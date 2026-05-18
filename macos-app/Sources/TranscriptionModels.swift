import Foundation
import Speech

enum STTEngine: String {
    case appleSpeech
    case whisperCpp
    case parakeetCLI
    case voxtralMLX
}

struct STTModel: Equatable {
    let id: String
    let name: String
    let shortName: String
    let engine: STTEngine
    let locale: Locale?
    let onDeviceOnly: Bool
    let languageCode: String?
    let summary: String
    let speedRank: Int
    let accuracyRank: Int
    let accuracyLabel: String
    let downloadSize: String?
    let memoryRequirement: String?
    let fileName: String?
    let downloadURL: URL?
    let expectedBytes: Int64?
    let expectedSHA256: String?
    let isQuickChoice: Bool

    init(
        id: String,
        name: String,
        shortName: String,
        engine: STTEngine,
        locale: Locale?,
        onDeviceOnly: Bool,
        languageCode: String?,
        summary: String,
        speedRank: Int,
        accuracyRank: Int,
        accuracyLabel: String,
        downloadSize: String?,
        memoryRequirement: String? = nil,
        fileName: String?,
        downloadURL: URL?,
        expectedBytes: Int64? = nil,
        expectedSHA256: String? = nil,
        isQuickChoice: Bool
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.engine = engine
        self.locale = locale
        self.onDeviceOnly = onDeviceOnly
        self.languageCode = languageCode
        self.summary = summary
        self.speedRank = speedRank
        self.accuracyRank = accuracyRank
        self.accuracyLabel = accuracyLabel
        self.downloadSize = downloadSize
        self.memoryRequirement = memoryRequirement
        self.fileName = fileName
        self.downloadURL = downloadURL
        self.expectedBytes = expectedBytes
        self.expectedSHA256 = expectedSHA256
        self.isQuickChoice = isQuickChoice
    }

    static func == (lhs: STTModel, rhs: STTModel) -> Bool {
        lhs.id == rhs.id
    }

    var isAppleSpeech: Bool { engine == .appleSpeech }
    var isLocalWhisper: Bool { engine == .whisperCpp }
    var isLocalParakeet: Bool { engine == .parakeetCLI }
    var isLocalVoxtral: Bool { engine == .voxtralMLX }

    var localModelURL: URL? {
        guard let fileName else { return nil }
        return ModelStorage.modelsDirectory.appendingPathComponent(fileName)
    }

    var isDownloaded: Bool {
        switch engine {
        case .appleSpeech:
            return true
        case .whisperCpp:
            guard let localModelURL else { return false }
            return FileManager.default.fileExists(atPath: localModelURL.path)
        case .parakeetCLI:
            return ParakeetRuntime.modelExists(for: self)
        case .voxtralMLX:
            return VoxtralRuntime.modelExists(for: self)
        }
    }

    var isRuntimeAvailable: Bool {
        switch engine {
        case .appleSpeech:
            return true
        case .whisperCpp:
            return WhisperRuntime.executableURL() != nil
        case .parakeetCLI:
            return ParakeetRuntime.executableURL() != nil
        case .voxtralMLX:
            return VoxtralRuntime.executableURL() != nil
        }
    }

    var isAvailable: Bool {
        switch engine {
        case .appleSpeech:
            guard let locale, let recognizer = SFSpeechRecognizer(locale: locale) else { return false }
            if onDeviceOnly { return recognizer.supportsOnDeviceRecognition }
            return recognizer.isAvailable
        case .whisperCpp:
            return isDownloaded && isRuntimeAvailable
        case .parakeetCLI:
            return isDownloaded && isRuntimeAvailable
        case .voxtralMLX:
            return isDownloaded && isRuntimeAvailable
        }
    }

    var needsDownload: Bool {
        (isLocalWhisper || isLocalParakeet || isLocalVoxtral) && !isDownloaded
    }

    var statusText: String {
        switch engine {
        case .appleSpeech:
            return isAvailable ? "Ready" : "Unavailable"
        case .whisperCpp:
            if !isDownloaded { return "Download" }
            if !isRuntimeAvailable { return "Needs runtime" }
            return "Ready"
        case .parakeetCLI:
            if !isDownloaded { return "Download" }
            if !isRuntimeAvailable { return "Needs runtime" }
            return "Ready"
        case .voxtralMLX:
            if !isDownloaded { return "Download" }
            if !isRuntimeAvailable { return "Needs runtime" }
            return "Ready"
        }
    }

    var runtimeInstallHint: String {
        switch engine {
        case .appleSpeech:
            return ""
        case .whisperCpp:
            return WhisperRuntime.installHint
        case .parakeetCLI:
            return ParakeetRuntime.installHint
        case .voxtralMLX:
            return VoxtralRuntime.installHint
        }
    }

    var isExternalDownloaderModel: Bool {
        engine == .parakeetCLI || engine == .voxtralMLX
    }

    var tooltipText: String {
        let localText: String
        switch engine {
        case .appleSpeech:
            localText = "Uses Apple's live Speech recognizer."
        case .whisperCpp:
            localText = "Runs through whisper.cpp after recording stops. GGML downloads are size and SHA-256 verified."
        case .parakeetCLI:
            localText = "Runs through parakeet-cli after recording stops. Parakeet's downloader verifies ONNX files by SHA-256."
        case .voxtralMLX:
            localText = "Runs through voxmlx after recording stops. Voxtral Mini Realtime is local after its MLX weights are downloaded."
        }
        let tradeoff = "Speed \(speedRank)/5, accuracy \(accuracyRank)/5, \(accuracyLabel). \(footprintText)."
        return "\(name). \(localText) \(tradeoff)"
    }

    var diskSizeText: String {
        if let installedBytes = installedDiskBytes {
            return ByteCountFormatter.string(fromByteCount: installedBytes, countStyle: .file)
        }
        return downloadSize ?? "built-in"
    }

    var footprintText: String {
        let memory = memoryRequirement ?? "system"
        return "Disk \(diskSizeText), RAM \(memory)"
    }

    private var installedDiskBytes: Int64? {
        guard let localModelURL else { return nil }
        guard FileManager.default.fileExists(atPath: localModelURL.path) else { return nil }
        return Self.diskUsageBytes(at: localModelURL)
    }

    private static func diskUsageBytes(at url: URL) -> Int64? {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        if values.isDirectory == true {
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return nil }

            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                guard let fileValues = try? fileURL.resourceValues(forKeys: keys),
                      fileValues.isDirectory != true else { continue }
                let size = fileValues.totalFileAllocatedSize ?? fileValues.fileAllocatedSize ?? 0
                total += Int64(size)
            }
            return total
        }

        let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize
        return size.map { Int64($0) }
    }
}

enum ModelStorage {
    static let modelsDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("VibeTalk", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }()

    static func ensureModelsDirectory() throws {
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
}

enum WhisperRuntime {
    static func executableURL() -> URL? {
        let resource = Bundle.main.resourceURL
        let candidates = [
            resource?.appendingPathComponent("whisper-cli"),
            resource?.appendingPathComponent("whisper.cpp/whisper-cli"),
            URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cli"),
            URL(fileURLWithPath: "/usr/local/bin/whisper-cli"),
            URL(fileURLWithPath: "/opt/homebrew/bin/whisper-cpp"),
            URL(fileURLWithPath: "/usr/local/bin/whisper-cpp")
        ].compactMap { $0 }

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static var installHint: String {
        "Install whisper.cpp with Homebrew: brew install whisper-cpp"
    }
}

enum ParakeetRuntime {
    static func executableURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let resource = Bundle.main.resourceURL
        let candidates = [
            resource?.appendingPathComponent("parakeet"),
            resource?.appendingPathComponent("parakeet-cli/parakeet"),
            home.appendingPathComponent(".local/bin/parakeet"),
            URL(fileURLWithPath: "/opt/homebrew/bin/parakeet"),
            URL(fileURLWithPath: "/usr/local/bin/parakeet")
        ].compactMap { $0 }

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static var installHint: String {
        "Install Parakeet locally with Homebrew: brew install lucataco/tap/parakeet-cli"
    }

    static func modelExists(for model: STTModel) -> Bool {
        guard model.engine == .parakeetCLI,
              let directory = model.localModelURL else { return false }

        let requiredShared = ["vocab.txt", "config.json"]
        let requiredVariant: [String]
        if model.id.contains("fp16") {
            requiredVariant = ["encoder-model.fp16.onnx", "decoder_joint-model.fp16.onnx"]
        } else {
            requiredVariant = ["encoder-model.int8.onnx", "decoder_joint-model.int8.onnx"]
        }

        return (requiredShared + requiredVariant).allSatisfy {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
    }
}

enum VoxtralRuntime {
    static let defaultModelID = "mlx-community/Voxtral-Mini-4B-Realtime-6bit"

    static func executableURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let resource = Bundle.main.resourceURL
        let candidates = [
            resource?.appendingPathComponent("voxmlx"),
            resource?.appendingPathComponent("voxmlx/voxmlx"),
            home.appendingPathComponent(".local/bin/voxmlx"),
            URL(fileURLWithPath: "/opt/homebrew/bin/voxmlx"),
            URL(fileURLWithPath: "/usr/local/bin/voxmlx")
        ].compactMap { $0 }

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func uvExecutableURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".local/bin/uv"),
            URL(fileURLWithPath: "/opt/homebrew/bin/uv"),
            URL(fileURLWithPath: "/usr/local/bin/uv")
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static var installHint: String {
        "Install Voxtral MLX locally with uv: uv tool install voxmlx"
    }

    static func modelExists(for model: STTModel) -> Bool {
        guard model.engine == .voxtralMLX,
              let directory = model.localModelURL else { return false }

        let markerFiles = ["config.json", "tokenizer_config.json"]
        let hasMarker = markerFiles.contains {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }
        return hasMarker
    }
}

enum ModelPreferences {
    private static let selectedModelKey = "selectedSTTModelID"

    static var selectedModel: STTModel {
        get {
            guard let id = UserDefaults.standard.string(forKey: selectedModelKey),
                  let model = model(for: id) else {
                return defaultModel
            }
            return model
        }
        set {
            UserDefaults.standard.set(newValue.id, forKey: selectedModelKey)
        }
    }

    static let defaultModelID = "apple-en-US-ondevice"

    static var defaultModel: STTModel {
        model(for: defaultModelID) ?? availableModels[0]
    }

    static func model(for id: String) -> STTModel? {
        let aliases = [
            "whisper-large-v3-turbo-q8": "whisper-large-v3-turbo-q5",
            "parakeet-tdt-0.6b-v3": "parakeet-tdt-0.6b-v3-int8"
        ]
        let normalizedID = aliases[id] ?? id
        return availableModels.first { $0.id == normalizedID }
    }
}

private func hfModelURL(_ fileName: String) -> URL {
    URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
}

private let whisperTierModels: [STTModel] = [
    STTModel(
        id: "whisper-large-v3-turbo-q5",
        name: "Whisper Large-v3 Turbo Q5_0",
        shortName: "Whisper Turbo",
        engine: .whisperCpp,
        locale: nil,
        onDeviceOnly: true,
        languageCode: nil,
        summary: "Best Whisper quality at the smallest size",
        speedRank: 3,
        accuracyRank: 5,
        accuracyLabel: "low WER",
        downloadSize: "574 MB",
        memoryRequirement: "~2.5 GB",
        fileName: "ggml-large-v3-turbo-q5_0.bin",
        downloadURL: hfModelURL("ggml-large-v3-turbo-q5_0.bin"),
        expectedBytes: 574041195,
        expectedSHA256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
        isQuickChoice: true
    )
]

private let parakeetTierModels: [STTModel] = [
    STTModel(
        id: "parakeet-tdt-0.6b-v3-int8",
        name: "Parakeet TDT 0.6B V3 INT8",
        shortName: "Parakeet",
        engine: .parakeetCLI,
        locale: nil,
        onDeviceOnly: true,
        languageCode: "en",
        summary: "Best Parakeet quality at the smallest size",
        speedRank: 4,
        accuracyRank: 5,
        accuracyLabel: "very low WER",
        downloadSize: "670 MB",
        memoryRequirement: "~1.2 GB",
        fileName: "parakeet-tdt-0.6b-v3-int8",
        downloadURL: nil,
        isQuickChoice: true
    )
]

private let voxtralTierModels: [STTModel] = [
    STTModel(
        id: "voxtral-mini-realtime-6bit",
        name: "Voxtral Mini Realtime 4B 6-bit MLX",
        shortName: "Voxtral 6-bit",
        engine: .voxtralMLX,
        locale: nil,
        onDeviceOnly: true,
        languageCode: nil,
        summary: "Realtime-capable MLX model",
        speedRank: 3,
        accuracyRank: 5,
        accuracyLabel: "top-tier WER",
        downloadSize: "3.62 GB",
        memoryRequirement: "~6 GB",
        fileName: "voxtral-mini-4b-realtime-6bit",
        downloadURL: nil,
        isQuickChoice: true
    )
]

let availableModels: [STTModel] = [
    STTModel(
        id: "apple-en-US-ondevice",
        name: "Apple Speech English (US) - On-Device",
        shortName: "Apple EN-US",
        engine: .appleSpeech,
        locale: Locale(identifier: "en-US"),
        onDeviceOnly: true,
        languageCode: "en",
        summary: "Live, private, lowest CPU",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: true
    ),
    STTModel(
        id: "apple-en-US-server",
        name: "Apple Speech English (US) - Server",
        shortName: "Apple EN-US Server",
        engine: .appleSpeech,
        locale: Locale(identifier: "en-US"),
        onDeviceOnly: false,
        languageCode: "en",
        summary: "Live, can be more accurate, may use network",
        speedRank: 5,
        accuracyRank: 4,
        accuracyLabel: "lower WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: false
    ),
    STTModel(
        id: "apple-en-GB-ondevice",
        name: "Apple Speech English (UK) - On-Device",
        shortName: "Apple EN-GB",
        engine: .appleSpeech,
        locale: Locale(identifier: "en-GB"),
        onDeviceOnly: true,
        languageCode: "en",
        summary: "Live, private, UK English",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: true
    ),
    STTModel(
        id: "apple-es-ES-ondevice",
        name: "Apple Speech Spanish - On-Device",
        shortName: "Apple ES",
        engine: .appleSpeech,
        locale: Locale(identifier: "es-ES"),
        onDeviceOnly: true,
        languageCode: "es",
        summary: "Live, private, Spanish",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: false
    ),
    STTModel(
        id: "apple-fr-FR-ondevice",
        name: "Apple Speech French - On-Device",
        shortName: "Apple FR",
        engine: .appleSpeech,
        locale: Locale(identifier: "fr-FR"),
        onDeviceOnly: true,
        languageCode: "fr",
        summary: "Live, private, French",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: false
    ),
    STTModel(
        id: "apple-de-DE-ondevice",
        name: "Apple Speech German - On-Device",
        shortName: "Apple DE",
        engine: .appleSpeech,
        locale: Locale(identifier: "de-DE"),
        onDeviceOnly: true,
        languageCode: "de",
        summary: "Live, private, German",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: false
    ),
    STTModel(
        id: "apple-ja-JP-ondevice",
        name: "Apple Speech Japanese - On-Device",
        shortName: "Apple JA",
        engine: .appleSpeech,
        locale: Locale(identifier: "ja-JP"),
        onDeviceOnly: true,
        languageCode: "ja",
        summary: "Live, private, Japanese",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: false
    ),
    STTModel(
        id: "apple-zh-CN-ondevice",
        name: "Apple Speech Chinese (Mandarin) - On-Device",
        shortName: "Apple ZH",
        engine: .appleSpeech,
        locale: Locale(identifier: "zh-CN"),
        onDeviceOnly: true,
        languageCode: "zh",
        summary: "Live, private, Mandarin",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium CER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: false
    ),
    STTModel(
        id: "apple-pt-BR-ondevice",
        name: "Apple Speech Portuguese (BR) - On-Device",
        shortName: "Apple PT-BR",
        engine: .appleSpeech,
        locale: Locale(identifier: "pt-BR"),
        onDeviceOnly: true,
        languageCode: "pt",
        summary: "Live, private, Portuguese",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: false
    ),
    STTModel(
        id: "apple-it-IT-ondevice",
        name: "Apple Speech Italian - On-Device",
        shortName: "Apple IT",
        engine: .appleSpeech,
        locale: Locale(identifier: "it-IT"),
        onDeviceOnly: true,
        languageCode: "it",
        summary: "Live, private, Italian",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: false
    ),
    STTModel(
        id: "apple-ko-KR-ondevice",
        name: "Apple Speech Korean - On-Device",
        shortName: "Apple KO",
        engine: .appleSpeech,
        locale: Locale(identifier: "ko-KR"),
        onDeviceOnly: true,
        languageCode: "ko",
        summary: "Live, private, Korean",
        speedRank: 5,
        accuracyRank: 3,
        accuracyLabel: "medium WER",
        downloadSize: nil,
        fileName: nil,
        downloadURL: nil,
        isQuickChoice: false
    )
]
    + whisperTierModels
    + parakeetTierModels
    + voxtralTierModels

let quickModelChoices: [STTModel] = availableModels.filter { $0.isQuickChoice }
