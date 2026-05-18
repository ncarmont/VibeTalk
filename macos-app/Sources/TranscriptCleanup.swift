import Foundation

enum TranscriptCleanupPreferences {
    private static let enabledKey = "liquidTranscriptCleanupEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}

enum TranscriptCleanupRuntime {
    static let modelName = "LiquidAI/LFM2.5-350M"
    static let modelReference = "LiquidAI/LFM2.5-350M-GGUF:Q4_K_M"
    static let modelFileName = "LFM2.5-350M-Q4_K_M.gguf"

    static var localModelURL: URL {
        ModelStorage.modelsDirectory.appendingPathComponent(modelFileName)
    }

    static var localModelExists: Bool {
        FileManager.default.fileExists(atPath: localModelURL.path)
    }

    static func executableURL() -> URL? {
        let resource = Bundle.main.resourceURL
        let candidates = [
            resource?.appendingPathComponent("llama.cpp/llama-completion"),
            resource?.appendingPathComponent("llama-completion"),
            URL(fileURLWithPath: "/opt/homebrew/bin/llama-completion"),
            URL(fileURLWithPath: "/usr/local/bin/llama-completion"),
            resource?.appendingPathComponent("llama.cpp/llama-cli"),
            resource?.appendingPathComponent("llama-cli"),
            URL(fileURLWithPath: "/opt/homebrew/bin/llama-cli"),
            URL(fileURLWithPath: "/usr/local/bin/llama-cli"),
            URL(fileURLWithPath: "/opt/homebrew/bin/llama"),
            URL(fileURLWithPath: "/usr/local/bin/llama")
        ].compactMap { $0 }

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func isCompletionBinary(_ url: URL) -> Bool {
        url.lastPathComponent == "llama-completion"
    }

    static var installHint: String {
        "Install llama.cpp locally with Homebrew: brew install llama.cpp"
    }

    static var tooltip: String {
        "\(modelName) Q4_K_M via llama.cpp. Put \(modelFileName) in VibeTalk's Models folder, or let llama.cpp use its Hugging Face cache."
    }
}

final class TranscriptCleanupService {
    static let shared = TranscriptCleanupService()

    private init() {}

    func improve(_ text: String, onStream: ((String) -> Void)? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                completion(.success(try self.improve(text, onStream: onStream)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func improve(_ text: String, onStream: ((String) -> Void)? = nil) throws -> String {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return "" }
        guard source.count <= 12_000 else {
            throw TranscriptionError.message("LLM formatting skipped because the transcript is too long.")
        }

        guard let executableURL = TranscriptCleanupRuntime.executableURL() else {
            throw TranscriptionError.message(TranscriptCleanupRuntime.installHint)
        }

        let output = try runLiquidCleanup(executableURL: executableURL, source: source, onStream: onStream)
        let cleaned = normalizeOutput(output)
        guard !cleaned.isEmpty else {
            throw TranscriptionError.message("LLM formatting returned an empty transcript.")
        }

        try validate(cleaned: cleaned, source: source)
        return cleaned
    }

    private static func normalizeStreamChunk(_ accumulated: String) -> String {
        // llama-completion echoes roles+prompt before generating — only show post-assistant text
        let marker = "\nassistant\n"
        guard let range = accumulated.range(of: marker, options: .backwards) else { return "" }
        var t = String(accumulated[range.upperBound...])
        // Strip partial/complete EOF marker
        if let eofRange = t.range(of: "\n> EOF") { t = String(t[..<eofRange.lowerBound]) }
        else if let eofRange = t.range(of: "> EOF") { t = String(t[..<eofRange.lowerBound]) }
        // Legacy chatml special tokens (llama-cli fallback)
        for token in ["<|im_end|>", "<|endoftext|>", "<|eot_id|>"] { t = t.replacingOccurrences(of: token, with: "") }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runLiquidCleanup(executableURL: URL, source: String, onStream: ((String) -> Void)? = nil) throws -> String {
        let maxNewTokens = maxNewTokens(for: source)
        let usingLocalModel = TranscriptCleanupRuntime.localModelExists
        let useCompletion = TranscriptCleanupRuntime.isCompletionBinary(executableURL)
        let ctxSize = max(512, min(2048, source.split { $0.isWhitespace }.count * 2 + maxNewTokens + 100))

        let process = Process()
        process.executableURL = executableURL

        var args: [String]
        if usingLocalModel {
            args = ["-m", TranscriptCleanupRuntime.localModelURL.path]
        } else {
            args = ["-hf", TranscriptCleanupRuntime.modelReference]
        }

        if useCompletion {
            args += [
                "--no-perf",
                "--ctx-size", "\(ctxSize)",
                "--temp", "0.1",
                "--top-k", "50",
                "--repeat-penalty", "1.05",
                "-n", "\(maxNewTokens)",
                "-sys", buildSystemPrompt(),
                "-p", source
            ]
        } else {
            args += [
                "--no-display-prompt",
                "--simple-io",
                "--ctx-size", "\(ctxSize)",
                "--temp", "0.1",
                "--top-k", "50",
                "--repeat-penalty", "1.05",
                "-n", "\(maxNewTokens)",
                "-p", buildPrompt(for: source)
            ]
        }
        process.arguments = args

        var environment = ProcessInfo.processInfo.environment
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        let execDir = executableURL.deletingLastPathComponent().path
        let existingLibPath = environment["DYLD_LIBRARY_PATH"] ?? ""
        environment["DYLD_LIBRARY_PATH"] = existingLibPath.isEmpty ? execDir : "\(execDir):\(existingLibPath)"
        process.environment = environment

        let outputLock = NSLock()
        let errorLock = NSLock()
        var outputData = Data()
        var errorData = Data()
        var streamAccum = ""

        // PTY for stdout: forces llama-completion to flush tokens immediately instead of buffering
        var masterFd: Int32 = -1
        var slaveFd: Int32 = -1
        let usePTY = openpty(&masterFd, &slaveFd, nil, nil, nil) == 0

        let errorPipe = Pipe()
        var outputPipe: Pipe?

        if usePTY {
            // cfmakeraw disables echo and \n→\r\n translation that would corrupt output
            var t = termios()
            tcgetattr(slaveFd, &t)
            cfmakeraw(&t)
            tcsetattr(slaveFd, TCSANOW, &t)
            process.standardOutput = FileHandle(fileDescriptor: slaveFd, closeOnDealloc: false)
        } else {
            let pipe = Pipe()
            outputPipe = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                outputLock.lock(); outputData.append(data); outputLock.unlock()
                if let onStream, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty {
                    streamAccum += chunk
                    let display = TranscriptCleanupService.normalizeStreamChunk(streamAccum)
                    if !display.isEmpty { DispatchQueue.main.async { onStream(display) } }
                }
            }
            process.standardOutput = pipe
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            errorLock.lock()
            if errorData.count < 16_384 {
                errorData.append(contentsOf: data.prefix(16_384 - errorData.count))
            }
            errorLock.unlock()
        }
        process.standardError = errorPipe

        let processSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in processSemaphore.signal() }

        try process.run()

        // For PTY: close slave in parent so master gets EIO when child exits.
        // Drain master on a background thread so tokens stream in real time.
        let drainSemaphore = DispatchSemaphore(value: 0)
        if usePTY {
            close(slaveFd)
            DispatchQueue.global(qos: .userInitiated).async {
                var buf = [UInt8](repeating: 0, count: 4096)
                while true {
                    let n = Darwin.read(masterFd, &buf, buf.count)
                    if n <= 0 { break }
                    let data = Data(buf[0..<n])
                    outputLock.lock(); outputData.append(data); outputLock.unlock()
                    if let onStream, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty {
                        streamAccum += chunk
                        let display = TranscriptCleanupService.normalizeStreamChunk(streamAccum)
                        if !display.isEmpty { DispatchQueue.main.async { onStream(display) } }
                    }
                }
                close(masterFd)
                drainSemaphore.signal()
            }
        } else {
            drainSemaphore.signal()
        }

        let timeoutSeconds: TimeInterval = usingLocalModel ? 6 : 25
        if processSemaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            _ = processSemaphore.wait(timeout: .now() + 2)
            _ = drainSemaphore.wait(timeout: .now() + 1)
            outputPipe?.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw TranscriptionError.message("LLM formatting timed out, so raw dictation was used.")
        }

        _ = drainSemaphore.wait(timeout: .now() + 2)
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        if let pipe = outputPipe {
            let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
            outputLock.lock(); outputData.append(remaining); outputLock.unlock()
        }

        let remainingError = errorPipe.fileHandleForReading.readDataToEndOfFile()
        errorLock.lock()
        if errorData.count < 16_384 {
            errorData.append(contentsOf: remainingError.prefix(16_384 - errorData.count))
        }
        let capturedError = errorData
        errorLock.unlock()

        outputLock.lock()
        let capturedOutput = outputData
        outputLock.unlock()

        let output = String(data: capturedOutput, encoding: .utf8) ?? ""
        let error = String(data: capturedError, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            let message = error?.isEmpty == false ? error! : "LLM formatting failed."
            throw TranscriptionError.message(message)
        }

        return output
    }

    private func buildSystemPrompt() -> String {
        "You are a transcript formatter. Rules: preserve meaning exactly; do not add facts; do not remove named entities, numbers, dates, URLs, or technical terms; make only tiny targeted edits: fix punctuation, capitalization, and spacing; fix obvious homophones or similar-sounding wrong words where the correct word is unambiguous from context (e.g. 'their'/'there', 'your'/'you're', 'to'/'too', or any word a speech recognizer commonly mishears); make a semantic word substitution only when a word makes no sense in context and the speaker's intent is completely unambiguous; keep the same language; return only the corrected transcript."
    }

    private func buildPrompt(for text: String) -> String {
        "<|startoftext|><|im_start|>system\n\(buildSystemPrompt())<|im_end|>\n<|im_start|>user\nText:\n\(text)<|im_end|>\n<|im_start|>assistant\n"
    }

    private func maxNewTokens(for text: String) -> Int {
        let wordCount = max(1, text.split { $0.isWhitespace || $0.isNewline }.count)
        return min(1024, max(96, Int(Double(wordCount) * 1.3) + 48))
    }

    private func normalizeOutput(_ output: String) -> String {
        var text = output.replacingOccurrences(of: "\r\n", with: "\n")

        // llama-completion format: role headers + "assistant\n{response}\n\n> EOF by user"
        if let assistantRange = text.range(of: "\nassistant\n", options: .backwards) {
            text = String(text[assistantRange.upperBound...])
            if let eofRange = text.range(of: "\n> EOF") { text = String(text[..<eofRange.lowerBound]) }
            else if let eofRange = text.range(of: "> EOF") { text = String(text[..<eofRange.lowerBound]) }
        } else if let assistantRange = text.range(of: "<|im_start|>assistant") {
            // Legacy llama-cli chatml format
            text = String(text[assistantRange.upperBound...])
        }

        let specialTokens = ["<|startoftext|>", "<|im_start|>", "<|im_end|>", "<|endoftext|>", "<|eot_id|>"]
        for token in specialTokens {
            text = text.replacingOccurrences(of: token, with: "")
        }

        text = text.replacingOccurrences(of: #"(?m)^\s*(Corrected transcript|Transcript):\s*"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[ \t]+([,.;:!?])"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"([(\[])[ \t]+"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[ \t]+([)\]])"#, with: "$1", options: .regularExpression)
        text = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\""), text.hasSuffix("\""), text.count > 1 {
            text.removeFirst()
            text.removeLast()
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validate(cleaned: String, source: String) throws {
        let sourceCount = source.count
        let cleanedCount = cleaned.count
        if sourceCount > 80 {
            let lengthDelta = Double(abs(cleanedCount - sourceCount)) / Double(max(sourceCount, 1))
            guard lengthDelta <= 0.15 else {
                throw TranscriptionError.message("LLM formatting changed the transcript length too much.")
            }
        }

        let sourceProtected = protectedTokens(in: source)
        let cleanedProtected = protectedTokens(in: cleaned)
        guard sourceProtected == cleanedProtected else {
            throw TranscriptionError.message("LLM formatting changed a protected token.")
        }

        let sourceWords = wordTokens(in: source)
        let cleanedWords = wordTokens(in: cleaned)
        guard !sourceWords.isEmpty else { return }

        let distance = editDistance(sourceWords, cleanedWords)
        let allowedEdits = max(1, Int(ceil(Double(sourceWords.count) * 0.05)))
        guard distance <= allowedEdits else {
            throw TranscriptionError.message("LLM formatting changed too many words.")
        }
    }

    private func protectedTokens(in text: String) -> [String] {
        let patterns = [
            #"https?://[^\s]+"#,
            #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            #"(?:[$]|USD|GBP|EUR)\s*\d+(?:[.,]\d+)*"#,
            #"\b\d{1,4}(?:[/:.-]\d{1,4}){1,3}\b"#,
            #"\b\d+(?:[.,]\d+)*(?:\s?(?:am|pm|kg|g|ms|s|gb|mb|kb|%))?\b"#
        ]

        var tokens: [String] = []
        for pattern in patterns {
            tokens += matches(pattern: pattern, in: text)
        }
        return tokens.map { $0.lowercased() }.sorted()
    }

    private func wordTokens(in text: String) -> [String] {
        matches(pattern: #"[A-Za-z0-9][A-Za-z0-9'_/-]*"#, in: text)
            .map { $0.lowercased() }
    }

    private func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    private func editDistance(_ lhs: [String], _ rhs: [String]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        var previous = Array(0...rhs.count)
        var current = Array(repeating: 0, count: rhs.count + 1)

        for i in 1...lhs.count {
            current[0] = i
            for j in 1...rhs.count {
                if lhs[i - 1] == rhs[j - 1] {
                    current[j] = previous[j - 1]
                } else {
                    current[j] = min(previous[j], current[j - 1], previous[j - 1]) + 1
                }
            }
            swap(&previous, &current)
        }

        return previous[rhs.count]
    }
}
