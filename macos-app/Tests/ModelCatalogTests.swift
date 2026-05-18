import AVFoundation
import Foundation
import Speech

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(description: message)
    }
}

func requireNonEmpty(_ value: String, _ message: String) throws {
    try require(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, message)
}

func validateModelCatalog() throws {
    try require(!availableModels.isEmpty, "No STT models are registered.")
    try require(ModelPreferences.model(for: ModelPreferences.defaultModelID) != nil, "Default STT model is missing.")
    try require(!quickModelChoices.isEmpty, "No quick-choice STT models are registered.")

    var seenIDs = Set<String>()

    for model in availableModels {
        try require(seenIDs.insert(model.id).inserted, "Duplicate model id: \(model.id)")
        try requireNonEmpty(model.name, "\(model.id) has an empty name.")
        try requireNonEmpty(model.shortName, "\(model.id) has an empty short name.")
        try requireNonEmpty(model.summary, "\(model.id) has an empty summary.")
        try require((1...5).contains(model.speedRank), "\(model.id) has invalid speed rank.")
        try require((1...5).contains(model.accuracyRank), "\(model.id) has invalid accuracy rank.")

        switch model.engine {
        case .appleSpeech:
            try require(model.locale != nil, "\(model.id) needs an Apple Speech locale.")
            try require(model.fileName == nil, "\(model.id) should not define a local model file.")
            try require(model.downloadURL == nil, "\(model.id) should not define a download URL.")

        case .whisperCpp:
            try require(model.fileName?.hasSuffix(".bin") == true, "\(model.id) must point at a GGML .bin file.")
            try require(model.downloadURL?.host == "huggingface.co", "\(model.id) must download from Hugging Face.")
            try require((model.expectedBytes ?? 0) > 0, "\(model.id) must define expected byte size.")
            try require(model.expectedSHA256?.count == 64, "\(model.id) must define a SHA-256 checksum.")

        case .parakeetCLI:
            try requireNonEmpty(model.fileName ?? "", "\(model.id) must define a model directory.")
            try require(model.downloadURL == nil, "\(model.id) should use the Parakeet downloader.")

        case .voxtralMLX:
            try requireNonEmpty(model.fileName ?? "", "\(model.id) must define a model directory.")
            try require(model.downloadURL == nil, "\(model.id) should use the Voxtral downloader.")
        }

        if model.isAvailable {
            try require(model.statusText == "Ready", "\(model.id) is available but status is \(model.statusText).")
        }
    }
}

func selfTestAvailableModels() throws {
    let readyModels = availableModels.filter { !$0.isAppleSpeech && $0.isAvailable }
    if readyModels.isEmpty {
        print("No downloaded local CLI models are ready for command-line self-test.")
        print("Apple Speech self-test runs from the VibeTalk app bundle because macOS requires app privacy keys.")
        return
    }

    let engine = TranscriptionEngine()

    for model in readyModels {
        print("Self-testing \(model.id)...")
        let semaphore = DispatchSemaphore(value: 0)
        var testResult: Result<String, Error>?

        DispatchQueue.main.async {
            engine.testModel(model) { result in
                testResult = result
                semaphore.signal()
            }
        }

        while semaphore.wait(timeout: .now() + 0.05) == .timedOut {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
        }

        switch testResult {
        case .success(let message):
            print("  PASS \(message)")
        case .failure(let error):
            throw TestFailure(description: "\(model.id) failed self-test: \(error.localizedDescription)")
        case .none:
            throw TestFailure(description: "\(model.id) did not return a self-test result.")
        }
    }
}

@main
struct ModelCatalogTestRunner {
    static func main() {
        do {
            try validateModelCatalog()

            if CommandLine.arguments.contains("--self-test-available") {
                try selfTestAvailableModels()
            }

            print("Model catalog tests passed for \(availableModels.count) models.")
        } catch {
            fputs("Model tests failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
