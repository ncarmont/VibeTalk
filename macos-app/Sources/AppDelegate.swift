import Cocoa
import AVFoundation
import Speech
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var pillController: PillWindowController!
    private var mainWindow: MainWindowController!
    private var hotkeyManager: HotkeyManager!
    private var transcriptionEngine: TranscriptionEngine!
    private var isRecording = false
    private var accessibilityTimer: Timer?
    private var targetApp: NSRunningApplication?
    private var onboardingWindow: OnboardingWindowController?
    private var historyController: HistoryWindowController!
    private var imagePickerController: RecentImagePickerWindowController!
    private var modelSettingsController: ModelSettingsWindowController!
    private var lastToggleTime: TimeInterval = 0
    private var lastScreenshotHotkeyTime: TimeInterval = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        if activateExistingInstanceIfNeeded() { return }

        setupStatusBar()
        setupTranscriptionEngine()

        // History
        historyController = HistoryWindowController()

        // Recent Desktop images
        imagePickerController = RecentImagePickerWindowController()
        imagePickerController.onImageSelected = { [weak self] item, targetApp in
            self?.pasteDesktopImage(item, targetApp: targetApp)
        }
        imagePickerController.onVisibilityChanged = { [weak self] isVisible in
            self?.pillController.setScreenshotPickerOpen(isVisible)
        }

        // Model settings
        modelSettingsController = ModelSettingsWindowController()
        modelSettingsController.onModelSelected = { [weak self] model in
            self?.selectModel(model)
        }

        // Pill
        pillController = PillWindowController()
        pillController.onToggle = { [weak self] in self?.toggleRecording() }
        pillController.onOpenUI = { [weak self] in self?.showMainWindow() }
        pillController.onFrameChanged = { [weak self] frame in
            self?.historyController.updatePosition(pillFrame: frame)
            if let self, self.imagePickerController.isVisible {
                self.imagePickerController.updatePosition(anchorFrame: self.pillController.cameraButtonScreenFrame)
            }
        }
        pillController.onHistoryToggle = { [weak self] in
            guard let self = self else { return }
            self.imagePickerController.close()
            guard self.historyController.hasContent else {
                self.historyController.close()
                self.pillController.setHistoryOpen(false)
                self.pillController.showNotice("No previous chats yet")
                return
            }
            self.historyController.updatePosition(pillFrame: self.pillController.currentFrame)
            let isOpen = self.historyController.toggle()
            self.pillController.setHistoryOpen(isOpen)
        }
        pillController.onScreenshotPaste = { [weak self] in self?.toggleDesktopImagePicker() }
        pillController.onSettingsToggle = { [weak self] in self?.showMainWindow() }
        pillController.setSelectedModel(ModelPreferences.selectedModel)

        // Main window
        mainWindow = MainWindowController()
        mainWindow.onRecordToggle = { [weak self] in
            self?.toggleRecording()
            self?.mainWindow.isRecording = self?.isRecording ?? false
            self?.mainWindow.updateRecordButton()
        }
        mainWindow.onModelChange = { [weak self] model in
            self?.selectModel(model)
        }
        mainWindow.onManageModels = { [weak self] in
            self?.openModelSettingsFromMain()
        }
        mainWindow.onTestSelectedModel = { [weak self] in
            self?.testSelectedModel()
        }
        mainWindow.transcriptCleanupEnabled = TranscriptCleanupPreferences.isEnabled
        mainWindow.onTranscriptCleanupChange = { [weak self] enabled in
            TranscriptCleanupPreferences.isEnabled = enabled
            self?.pillController.showNotice(enabled ? "LLM formatting on" : "LLM formatting off")
        }
        mainWindow.onShowFloatingPill = { [weak self] in
            self?.revealFloatingPill()
        }

        // Re-check permissions the moment the app regains focus (e.g. returning from System Settings)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.hotkeyManager?.retryWithAccessibility()
            self.mainWindow.refreshPermissions()
            self.mainWindow.refreshInputDevices(selectedUID: self.transcriptionEngine.preferredInputDeviceUID)
        }

        // Setup hotkey immediately
        setupHotkey()
        setupLaunchAtLogin()

        // Wire input device selector
        mainWindow.onInputDeviceChange = { [weak self] uid in
            self?.transcriptionEngine.preferredInputDeviceUID = uid
        }
        mainWindow.refreshInputDevices(selectedUID: transcriptionEngine.preferredInputDeviceUID)

        if UserDefaults.standard.bool(forKey: "onboardingComplete") {
            pillController.show()
            mainWindow.show()
        } else {
            showOnboarding(needsMoveToApps: !isInApplicationsFolder())
        }

        // Request mic/speech in background
        requestPermissions {}
    }

    // MARK: - Install check

    private func isInApplicationsFolder() -> Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    private func activateExistingInstanceIfNeeded() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }

        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        guard let existing = others.first else { return false }

        if #available(macOS 14.0, *) {
            existing.activate()
        } else {
            _ = existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        NSApp.terminate(nil)
        return true
    }

    // MARK: - Onboarding

    private func showOnboarding(needsMoveToApps: Bool = false) {
        onboardingWindow = OnboardingWindowController(needsMoveToApps: needsMoveToApps)
        onboardingWindow?.onComplete = { [weak self] in
            self?.onboardingWindow = nil
            self?.pillController.show()
            self?.mainWindow.show()
        }
        onboardingWindow?.show()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "VibeTalk")
        }

        let menu = NSMenu()
        let showItem = NSMenuItem(title: "Open VibeTalk", action: #selector(showMainWindow), keyEquivalent: "")
        showItem.target = self; menu.addItem(showItem)
        menu.addItem(NSMenuItem.separator())
        let toggleItem = NSMenuItem(title: "Toggle Recording", action: #selector(toggleRecording), keyEquivalent: "")
        toggleItem.target = self; menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self; menu.addItem(quitItem)
        statusItem.menu = menu
    }

    // MARK: - Permissions

    private func requestPermissions(completion: @escaping () -> Void) {
        let group = DispatchGroup()
        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { _ in group.leave() }
        group.enter()
        SFSpeechRecognizer.requestAuthorization { _ in group.leave() }
        group.notify(queue: .main) { completion() }
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyManager = HotkeyManager()
        hotkeyManager.onToggle = { [weak self] in
            self?.toggleRecording()
            self?.mainWindow.isRecording = self?.isRecording ?? false
            self?.mainWindow.updateRecordButton()
        }
        hotkeyManager.onPasteLatestScreenshot = { [weak self] in
            self?.pasteLatestDesktopImageFromHotkey()
        }
        hotkeyManager.onEventTapActivated = { [weak self] in
            guard let self else { return }
            self.mainWindow.refreshPermissions()
            self.mainWindow.showResult("")
            self.pillController.showNotice("fn+Space is active — try it now!")
        }
        hotkeyManager.start()
        mainWindow.hotkeyManager = hotkeyManager

        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                self.hotkeyManager.retryWithAccessibility()
            }
            self.mainWindow.refreshPermissions()
        }
    }

    // MARK: - Transcription Engine

    private func setupTranscriptionEngine() {
        transcriptionEngine = TranscriptionEngine()

        transcriptionEngine.onPartialResult = { [weak self] text in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.pillController.updateTranscription(text)
                self.mainWindow.updateTranscription(text)
                self.historyController.updateLive(text)
                if self.historyController.isVisible {
                    self.historyController.updatePosition(pillFrame: self.pillController.currentFrame)
                }
            }
        }

        transcriptionEngine.onFinalResult = { [weak self] text in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRecording = false
                self.mainWindow.isRecording = false
                self.mainWindow.updateRecordButton()
                self.finishFinalTranscription(text)
            }
        }

        transcriptionEngine.onStatusUpdate = { [weak self] text in
            DispatchQueue.main.async {
                self?.pillController.updateProcessingText(text)
                self?.mainWindow.updateTranscription(text)
            }
        }

        transcriptionEngine.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.isRecording = false
                self?.mainWindow.isRecording = false
                self?.mainWindow.updateRecordButton()
                self?.mainWindow.showError(error)
                self?.pillController.showError(error)
                self?.targetApp = nil
            }
        }
    }

    // MARK: - Launch at Login

    private func finishFinalTranscription(_ text: String) {
        let rawText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard TranscriptCleanupPreferences.isEnabled, !rawText.isEmpty else {
            completeFinalTranscription(rawText)
            return
        }

        pillController.updateProcessingText("Formatting...")
        mainWindow.updateTranscription("Formatting...")

        TranscriptCleanupService.shared.improve(rawText, onStream: { [weak self] streamedText in
            self?.pillController.updateProcessingText(streamedText)
            self?.mainWindow.updateTranscription(streamedText)
        }) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success(let improvedText):
                    self.completeFinalTranscription(improvedText)
                case .failure(let error):
                    self.completeFinalTranscription(rawText)
                    self.mainWindow.showError("LLM formatting skipped: \(error.localizedDescription)")
                }
            }
        }
    }

    private func completeFinalTranscription(_ text: String) {
        historyController.finalizeLive(text)
        if historyController.isVisible {
            historyController.updatePosition(pillFrame: pillController.currentFrame)
        }

        if !text.isEmpty {
            mainWindow.showResult(text)
            TextInjector.inject(text, targetApp: targetApp)
            pillController.setSuccess(text: text)
        } else {
            mainWindow.showResult("")
            pillController.setIdle()
        }
        targetApp = nil
    }

    private func setupLaunchAtLogin() {
        let defaults = UserDefaults.standard
        // One-time migration: force enable if we haven't applied the new default yet
        if !defaults.bool(forKey: "launchAtLoginDefaultApplied") {
            defaults.set(true, forKey: "launchAtLoginDefaultApplied")
            defaults.set(true, forKey: "launchAtLogin")
        }
        if defaults.bool(forKey: "launchAtLogin") {
            try? SMAppService.mainApp.register()
        }

        mainWindow.launchAtLoginEnabled = defaults.bool(forKey: "launchAtLogin")
        mainWindow.onLaunchAtLoginChange = { enabled in
            defaults.set(enabled, forKey: "launchAtLogin")
            if enabled {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    // MARK: - Actions

    @objc private func toggleRecording() {
        // Debounce: prevent double-firing from simultaneous event tap + NSEvent monitor
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastToggleTime > 0.25 else { return }
        lastToggleTime = now

        if isRecording {
            isRecording = false
            transcriptionEngine.stopRecording()
            let model = ModelPreferences.selectedModel
            switch model.engine {
            case .appleSpeech:
                pillController.setProcessing(text: "Transcribing...")
            case .whisperCpp, .parakeetCLI, .voxtralMLX:
                pillController.setProcessing(text: "Transcribing with \(model.shortName)...")
            }
        } else {
            targetApp = NSWorkspace.shared.frontmostApplication
            isRecording = true
            pillController.setRecording()
            transcriptionEngine.startRecording()
        }
    }

    @objc private func showMainWindow() {
        mainWindow.show()
    }

    private func revealFloatingPill() {
        pillController.revealOnScreen()
    }

    private func pasteLatestDesktopImageFromHotkey() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastScreenshotHotkeyTime > 0.35 else { return }
        lastScreenshotHotkeyTime = now

        guard !isRecording else {
            pillController.showNotice("Stop dictation before screenshots")
            return
        }

        let target = currentContextApplication()
        modelSettingsController.close()
        historyController.close()
        pillController.setHistoryOpen(false)
        pillController.revealOnScreen()
        pillController.showNotice("Pasting latest screenshot...")

        imagePickerController.openAndPasteLatest(
            anchorFrame: pillController.cameraButtonScreenFrame,
            targetApp: target
        )
    }

    private func selectModel(_ model: STTModel) {
        guard !isRecording else {
            pillController.showNotice("Stop recording to change models")
            return
        }
        guard model.isAvailable else {
            pillController.showNotice(model.statusText)
            return
        }

        ModelPreferences.selectedModel = model
        transcriptionEngine.setModel(model)
        pillController.setSelectedModel(model)
        mainWindow.setSelectedModel(model)
        modelSettingsController.setSelectedModel(model)
        pillController.showNotice("Model: \(model.shortName)")
    }

    private func toggleModelSettings() {
        imagePickerController.close()
        historyController.close()
        pillController.setHistoryOpen(false)

        _ = modelSettingsController.toggle(
            anchorFrame: pillController.settingsButtonScreenFrame,
            selectedModel: ModelPreferences.selectedModel
        )
    }

    private func openModelSettingsFromMain() {
        imagePickerController.close()
        historyController.close()
        pillController.setHistoryOpen(false)
        mainWindow.show()
        modelSettingsController.open(
            anchorFrame: mainWindow.modelSettingsAnchorFrame,
            selectedModel: ModelPreferences.selectedModel
        )
    }

    private func testSelectedModel() {
        guard !isRecording else {
            mainWindow.setModelTestResult(success: false, message: "Stop recording before testing a model.")
            pillController.showNotice("Stop recording to test models")
            return
        }

        let model = ModelPreferences.selectedModel
        mainWindow.setModelTestRunning(model)
        pillController.showNotice("Testing \(model.shortName)...")

        transcriptionEngine.testModel(model) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.mainWindow.setModelTestResult(success: true, message: message)
                    self.pillController.showNotice("Test passed: \(model.shortName)")
                case .failure(let error):
                    let message = error.localizedDescription
                    self.mainWindow.setModelTestResult(success: false, message: message)
                    self.pillController.showError(message)
                }
            }
        }
    }

    private func toggleDesktopImagePicker() {
        modelSettingsController.close()
        historyController.close()
        pillController.setHistoryOpen(false)

        let app = currentContextApplication()
        _ = imagePickerController.toggle(
            anchorFrame: pillController.cameraButtonScreenFrame,
            targetApp: app
        )
    }

    private func currentContextApplication() -> NSRunningApplication? {
        let app = NSWorkspace.shared.frontmostApplication
        if app?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return nil
        }
        return app
    }

    private func pasteDesktopImage(_ item: RecentDesktopImage, targetApp app: NSRunningApplication?) {
        let image = NSImage(contentsOf: item.url) ?? item.image
        pillController.showScreenshotPreview(image)
        pillController.setSuccess(text: item.url.deletingPathExtension().lastPathComponent)

        if let app = app {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: .activateIgnoringOtherApps)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { [weak self] in
            NSPasteboard.general.clearContents()
            let pasteboardItem = RecentImageThumbnailView.makePasteboardItem(
                for: RecentDesktopImage(url: item.url, image: image, sortDate: item.sortDate)
            )
            guard NSPasteboard.general.writeObjects([pasteboardItem]) else {
                self?.pillController.showError("Pasteboard failed")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let source = CGEventSource(stateID: .combinedSessionState)
                let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                let vKeyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                vKeyDown?.flags = .maskCommand
                vKeyUp?.flags   = .maskCommand
                vKeyDown?.post(tap: .cghidEventTap)
                vKeyUp?.post(tap: .cghidEventTap)
            }
        }
    }

    private func takeAndPasteScreenshot() {
        // Capture target app before anything changes focus
        let app = NSWorkspace.shared.frontmostApplication

        // Hide pill so it doesn't appear in the capture
        pillController.hideForScreenshot()

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vibetalk_ss_\(UUID().uuidString).png")

        // Small delay so the pill has time to visually disappear before capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-x", tempURL.path]   // -x = no shutter sound

            task.terminationHandler = { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.pillController.restoreAfterScreenshot()

                    guard task.terminationStatus == 0 else {
                        try? FileManager.default.removeItem(at: tempURL)
                        self.pillController.showError("Screenshot failed")
                        return
                    }

                    guard let image = NSImage(contentsOf: tempURL) else {
                        try? FileManager.default.removeItem(at: tempURL)
                        self.pillController.showError("Screenshot failed")
                        return
                    }

                    self.pillController.showScreenshotPreview(image)
                    self.pillController.setSuccess(text: "Screenshot")

                    if let app = app {
                        if #available(macOS 14.0, *) {
                            app.activate()
                        } else {
                            app.activate(options: .activateIgnoringOtherApps)
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        NSPasteboard.general.clearContents()
                        guard NSPasteboard.general.writeObjects([image]) else {
                            try? FileManager.default.removeItem(at: tempURL)
                            self.pillController.showError("Pasteboard failed")
                            return
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            let source = CGEventSource(stateID: .combinedSessionState)
                            let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                            let vKeyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                            vKeyDown?.flags = .maskCommand
                            vKeyUp?.flags   = .maskCommand
                            vKeyDown?.post(tap: .cghidEventTap)
                            vKeyUp?.post(tap: .cghidEventTap)

                            // Clean up temp file
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                    }
                }
            }

            do {
                try task.run()
            } catch {
                self.pillController.restoreAfterScreenshot()
                self.pillController.showError("Screenshot failed")
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
        transcriptionEngine?.cancelRecording()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow.show()
        return true
    }
}
