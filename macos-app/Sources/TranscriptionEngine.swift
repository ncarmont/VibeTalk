import AVFoundation
import CoreAudio
import Speech

enum TranscriptionError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message): return message
        }
    }
}

// MARK: - TranscriptionEngine

class TranscriptionEngine: NSObject, SFSpeechRecognitionTaskDelegate {

    // MARK: - Audio

    private var audioEngine = AVAudioEngine()

    // recognitionRequest is read from the audio-tap thread and written from the main thread.
    // All access is protected by requestLock to prevent data races.
    private let requestLock = NSLock()
    private var _recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest? {
        get { requestLock.lock(); defer { requestLock.unlock() }; return _recognitionRequest }
        set { requestLock.lock(); defer { requestLock.unlock() }; _recognitionRequest = newValue }
    }

    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var currentModel: STTModel = ModelPreferences.selectedModel

    // Local file-mode models record to disk, convert to WAV, then run their CLI runtime.
    private let localAudioLock = NSLock()
    private var localAudioFile: AVAudioFile?
    private var localRecordingURL: URL?
    private var localProcessingModel: STTModel?

    // MARK: - Session state  (main-thread only)

    private var accumulatedText = ""   // Committed segments — never cleared mid-session
    private var currentPartial  = ""   // Latest unfinished partial from current task
    private var sessionActive   = false
    private var isStarting      = false
    private var isStopping      = false // endAudio() sent; waiting for recognizer's final answer
    private var delivered       = false
    private var startGeneration = 0

    // MARK: - Reliability infrastructure

    // Prevents the 60-second recognizer hard-limit from being hit cold.
    // We proactively rotate the task at 50 s so the handoff is planned rather than forced.
    private var proactiveTimer: Timer?

    // Only fail the session when the recognizer is clearly thrashing. Normal
    // pauses in speech can legitimately cause task boundaries on macOS.
    private var lastSpawnAt: Date?
    private var rapidRespawnCount = 0
    private static let rapidRespawnThresholdSeconds: Double = 0.75
    private static let maxRapidRespawns = 6

    // Re-creates the audio session when macOS switches the audio device
    // (AirPods, headphones, USB audio, etc.) — without this, the engine dies silently.
    private var audioConfigObserver: Any?
    private var audioTapInstalled = false
    private var audioRestartWork: DispatchWorkItem?

    // Stop flow
    private var stopTimeoutWork: DispatchWorkItem?

    // Short-lived task used to load the speech framework before the first real session
    private var warmupTask: SFSpeechRecognitionTask?

    // MARK: - Callbacks

    var onPartialResult: ((String) -> Void)?
    var onFinalResult:   ((String) -> Void)?
    var onError:         ((String) -> Void)?
    var onStatusUpdate:  ((String) -> Void)?

    // MARK: - Audio Device Selection

    var preferredInputDeviceUID: String? {
        get { UserDefaults.standard.string(forKey: "preferredInputDeviceUID") }
        set { UserDefaults.standard.set(newValue, forKey: "preferredInputDeviceUID") }
    }

    static func availableInputDevices() -> [(name: String, uid: String)] {
        let types: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            types = [.microphone, .externalUnknown]
        } else {
            types = [.builtInMicrophone, .externalUnknown]
        }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .audio, position: .unspecified
        )
        return session.devices.map { ($0.localizedName, $0.uniqueID) }
    }

    private func audioDeviceID(forUID uid: String) -> AudioDeviceID? {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var cfUID = uid as CFString
        var translation = AudioValueTranslation(
            mInputData: &cfUID,
            mInputDataSize: UInt32(MemoryLayout<CFString?>.size),
            mOutputData: &deviceID,
            mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &translation
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private func applyPreferredInputDevice() {
        guard let uid = preferredInputDeviceUID,
              let deviceID = audioDeviceID(forUID: uid),
              let audioUnit = audioEngine.inputNode.audioUnit else { return }
        var id = deviceID
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }

    // MARK: - Init

    override init() {
        super.init()
        configureSpeechRecognizer(for: currentModel)
        // Give the app a moment to finish launch, then pre-warm so the first press is instant.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.prewarm()
        }
    }

    func setModel(_ model: STTModel) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.setModel(model) }
            return
        }
        guard !sessionActive && !isStarting && !isStopping else { return }
        currentModel = model
        ModelPreferences.selectedModel = model
        configureSpeechRecognizer(for: model)
    }

    private func configureSpeechRecognizer(for model: STTModel) {
        guard model.engine == .appleSpeech, let locale = model.locale else {
            speechRecognizer = nil
            return
        }
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.defaultTaskHint = .dictation
    }

    // MARK: - Prewarming

    // Called after init and after each session ends. Creates a standby engine (already
    // prepare()'d by CoreAudio) and loads the speech framework so the next press is instant.
    func prewarm() {
        guard !sessionActive, !isStarting else { return }
        if currentModel.engine == .appleSpeech {
            prewarmSpeechRecognizer()
        }
    }

    private func prewarmSpeechRecognizer() {
        // Only warm the recognizer if the user has already granted access —
        // calling recognitionTask without authorization crashes via TCC.
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { return }
        warmupTask?.cancel()
        warmupTask = nil
        guard let sr = speechRecognizer else { return }
        // Creating a recognition task triggers speech framework initialisation. The task is
        // cancelled quickly — the framework stays warm and subsequent real tasks start fast.
        let req = SFSpeechAudioBufferRecognitionRequest()
        warmupTask = sr.recognitionTask(with: req) { [weak self] _, _ in
            self?.warmupTask = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.warmupTask?.cancel()
            self?.warmupTask = nil
        }
    }

    private func schedulePrewarm() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.sessionActive, !self.isStarting else { return }
            self.prewarm()
        }
    }

    // MARK: - Public API

    func testModel(_ model: STTModel, completion: @escaping (Result<String, Error>) -> Void) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.testModel(model, completion: completion) }
            return
        }

        guard !sessionActive && !isStarting && !isStopping else {
            completion(.failure(TranscriptionError.message("Stop dictation before testing a model.")))
            return
        }

        if model.engine == .appleSpeech {
            testAppleSpeechModel(model, completion: completion)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                try self.validateLocalModelReady(model)
                let wavURL = try self.createModelSelfTestWav()
                defer { try? FileManager.default.removeItem(at: wavURL) }

                let output = try self.runLocalTranscriber(model: model, wavURL: wavURL)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !output.isEmpty else {
                    throw TranscriptionError.message("\(model.shortName) ran, but returned an empty transcript for the test audio.")
                }

                let preview = output.count > 72 ? String(output.prefix(69)) + "..." : output
                completion(.success("\(model.shortName) passed. Heard: \"\(preview)\""))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func startRecording() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.startRecording() }
            return
        }

        startGeneration += 1
        let generation = startGeneration

        // Full teardown first — ensures clean state even if called while running
        fullTeardown()

        accumulatedText  = ""
        currentPartial   = ""
        sessionActive    = false
        isStarting       = true
        isStopping       = false
        delivered        = false
        lastSpawnAt      = nil
        rapidRespawnCount = 0

        switch currentModel.engine {
        case .appleSpeech:
            continueStartAfterPermissions(generation: generation)
        case .whisperCpp, .parakeetCLI, .voxtralMLX:
            continueStartAfterMicrophonePermission(generation: generation)
        }
    }

    private func continueStartAfterPermissions(generation: Int) {
        guard generation == startGeneration, isStarting else { return }

        requestMicrophonePermission(generation: generation) { [weak self] in
            self?.continueStartAfterSpeechPermission(generation: generation)
        }
    }

    private func continueStartAfterMicrophonePermission(generation: Int) {
        guard generation == startGeneration, isStarting else { return }

        guard currentModel.isDownloaded else {
            failStart("Download \(currentModel.shortName) before using it.", generation: generation)
            return
        }

        guard currentModel.isRuntimeAvailable else {
            failStart(currentModel.runtimeInstallHint, generation: generation)
            return
        }

        requestMicrophonePermission(generation: generation) { [weak self] in
            self?.beginLocalRecording(generation: generation)
        }
    }

    private func requestMicrophonePermission(generation: Int, completion: @escaping () -> Void) {
        guard generation == startGeneration, isStarting else { return }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if granted {
                        completion()
                    } else {
                        self.failStart("Microphone access is required for dictation.", generation: generation)
                    }
                }
            }
            return
        case .denied, .restricted:
            failStart("Microphone access is not granted. Enable it in System Settings.", generation: generation)
            return
        @unknown default:
            failStart("Microphone access is unavailable on this Mac.", generation: generation)
            return
        }
    }

    private func continueStartAfterSpeechPermission(generation: Int) {
        guard generation == startGeneration, isStarting else { return }

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if status == .authorized {
                        self.continueStartAfterPermissions(generation: generation)
                    } else {
                        self.failStart("Speech Recognition access is required for dictation.", generation: generation)
                    }
                }
            }
            return
        case .denied, .restricted:
            failStart("Speech Recognition access is not granted. Enable it in System Settings.", generation: generation)
            return
        @unknown default:
            failStart("Speech Recognition is unavailable on this Mac.", generation: generation)
            return
        }

        beginAuthorizedRecording(generation: generation)
    }

    private func testAppleSpeechModel(_ model: STTModel, completion: @escaping (Result<String, Error>) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.testAppleSpeechModel(model, completion: completion)
                    } else {
                        completion(.failure(TranscriptionError.message("Microphone access is required for dictation.")))
                    }
                }
            }
            return
        case .denied, .restricted:
            completion(.failure(TranscriptionError.message("Microphone access is not granted. Enable it in System Settings.")))
            return
        @unknown default:
            completion(.failure(TranscriptionError.message("Microphone access is unavailable on this Mac.")))
            return
        }

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if status == .authorized {
                        self.testAppleSpeechModel(model, completion: completion)
                    } else {
                        completion(.failure(TranscriptionError.message("Speech Recognition access is required for dictation.")))
                    }
                }
            }
            return
        case .denied, .restricted:
            completion(.failure(TranscriptionError.message("Speech Recognition access is not granted. Enable it in System Settings.")))
            return
        @unknown default:
            completion(.failure(TranscriptionError.message("Speech Recognition is unavailable on this Mac.")))
            return
        }

        guard let locale = model.locale,
              let recognizer = SFSpeechRecognizer(locale: locale) else {
            completion(.failure(TranscriptionError.message("Apple Speech recognizer unavailable for \(model.name).")))
            return
        }

        if model.onDeviceOnly && !recognizer.supportsOnDeviceRecognition {
            completion(.failure(TranscriptionError.message("\(model.shortName) does not support on-device recognition on this Mac.")))
            return
        }

        if !model.onDeviceOnly && !recognizer.isAvailable {
            completion(.failure(TranscriptionError.message("\(model.shortName) is not available right now.")))
            return
        }

        let mode = model.onDeviceOnly ? "on-device" : "server"
        completion(.success("\(model.shortName) passed. Apple Speech \(locale.identifier), \(mode), mic and speech access ready."))
    }

    private func beginAuthorizedRecording(generation: Int) {
        guard generation == startGeneration, isStarting else { return }

        guard speechRecognizer != nil, currentModel.isAvailable else {
            failStart("Speech recognizer unavailable for \(currentModel.name)", generation: generation)
            return
        }

        sessionActive = true
        isStarting = false
        audioEngine = AVAudioEngine()
        audioTapInstalled = false
        applyPreferredInputDevice()
        installAudioConfigObserver()

        guard installAudioTap() else { return }
        spawnTask()
    }

    private func beginLocalRecording(generation: Int) {
        guard generation == startGeneration, isStarting else { return }
        guard currentModel.isDownloaded else {
            failStart("Download \(currentModel.shortName) before using it.", generation: generation)
            return
        }
        guard currentModel.isRuntimeAvailable else {
            failStart(currentModel.runtimeInstallHint, generation: generation)
            return
        }

        sessionActive = true
        isStarting = false
        audioEngine = AVAudioEngine()
        audioTapInstalled = false
        localProcessingModel = currentModel
        applyPreferredInputDevice()
        installAudioConfigObserver()

        guard installLocalAudioTap() else { return }
        onPartialResult?("Recording with \(currentModel.shortName)...")
    }

    func stopRecording() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.stopRecording() }
            return
        }

        startGeneration += 1

        if isStarting && !sessionActive {
            isStarting = false
            fullTeardown()
            onFinalResult?("")
            return
        }

        guard sessionActive else { return }

        if currentModel.engine == .whisperCpp || currentModel.engine == .parakeetCLI || currentModel.engine == .voxtralMLX {
            stopLocalRecording()
            return
        }

        sessionActive = false
        isStarting    = false
        isStopping    = true

        proactiveTimer?.invalidate()
        proactiveTimer = nil

        removeAudioConfigObserver()

        // Stop capturing — no new audio after this point
        stopAudioEngine()

        // Signal the recognizer that audio is finished so it can flush its buffer
        // and return the very last words before we deliver the result.
        recognitionRequest?.endAudio()

        // Timeout guard: if the recognizer takes > 1.5 s to finalize, deliver now
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isStopping else { return }
            self.isStopping = false
            self.deliverFinal()
            self.teardownRecognition()
        }
        stopTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func cancelRecording() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.cancelRecording() }
            return
        }

        startGeneration += 1
        isStarting = false
        sessionActive = false
        isStopping = false
        fullTeardown()
        schedulePrewarm()
    }

    // MARK: - Audio device change recovery

    /// Called when macOS switches the system audio device while we are recording.
    /// Tears down the now-invalid tap and restarts capture seamlessly — accumulated
    /// text and the recording session are preserved.
    private func handleAudioDeviceChange() {
        guard sessionActive else { return }

        if currentModel.engine == .whisperCpp || currentModel.engine == .parakeetCLI || currentModel.engine == .voxtralMLX {
            failActiveSession("Audio input changed. Start local dictation again.")
            return
        }

        // The tap is already invalid; stop the engine and cancel the current task.
        // We keep sessionActive = true and preserve accumulatedText.
        removeAudioConfigObserver()
        stopAudioEngine()
        audioEngine = AVAudioEngine()
        audioTapInstalled = false
        applyPreferredInputDevice()
        installAudioConfigObserver()

        proactiveTimer?.invalidate()
        proactiveTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        currentPartial = ""
        audioRestartWork?.cancel()

        // Brief settle period for the OS to finish routing the new device
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.sessionActive else { return }
            self.audioRestartWork = nil
            if self.installAudioTap() {
                self.spawnTask()
            }
        }
        audioRestartWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - Audio helpers

    @discardableResult
    private func installAudioTap() -> Bool {
        guard sessionActive else { return false }
        stopAudioEngine()

        let input  = audioEngine.inputNode
        // Always read the format AFTER any device change — it may differ
        let outputFormat = input.outputFormat(forBus: 0)
        let inputFormat = input.inputFormat(forBus: 0)
        let hasValidInput = (outputFormat.sampleRate > 0 && outputFormat.channelCount > 0)
            || (inputFormat.sampleRate > 0 && inputFormat.channelCount > 0)
        guard hasValidInput else {
            failActiveSession("No valid microphone input format was available.")
            return false
        }

        // Passing nil keeps AVAudioEngine on the hardware/native input format.
        // Forcing outputFormat here can raise an Objective-C exception during
        // route changes, which Swift cannot catch.
        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }
        audioTapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
            return true
        } catch let firstError {
            // Retry once with a fresh engine on the system-default device.
            // Fixes -10868 (format/device mismatch) that happens when earphones
            // are plugged in and the input route changes between engine creation
            // and start.
            stopAudioEngine()
            audioEngine = AVAudioEngine()
            audioTapInstalled = false
            let retryInput = audioEngine.inputNode
            retryInput.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buf, _ in
                self?.recognitionRequest?.append(buf)
            }
            audioTapInstalled = true
            audioEngine.prepare()
            do {
                try audioEngine.start()
                return true
            } catch {
                failActiveSession("Audio engine: \(firstError.localizedDescription)")
                return false
            }
        }
    }

    @discardableResult
    private func installLocalAudioTap() -> Bool {
        guard sessionActive else { return false }
        stopAudioEngine()

        let input = audioEngine.inputNode
        let outputFormat = input.outputFormat(forBus: 0)
        let inputFormat = input.inputFormat(forBus: 0)
        let tapFormat = outputFormat.sampleRate > 0 && outputFormat.channelCount > 0 ? outputFormat : inputFormat
        guard tapFormat.sampleRate > 0, tapFormat.channelCount > 0 else {
            failActiveSession("No valid microphone input format was available.")
            return false
        }

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vibetalk_local_\(UUID().uuidString).caf")
        do {
            localAudioFile = try AVAudioFile(forWriting: url, settings: tapFormat.settings)
            localRecordingURL = url
        } catch {
            failActiveSession("Audio recorder: \(error.localizedDescription)")
            return false
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
            guard let self else { return }
            self.localAudioLock.lock()
            defer { self.localAudioLock.unlock() }
            do {
                try self.localAudioFile?.write(from: buffer)
            } catch {
                DispatchQueue.main.async {
                    self.failActiveSession("Audio recorder: \(error.localizedDescription)")
                }
            }
        }
        audioTapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
            return true
        } catch {
            failActiveSession("Audio engine: \(error.localizedDescription)")
            return false
        }
    }

    private func stopLocalRecording() {
        let processingGeneration = startGeneration

        sessionActive = false
        isStarting = false
        isStopping = true

        removeAudioConfigObserver()
        stopAudioEngine()

        localAudioLock.lock()
        let sourceURL = localRecordingURL
        let model = localProcessingModel ?? currentModel
        localAudioFile = nil
        localRecordingURL = nil
        localAudioLock.unlock()

        guard let sourceURL else {
            isStopping = false
            onFinalResult?("")
            return
        }

        transcribeLocalRecording(sourceURL: sourceURL, model: model, generation: processingGeneration)
    }

    private func transcribeLocalRecording(sourceURL: URL, model: STTModel, generation: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                DispatchQueue.main.async { [weak self] in self?.onStatusUpdate?("Converting audio...") }
                let wavURL = try self.convertToLocalWav(sourceURL: sourceURL)
                DispatchQueue.main.async { [weak self] in self?.onStatusUpdate?("Transcribing with \(model.shortName)...") }
                let text = try self.runLocalTranscriber(model: model, wavURL: wavURL)
                try? FileManager.default.removeItem(at: sourceURL)
                try? FileManager.default.removeItem(at: wavURL)
                DispatchQueue.main.async {
                    guard generation == self.startGeneration, self.isStopping else { return }
                    self.isStopping = false
                    self.currentPartial = text
                    self.deliverFinal()
                    self.fullTeardown()
                }
            } catch {
                try? FileManager.default.removeItem(at: sourceURL)
                DispatchQueue.main.async {
                    guard generation == self.startGeneration else { return }
                    self.isStopping = false
                    self.fullTeardown()
                    self.onError?(error.localizedDescription)
                }
            }
        }
    }

    private func convertToLocalWav(sourceURL: URL) throws -> URL {
        let wavURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vibetalk_local_\(UUID().uuidString).wav")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = ["-f", "WAVE", "-d", "LEI16@16000", "-c", "1", sourceURL.path, wavURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let details = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw TranscriptionError.message(details?.isEmpty == false ? details! : "Audio conversion failed.")
        }

        return wavURL
    }

    private func runLocalTranscriber(model: STTModel, wavURL: URL) throws -> String {
        switch model.engine {
        case .whisperCpp:
            return try runWhisper(model: model, wavURL: wavURL)
        case .parakeetCLI:
            return try runParakeet(model: model, wavURL: wavURL)
        case .voxtralMLX:
            return try runVoxtral(model: model, wavURL: wavURL)
        case .appleSpeech:
            throw TranscriptionError.message("Apple Speech does not use file-mode transcription.")
        }
    }

    private func validateLocalModelReady(_ model: STTModel) throws {
        guard model.isDownloaded else {
            throw TranscriptionError.message("Download \(model.shortName) before testing it.")
        }

        guard model.isRuntimeAvailable else {
            throw TranscriptionError.message(model.runtimeInstallHint)
        }

        switch model.engine {
        case .whisperCpp:
            guard let modelURL = model.localModelURL,
                  FileManager.default.fileExists(atPath: modelURL.path) else {
                throw TranscriptionError.message("Missing model file for \(model.shortName).")
            }
        case .parakeetCLI:
            guard ParakeetRuntime.modelExists(for: model) else {
                throw TranscriptionError.message("Missing Parakeet model files for \(model.shortName).")
            }
        case .voxtralMLX:
            guard VoxtralRuntime.modelExists(for: model) else {
                throw TranscriptionError.message("Missing Voxtral model files for \(model.shortName).")
            }
        case .appleSpeech:
            break
        }
    }

    private func createModelSelfTestWav() throws -> URL {
        let id = UUID().uuidString
        let aiffURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vibetalk_model_test_\(id).aiff")
        let wavURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vibetalk_model_test_\(id).wav")

        do {
            try runProcess(
                executable: URL(fileURLWithPath: "/usr/bin/say"),
                arguments: ["-o", aiffURL.path, "VibeTalk model test"]
            )
            try runProcess(
                executable: URL(fileURLWithPath: "/usr/bin/afconvert"),
                arguments: ["-f", "WAVE", "-d", "LEI16@16000", "-c", "1", aiffURL.path, wavURL.path]
            )
            try? FileManager.default.removeItem(at: aiffURL)
            return wavURL
        } catch {
            try? FileManager.default.removeItem(at: aiffURL)
            try? FileManager.default.removeItem(at: wavURL)
            throw error
        }
    }

    private func runProcess(executable: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let details = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TranscriptionError.message(details?.isEmpty == false ? details! : "\(executable.lastPathComponent) failed.")
        }
    }

    private func runWhisper(model: STTModel, wavURL: URL) throws -> String {
        guard let executableURL = WhisperRuntime.executableURL() else {
            throw TranscriptionError.message(WhisperRuntime.installHint)
        }
        guard let modelURL = model.localModelURL,
              FileManager.default.fileExists(atPath: modelURL.path) else {
            throw TranscriptionError.message("Download \(model.shortName) before using it.")
        }

        let process = Process()
        process.executableURL = executableURL
        var args = ["-m", modelURL.path, "-f", wavURL.path, "-nt", "-np"]
        if let languageCode = model.languageCode {
            args += ["-l", languageCode]
        }
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let details = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TranscriptionError.message(details?.isEmpty == false ? details! : "Whisper transcription failed.")
        }

        return output
    }

    private func runVoxtral(model: STTModel, wavURL: URL) throws -> String {
        guard let executableURL = VoxtralRuntime.executableURL() else {
            throw TranscriptionError.message(VoxtralRuntime.installHint)
        }
        guard let modelDirectory = model.localModelURL,
              VoxtralRuntime.modelExists(for: model) else {
            throw TranscriptionError.message("Download \(model.shortName) before using it.")
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "--audio",
            wavURL.path,
            "--model",
            modelDirectory.path
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let details = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TranscriptionError.message(details?.isEmpty == false ? details! : "Voxtral transcription failed.")
        }

        return output
    }

    private func runParakeet(model: STTModel, wavURL: URL) throws -> String {
        guard let executableURL = ParakeetRuntime.executableURL() else {
            throw TranscriptionError.message(ParakeetRuntime.installHint)
        }
        guard let modelDirectory = model.localModelURL,
              ParakeetRuntime.modelExists(for: model) else {
            throw TranscriptionError.message("Download \(model.shortName) before using it.")
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "transcribe",
            wavURL.path,
            "--model-dir",
            modelDirectory.path,
            "--format",
            "text"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let details = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TranscriptionError.message(details?.isEmpty == false ? details! : "Parakeet transcription failed.")
        }

        return output
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning { audioEngine.stop() }
        if audioTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioTapInstalled = false
        }
    }

    private func removeAudioConfigObserver() {
        if let obs = audioConfigObserver {
            NotificationCenter.default.removeObserver(obs)
            audioConfigObserver = nil
        }
    }

    private func installAudioConfigObserver() {
        removeAudioConfigObserver()
        audioConfigObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.handleAudioDeviceChange() }
        }
    }

    // MARK: - Recognition task

    private func spawnTask() {
        guard sessionActive, let sr = speechRecognizer else { return }

        let now = Date()
        if let lastSpawnAt, now.timeIntervalSince(lastSpawnAt) < TranscriptionEngine.rapidRespawnThresholdSeconds {
            rapidRespawnCount += 1
        } else {
            rapidRespawnCount = 0
        }
        lastSpawnAt = now
        if rapidRespawnCount >= TranscriptionEngine.maxRapidRespawns {
            failActiveSession("Speech recognition is repeatedly failing. Check microphone access and try again.")
            return
        }

        // ── Create next request ──────────────────────────────────────────────────
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.taskHint = .dictation
        req.shouldReportPartialResults = true
        if #available(macOS 13.0, *) {
            req.addsPunctuation = true
        }
        if currentModel.onDeviceOnly && sr.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }

        // Swap the active request FIRST so the audio tap starts filling the new
        // buffer immediately — minimising the gap between tasks.
        let oldTask = recognitionTask
        recognitionRequest = req
        currentPartial     = ""

        // ── Proactive rotation at 50 s ───────────────────────────────────────────
        // Apple's on-device recognizer hard-limits each task to ~60 s.
        // Rotating at 50 s gives us 10 s of comfortable headroom so the handoff
        // is planned rather than forced mid-sentence.
        proactiveTimer?.invalidate()
        proactiveTimer = Timer.scheduledTimer(withTimeInterval: 50.0, repeats: false) { [weak self] _ in
            guard let self = self, self.sessionActive else { return }
            self.commit(self.currentPartial)
            self.onPartialResult?(self.accumulatedText)
            self.respawn()
        }

        // ── Start recognition ────────────────────────────────────────────────────
        recognitionTask = sr.recognitionTask(with: req, delegate: self)

        // Cancel old task only after the new task is installed.
        oldTask?.cancel()
    }

    private func respawn() {
        guard sessionActive else { return }
        spawnTask()
    }

    // MARK: - Helpers

    private var fullText: String {
        if accumulatedText.isEmpty { return currentPartial }
        if currentPartial.isEmpty  { return accumulatedText }
        return accumulatedText + " " + currentPartial
    }

    private func commit(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        accumulatedText = accumulatedText.isEmpty ? t : accumulatedText + " " + t
        currentPartial  = ""
    }

    private func deliverFinal() {
        guard !delivered else { return }
        delivered = true
        onFinalResult?(fullText)
        schedulePrewarm()
    }

    private func teardownRecognition() {
        recognitionTask?.cancel()
        recognitionTask    = nil
        recognitionRequest = nil
    }

    private func fullTeardown() {
        warmupTask?.cancel()
        warmupTask = nil
        proactiveTimer?.invalidate()
        proactiveTimer = nil
        audioRestartWork?.cancel()
        audioRestartWork = nil
        stopTimeoutWork?.cancel()
        stopTimeoutWork = nil
        removeAudioConfigObserver()
        stopAudioEngine()
        localAudioLock.lock()
        let staleURL = localRecordingURL
        localAudioFile = nil
        localRecordingURL = nil
        localProcessingModel = nil
        localAudioLock.unlock()
        if let staleURL { try? FileManager.default.removeItem(at: staleURL) }
        teardownRecognition()
    }

    private func failStart(_ message: String, generation: Int) {
        guard generation == startGeneration else { return }
        isStarting = false
        sessionActive = false
        isStopping = false
        fullTeardown()
        onError?(message)
    }

    private func failActiveSession(_ message: String) {
        sessionActive = false
        isStarting = false
        isStopping = false
        fullTeardown()
        onError?(message)
    }

    private func isCurrentTask(_ task: SFSpeechRecognitionTask) -> Bool {
        task === recognitionTask
    }

    private func handleUnexpectedTaskEnd(error: NSError?) {
        guard sessionActive else { return }

        if let error {
            let isRecoverableSpeechError =
                error.domain == "kAFAssistantErrorDomain" &&
                [1101, 1107, 1110].contains(error.code)

            if !isRecoverableSpeechError {
                failActiveSession("Speech recognition: \(error.localizedDescription)")
                return
            }
        }

        commit(currentPartial)
        if !accumulatedText.isEmpty {
            onPartialResult?(accumulatedText)
        }

        rolloverToNextTask()
    }

    private func rolloverToNextTask() {
        guard sessionActive else { return }

        commit(currentPartial)
        if !accumulatedText.isEmpty {
            onPartialResult?(accumulatedText)
        }

        // Keep the session hot across silence-triggered task boundaries so the
        // user stays in the same recording until they manually stop it.
        respawn()
    }

    // MARK: - SFSpeechRecognitionTaskDelegate

    func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        DispatchQueue.main.async {
            guard self.isCurrentTask(task) else { return }
            self.rapidRespawnCount = 0
        }
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        DispatchQueue.main.async {
            guard self.isCurrentTask(task) else { return }
            guard self.sessionActive || self.isStopping else { return }
            self.currentPartial = transcription.formattedString
            self.onPartialResult?(self.fullText)
        }
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        DispatchQueue.main.async {
            guard self.isCurrentTask(task) else { return }
            guard self.sessionActive || self.isStopping else { return }

            let text = recognitionResult.bestTranscription.formattedString
            self.commit(text)

            if self.isStopping {
                self.stopTimeoutWork?.cancel()
                self.stopTimeoutWork = nil
                self.isStopping = false
                self.deliverFinal()
                self.teardownRecognition()
            } else {
                self.onPartialResult?(self.accumulatedText)
            }
        }
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        DispatchQueue.main.async {
            guard self.isCurrentTask(task) else { return }

            if self.isStopping {
                self.stopTimeoutWork?.cancel()
                self.stopTimeoutWork = nil
                self.isStopping = false
                self.deliverFinal()
                self.teardownRecognition()
                return
            }

            if successfully {
                self.rolloverToNextTask()
            } else {
                self.handleUnexpectedTaskEnd(error: task.error as NSError?)
            }
        }
    }

    deinit {
        fullTeardown()
    }
}
