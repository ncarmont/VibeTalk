import Cocoa
import CryptoKit

final class ModelSettingsWindowController: NSObject, URLSessionDownloadDelegate {
    private var panel: NSPanel!
    private var bgView: NSView!
    private var anchorFrame: NSRect = .zero
    private var selectedModel: STTModel = ModelPreferences.selectedModel
    private var downloadSession: URLSession!
    private var downloadTask: URLSessionDownloadTask?
    private var externalDownloadProcess: Process?
    private var downloadingModel: STTModel?
    private var downloadProgress: Double = 0
    private var statusMessage: String?

    private(set) var isVisible = false
    var onModelSelected: ((STTModel) -> Void)?

    private let panelW: CGFloat = 412
    private let panelH: CGFloat = 448
    private let hPad: CGFloat = 16
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)
    private let accentLight = NSColor(red: 0.66, green: 0.55, blue: 0.98, alpha: 1.0)

    override init() {
        super.init()
        downloadSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        buildPanel()
    }

    func toggle(anchorFrame: NSRect, selectedModel: STTModel) -> Bool {
        if isVisible {
            close()
            return false
        }
        open(anchorFrame: anchorFrame, selectedModel: selectedModel)
        return true
    }

    func open(anchorFrame: NSRect, selectedModel: STTModel) {
        self.anchorFrame = anchorFrame
        self.selectedModel = selectedModel
        rebuild()
        updatePosition(anchorFrame: anchorFrame)
        isVisible = true
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1.0
        }
    }

    func close() {
        isVisible = false
        panel.orderOut(nil)
    }

    func setSelectedModel(_ model: STTModel) {
        selectedModel = model
        if isVisible { rebuild() }
    }

    func updatePosition(anchorFrame: NSRect) {
        self.anchorFrame = anchorFrame

        let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchorFrame) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var x = anchorFrame.midX - panelW / 2
        let maxX = max(visible.minX + 4, visible.maxX - panelW - 4)
        x = min(max(x, visible.minX + 4), maxX)

        var y = anchorFrame.maxY + 8
        if y + panelH > visible.maxY - 4 {
            y = anchorFrame.minY - panelH - 8
        }
        y = min(max(y, visible.minY + 4), max(visible.minY + 4, visible.maxY - panelH - 4))

        panel.setFrame(NSRect(x: x, y: y, width: panelW, height: panelH), display: false)
    }

    private func buildPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelW, height: panelH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false

        bgView = NSView(frame: NSRect(x: 0, y: 0, width: panelW, height: panelH))
        bgView.wantsLayer = true
        bgView.layer?.cornerRadius = 14
        bgView.layer?.backgroundColor = NSColor(red: 0.067, green: 0.067, blue: 0.078, alpha: 0.98).cgColor
        bgView.layer?.borderWidth = 1
        bgView.layer?.borderColor = accent.withAlphaComponent(0.28).cgColor
        panel.contentView = bgView
    }

    private func rebuild() {
        bgView.subviews.forEach { $0.removeFromSuperview() }

        let title = label("Speech Model", size: 13, weight: .semibold, frame: NSRect(x: hPad, y: panelH - 34, width: 150, height: 18))
        title.textColor = NSColor(white: 1, alpha: 0.86)
        bgView.addSubview(title)

        let current = label("Using \(selectedModel.shortName)", size: 11.5, weight: .medium, frame: NSRect(x: panelW - 186, y: panelH - 34, width: 170, height: 18))
        current.alignment = .right
        current.textColor = accentLight.withAlphaComponent(0.9)
        bgView.addSubview(current)

        let whisperRuntime = WhisperRuntime.executableURL() == nil ? "Whisper missing" : "Whisper ready"
        let parakeetRuntime = ParakeetRuntime.executableURL() == nil ? "Parakeet missing" : "Parakeet ready"
        let voxtralRuntime = VoxtralRuntime.executableURL() == nil ? "Voxtral missing" : "Voxtral ready"
        let runtimeText = "\(whisperRuntime) / \(parakeetRuntime) / \(voxtralRuntime)"
        let runtime = label(runtimeText, size: 11, weight: .regular, frame: NSRect(x: hPad, y: panelH - 55, width: panelW - hPad * 2, height: 16))
        runtime.textColor = WhisperRuntime.executableURL() == nil || ParakeetRuntime.executableURL() == nil || VoxtralRuntime.executableURL() == nil
            ? NSColor.systemYellow
            : NSColor(white: 1, alpha: 0.38)
        runtime.toolTip = "\(WhisperRuntime.installHint). \(ParakeetRuntime.installHint). \(VoxtralRuntime.installHint)."
        bgView.addSubview(runtime)

        let rowH: CGFloat = 62
        let gap: CGFloat = 8
        let listY: CGFloat = 42
        let listH: CGFloat = panelH - 111 - listY + rowH
        let listW = panelW - hPad * 2
        let contentH = CGFloat(quickModelChoices.count) * (rowH + gap) - gap

        let scrollView = NSScrollView(frame: NSRect(x: hPad, y: listY, width: listW, height: listH))
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: listW - 14, height: max(listH, contentH)))
        scrollView.documentView = documentView
        bgView.addSubview(scrollView)

        var y = documentView.frame.height - rowH
        for model in quickModelChoices {
            let row = modelRow(model, frame: NSRect(x: 0, y: y, width: documentView.frame.width, height: rowH))
            documentView.addSubview(row)
            y -= rowH + gap
        }

        let footerText = statusMessage ?? "Disk is exact when installed; RAM is runtime estimate and varies by audio length."
        let footer = label(footerText, size: 11, weight: .regular, frame: NSRect(x: hPad, y: 13, width: panelW - hPad * 2, height: 16))
        footer.textColor = statusMessage == nil ? NSColor(white: 1, alpha: 0.34) : NSColor.systemYellow
        bgView.addSubview(footer)
    }

    private func modelRow(_ model: STTModel, frame: NSRect) -> NSView {
        let row = NSView(frame: frame)
        row.wantsLayer = true
        row.layer?.cornerRadius = 10
        row.layer?.backgroundColor = selectedModel == model
            ? accent.withAlphaComponent(0.18).cgColor
            : NSColor(white: 1, alpha: 0.045).cgColor
        row.layer?.borderWidth = 1
        row.layer?.borderColor = selectedModel == model
            ? accent.withAlphaComponent(0.42).cgColor
            : NSColor(white: 1, alpha: 0.07).cgColor
        row.toolTip = model.tooltipText + " Lower WER means fewer word mistakes."

        let name = label(model.shortName, size: 12.5, weight: .semibold, frame: NSRect(x: 12, y: 39, width: 138, height: 17))
        name.textColor = NSColor(white: 1, alpha: 0.9)
        row.addSubview(name)

        let summary = label(model.summary, size: 10.5, weight: .regular, frame: NSRect(x: 12, y: 23, width: 150, height: 15))
        summary.textColor = NSColor(white: 1, alpha: 0.38)
        row.addSubview(summary)

        let footprint = label(model.footprintText, size: 10.5, weight: .medium, frame: NSRect(x: 12, y: 7, width: frame.width - 104, height: 15))
        footprint.textColor = NSColor(white: 1, alpha: 0.50)
        row.addSubview(footprint)

        row.addSubview(metric("Speed", value: model.speedRank, x: 170, y: 39))
        row.addSubview(metric("Accuracy", value: model.accuracyRank, x: 170, y: 23))

        let action = actionButton(for: model, frame: NSRect(x: frame.width - 84, y: 19, width: 72, height: 24))
        row.addSubview(action)

        if downloadingModel == model {
            let bar = NSView(frame: NSRect(x: 12, y: 0, width: max(4, (frame.width - 24) * CGFloat(downloadProgress)), height: 2))
            bar.wantsLayer = true
            bar.layer?.cornerRadius = 1
            bar.layer?.backgroundColor = accentLight.cgColor
            row.addSubview(bar)
        }

        return row
    }

    private func actionButton(for model: STTModel, frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        button.contentTintColor = .white
        button.identifier = NSUserInterfaceItemIdentifier(model.id)

        if downloadingModel == model {
            button.title = "\(Int(downloadProgress * 100))%"
            button.isEnabled = false
            button.layer?.backgroundColor = accent.withAlphaComponent(0.42).cgColor
        } else if selectedModel == model {
            button.title = "Selected"
            button.isEnabled = false
            button.layer?.backgroundColor = accent.withAlphaComponent(0.36).cgColor
        } else if model.needsDownload {
            if model.isExternalDownloaderModel && !model.isRuntimeAvailable {
                button.title = "Runtime"
                button.isEnabled = false
                button.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.30).cgColor
                button.toolTip = model.runtimeInstallHint
                return button
            }
            button.title = "Download"
            button.target = self
            button.action = #selector(downloadPressed(_:))
            button.layer?.backgroundColor = accent.cgColor
        } else if !model.isRuntimeAvailable {
            button.title = "Runtime"
            button.isEnabled = false
            button.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.30).cgColor
            button.toolTip = model.runtimeInstallHint
        } else if model.isAvailable {
            button.title = "Use"
            button.target = self
            button.action = #selector(selectPressed(_:))
            button.layer?.backgroundColor = accent.cgColor
        } else {
            button.title = "Unavailable"
            button.isEnabled = false
            button.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        }

        return button
    }

    private func metric(_ title: String, value: Int, x: CGFloat, y: CGFloat) -> NSView {
        let view = NSView(frame: NSRect(x: x, y: y, width: 118, height: 12))

        let titleLabel = label(title, size: 9.5, weight: .medium, frame: NSRect(x: 0, y: -1, width: 46, height: 12))
        titleLabel.textColor = NSColor(white: 1, alpha: 0.34)
        view.addSubview(titleLabel)

        for i in 0..<5 {
            let dot = NSView(frame: NSRect(x: 52 + CGFloat(i) * 10, y: 3, width: 6, height: 6))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 3
            dot.layer?.backgroundColor = i < value
                ? accentLight.withAlphaComponent(0.92).cgColor
                : NSColor(white: 1, alpha: 0.12).cgColor
            view.addSubview(dot)
        }
        return view
    }

    private func pill(_ text: String, x: CGFloat, y: CGFloat) -> NSView {
        let width = min(58, max(42, CGFloat(text.count) * 6.2 + 14))
        let view = NSView(frame: NSRect(x: x, y: y, width: width, height: 14))
        view.wantsLayer = true
        view.layer?.cornerRadius = 7
        view.layer?.backgroundColor = NSColor(white: 1, alpha: 0.075).cgColor
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor(white: 1, alpha: 0.10).cgColor

        let textLabel = label(text, size: 9, weight: .semibold, frame: NSRect(x: 0, y: 1, width: width, height: 12))
        textLabel.alignment = .center
        textLabel.textColor = NSColor(white: 1, alpha: 0.46)
        view.addSubview(textLabel)
        return view
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, frame: NSRect) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = .white
        return label
    }

    @objc private func selectPressed(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let model = ModelPreferences.model(for: id) else { return }
        statusMessage = nil
        onModelSelected?(model)
    }

    @objc private func downloadPressed(_ sender: NSButton) {
        guard downloadTask == nil,
              externalDownloadProcess == nil,
              let id = sender.identifier?.rawValue,
              let model = ModelPreferences.model(for: id) else { return }

        do {
            try ModelStorage.ensureModelsDirectory()
        } catch {
            statusMessage = "Could not create model folder."
            rebuild()
            return
        }

        statusMessage = "Downloading \(model.shortName)..."
        downloadingModel = model
        downloadProgress = 0
        rebuild()

        if model.isExternalDownloaderModel {
            startExternalModelDownload(model)
            return
        }

        guard let url = model.downloadURL else { return }
        let task = downloadSession.downloadTask(with: url)
        downloadTask = task
        task.resume()
    }

    private func startExternalModelDownload(_ model: STTModel) {
        guard model.engine == .parakeetCLI,
              let executableURL = ParakeetRuntime.executableURL(),
              let modelDirectory = model.localModelURL else {
            if model.engine == .voxtralMLX {
                startVoxtralModelDownload(model)
            } else {
                statusMessage = model.runtimeInstallHint
                downloadingModel = nil
                rebuild()
            }
            return
        }

        do {
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        } catch {
            statusMessage = "Could not create model folder."
            downloadingModel = nil
            rebuild()
            return
        }

        let process = Process()
        process.executableURL = executableURL
        var args = ["download", "--model-dir", modelDirectory.path]
        if model.id.contains("fp16") {
            args.append("--fp16")
        }
        process.arguments = args

        externalDownloadProcess = process
        downloadProgress = 0.12
        statusMessage = "Downloading \(model.shortName)..."
        rebuild()

        process.terminationHandler = { [weak self, weak process] completed in
            DispatchQueue.main.async {
                guard let self, self.externalDownloadProcess === process else { return }
                self.externalDownloadProcess = nil
                self.downloadingModel = nil
                self.downloadProgress = 0

                if completed.terminationStatus == 0, ParakeetRuntime.modelExists(for: model) {
                    self.statusMessage = "\(model.shortName) downloaded and verified."
                } else {
                    self.statusMessage = "Parakeet download failed."
                    try? FileManager.default.removeItem(at: modelDirectory)
                }
                self.rebuild()
            }
        }

        do {
            try process.run()
        } catch {
            externalDownloadProcess = nil
            downloadingModel = nil
            downloadProgress = 0
            statusMessage = "Download failed: \(error.localizedDescription)"
            rebuild()
        }
    }

    private func startVoxtralModelDownload(_ model: STTModel) {
        guard let modelDirectory = model.localModelURL,
              let uvURL = VoxtralRuntime.uvExecutableURL() else {
            statusMessage = VoxtralRuntime.installHint
            downloadingModel = nil
            rebuild()
            return
        }

        do {
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        } catch {
            statusMessage = "Could not create model folder."
            downloadingModel = nil
            rebuild()
            return
        }

        let process = Process()
        process.executableURL = uvURL
        process.arguments = [
            "run",
            "--with",
            "huggingface-hub",
            "python",
            "-c",
            "from huggingface_hub import snapshot_download; snapshot_download('\(VoxtralRuntime.defaultModelID)', local_dir='\(modelDirectory.path)', local_dir_use_symlinks=False)"
        ]

        externalDownloadProcess = process
        downloadProgress = 0.12
        statusMessage = "Downloading \(model.shortName)..."
        rebuild()

        process.terminationHandler = { [weak self, weak process] completed in
            DispatchQueue.main.async {
                guard let self, self.externalDownloadProcess === process else { return }
                self.externalDownloadProcess = nil
                self.downloadingModel = nil
                self.downloadProgress = 0

                if completed.terminationStatus == 0, VoxtralRuntime.modelExists(for: model) {
                    self.statusMessage = "\(model.shortName) downloaded."
                } else {
                    self.statusMessage = "Voxtral download failed."
                    try? FileManager.default.removeItem(at: modelDirectory)
                }
                self.rebuild()
            }
        }

        do {
            try process.run()
        } catch {
            externalDownloadProcess = nil
            downloadingModel = nil
            downloadProgress = 0
            statusMessage = "Download failed: \(error.localizedDescription)"
            rebuild()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        downloadProgress = min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        rebuild()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let model = downloadingModel,
              let targetURL = model.localModelURL else { return }

        do {
            try ModelStorage.ensureModelsDirectory()
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.moveItem(at: location, to: targetURL)
            try verifyDownloadedModel(model, at: targetURL)
            statusMessage = "\(model.shortName) downloaded and verified."
        } catch {
            try? FileManager.default.removeItem(at: targetURL)
            statusMessage = "Download failed: \(error.localizedDescription)"
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            statusMessage = "Download failed: \(error.localizedDescription)"
        }
        downloadTask = nil
        downloadingModel = nil
        downloadProgress = 0
        rebuild()
    }

    deinit {
        downloadTask?.cancel()
        externalDownloadProcess?.terminate()
        downloadSession.invalidateAndCancel()
    }

    private func verifyDownloadedModel(_ model: STTModel, at url: URL) throws {
        if let expectedBytes = model.expectedBytes {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let actualBytes = (attributes[.size] as? NSNumber)?.int64Value ?? -1
            guard actualBytes == expectedBytes else {
                throw TranscriptionError.message("Model size mismatch.")
            }
        }

        if let expectedSHA256 = model.expectedSHA256 {
            let actualSHA256 = try sha256Hex(for: url)
            guard actualSHA256.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
                throw TranscriptionError.message("Model checksum mismatch.")
            }
        }
    }

    private func sha256Hex(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
