import Cocoa
import QuartzCore

enum PillState: Equatable {
    case idle, recording, processing, success, error, notice
}

class PillPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    var onHotkey: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let m = event.modifierFlags
        let isFnSpace = event.keyCode == 49 && m.contains(.function)
        let isCSSpace = event.keyCode == 49 && m.contains(.control) && m.contains(.shift)
        if isFnSpace || isCSSpace { onHotkey?(); return }
        super.keyDown(with: event)
    }
}

class PillContentView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var onTextClick: (() -> Void)?
    var onDragged: (() -> Void)?
    var onPositionChanged: (() -> Void)?

    private var dragStart: NSPoint?
    private var isDragging = false

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        dragStart = event.locationInWindow
        isDragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let win = window else { return }
        let cur = event.locationInWindow
        if !isDragging {
            if hypot(cur.x - start.x, cur.y - start.y) < 4 { return }
            isDragging = true
        }
        win.setFrameOrigin(NSPoint(x: win.frame.origin.x + cur.x - start.x,
                                   y: win.frame.origin.y + cur.y - start.y))
        onPositionChanged?()
    }
    override func mouseUp(with event: NSEvent) {
        if isDragging { onDragged?() }
        else {
            let loc = convert(event.locationInWindow, from: nil)
            if loc.x > 44 { onTextClick?() }
        }
        dragStart = nil; isDragging = false
    }
    override func keyDown(with event: NSEvent) { window?.keyDown(with: event) }
}

// Generic pill icon button
class PillIconButton: NSView {
    var onClick: (() -> Void)?
    private var iconLayer = CALayer()
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, symbolName: String) {
        super.init(frame: frame)
        configure(symbolName: symbolName)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure(symbolName: nil)
    }

    private func configure(symbolName: String?) {
        wantsLayer = true
        layer?.cornerRadius = max(bounds.width, bounds.height) / 2
        iconLayer.contentsGravity = .resizeAspect
        if iconLayer.superlayer == nil {
            layer?.addSublayer(iconLayer)
        }
        if let symbolName,
           let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .medium)) {
            iconLayer.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        iconLayer.frame = bounds.insetBy(dx: 6, dy: 6)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        if let trackingArea { addTrackingArea(trackingArea) }
    }
    override func mouseEntered(with event: NSEvent) { animator().alphaValue = 0.7 }
    override func mouseExited(with event: NSEvent)  { animator().alphaValue = 1.0 }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
}

class MicButtonView: PillIconButton {
    var isRecording = false { didSet { updateColors() } }
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)

    init(frame: NSRect) {
        super.init(frame: frame, symbolName: "mic.fill")
        updateColors()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        updateColors()
    }

    func updateColors() {
        if isRecording {
            layer?.backgroundColor = NSColor.systemRed.cgColor
            if let img = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 11, weight: .bold)) {
                iconLayer.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
        } else {
            layer?.backgroundColor = accent.cgColor
            if let img = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 11, weight: .bold)) {
                iconLayer.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
        }
    }

    // Expose iconLayer for subclassing
    var iconLayer: CALayer { (layer?.sublayers?.first(where: { $0 !== layer })) ?? CALayer() }
}

// Hacky but MicButtonView needs its own iconLayer reference — let's fix via composition
// Override approach: rebuild MicButtonView cleanly
class MicButton: NSView {
    var onClick: (() -> Void)?
    var isRecording = false { didSet { update() } }

    private let iconLayer = CALayer()
    private var tracking: NSTrackingArea?
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)

    override init(frame: NSRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = max(bounds.width, bounds.height) / 2
        iconLayer.contentsGravity = .resizeAspect
        if iconLayer.superlayer == nil {
            layer?.addSublayer(iconLayer)
        }
        update()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func layout() { super.layout(); iconLayer.frame = bounds.insetBy(dx: 7, dy: 7) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        if let tracking { addTrackingArea(tracking) }
    }
    override func mouseEntered(with event: NSEvent) { NSAnimationContext.runAnimationGroup { $0.duration = 0.15; animator().alphaValue = 0.8 } }
    override func mouseExited(with event: NSEvent)  { NSAnimationContext.runAnimationGroup { $0.duration = 0.15; animator().alphaValue = 1.0 } }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
    func update() {
        let sym = isRecording ? "stop.fill" : "mic.fill"
        layer?.backgroundColor = isRecording ? NSColor.systemRed.cgColor : accent.cgColor
        if let img = NSImage(systemSymbolName: sym, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .bold)) {
            iconLayer.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    }
}

// Small history toggle button for the right end of the pill
class HistoryButton: NSView {
    var onClick: (() -> Void)?
    var isOpen = false { didSet { updateTint() } }
    private let iconLayer = CALayer()
    private var tracking: NSTrackingArea?
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)

    override init(frame: NSRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = max(bounds.width, bounds.height) / 2
        layer?.backgroundColor = accent.withAlphaComponent(0.42).cgColor
        iconLayer.contentsGravity = .resizeAspect
        if iconLayer.superlayer == nil {
            layer?.addSublayer(iconLayer)
        }
        toolTip = "Last chats"
        updateTint()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func layout() { super.layout(); iconLayer.frame = bounds.insetBy(dx: 5, dy: 5) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        if let tracking { addTrackingArea(tracking) }
    }
    override func mouseEntered(with event: NSEvent) { layer?.backgroundColor = accent.withAlphaComponent(0.58).cgColor }
    override func mouseExited(with event: NSEvent)  { updateTint() }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
    private func updateTint() {
        let sym = "clock.arrow.circlepath"
        let alpha: CGFloat = isOpen ? 1.0 : 0.9
        layer?.backgroundColor = accent.withAlphaComponent(isOpen ? 0.62 : 0.42).cgColor
        if let img = NSImage(systemSymbolName: sym, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .medium)) {
            iconLayer.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        iconLayer.opacity = Float(alpha)
    }
}

// Small screenshot paste button for the left end of the pill
class ScreenshotButton: NSView {
    var onClick: (() -> Void)?
    var isOpen: Bool = false { didSet { updateTint() } }
    private let iconLayer = CALayer()
    private var tracking: NSTrackingArea?
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)

    override init(frame: NSRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = max(bounds.width, bounds.height) / 2
        iconLayer.contentsGravity = .resizeAspect
        if iconLayer.superlayer == nil {
            layer?.addSublayer(iconLayer)
        }
        toolTip = "Open recent screenshots. Press fn+i to paste the latest screenshot."
        updateTint()
    }

    private func updateTint() {
        layer?.backgroundColor = accent.withAlphaComponent(isOpen ? 0.64 : 0.42).cgColor
        layer?.borderWidth = isOpen ? 1 : 0
        layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        let imageSymbol = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: nil)
        if let img = imageSymbol?
            .withSymbolConfiguration(.init(pointSize: 11, weight: isOpen ? .semibold : .medium)) {
            iconLayer.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
            iconLayer.opacity = isOpen ? 1.0 : 0.92
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func layout() { super.layout(); iconLayer.frame = bounds.insetBy(dx: 5, dy: 5) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        if let tracking { addTrackingArea(tracking) }
    }
    override func mouseEntered(with event: NSEvent) { layer?.backgroundColor = accent.withAlphaComponent(0.58).cgColor }
    override func mouseExited(with event: NSEvent)  { updateTint() }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
}

// Small model settings button beside the image picker
class SettingsButton: NSView {
    var onClick: (() -> Void)?
    private let iconLayer = CALayer()
    private var tracking: NSTrackingArea?
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)

    override init(frame: NSRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = max(bounds.width, bounds.height) / 2
        layer?.backgroundColor = accent.withAlphaComponent(0.42).cgColor
        iconLayer.contentsGravity = .resizeAspect
        if iconLayer.superlayer == nil {
            layer?.addSublayer(iconLayer)
        }
        if let img = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10.5, weight: .medium)) {
            iconLayer.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
            iconLayer.opacity = 0.92
        }
        setModel(ModelPreferences.selectedModel)
    }

    func setModel(_ model: STTModel) {
        toolTip = "Open VibeTalk. Current model: \(model.shortName)."
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func layout() { super.layout(); iconLayer.frame = bounds.insetBy(dx: 5, dy: 5) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        if let tracking { addTrackingArea(tracking) }
    }
    override func mouseEntered(with event: NSEvent) { layer?.backgroundColor = accent.withAlphaComponent(0.58).cgColor }
    override func mouseExited(with event: NSEvent)  { layer?.backgroundColor = accent.withAlphaComponent(0.42).cgColor }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
}

class PillWindowController: NSObject {
    private var window: PillPanel!
    private var contentView: PillContentView!
    private var backgroundView: NSView!
    private var screenshotButton: ScreenshotButton!
    private var settingsButton: SettingsButton!
    private var micButton: MicButton!
    private var historyButton: HistoryButton!
    private var textLabel: NSTextField!
    private var waveformBars: [NSView] = []
    private var waveformTimer: Timer?
    private var state: PillState = .idle
    private var userPositioned = false
    private var previewPanel: NSPanel?

    var onToggle: (() -> Void)?
    var onOpenUI: (() -> Void)?
    var onHistoryToggle: (() -> Void)?
    var onScreenshotPaste: (() -> Void)?
    var onSettingsToggle: (() -> Void)?
    var onFrameChanged: ((NSRect) -> Void)?
    var currentFrame: NSRect { window?.frame ?? .zero }
    var cameraButtonScreenFrame: NSRect {
        guard let screenshotButton = screenshotButton,
              let buttonWindow = screenshotButton.window else {
            return window?.frame ?? .zero
        }
        let buttonFrameInWindow = screenshotButton.convert(screenshotButton.bounds, to: nil)
        return buttonWindow.convertToScreen(buttonFrameInWindow)
    }
    var settingsButtonScreenFrame: NSRect {
        guard let settingsButton = settingsButton,
              let buttonWindow = settingsButton.window else {
            return window?.frame ?? .zero
        }
        let buttonFrameInWindow = settingsButton.convert(settingsButton.bounds, to: nil)
        return buttonWindow.convertToScreen(buttonFrameInWindow)
    }

    private let pillH: CGFloat    = 44
    private let radius: CGFloat   = 22
    private let idleW: CGFloat    = 280
    private let activeW: CGFloat  = 380
    private let maxW: CGFloat     = 580
    private let bottomOff: CGFloat = 48
    private let btnSz: CGFloat    = 32
    private let hBtnSz: CGFloat   = 26   // history button size
    private let ssBtnSz: CGFloat  = 26   // screenshot button size
    private let settingsBtnSz: CGFloat = 26
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)

    override init() {
        super.init()
        setupWindow()
        setupViews()
        setIdle()
        window.onHotkey = { [weak self] in self?.onToggle?() }
    }

    private func setupWindow() {
        let sf = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        window = PillPanel(
            contentRect: NSRect(x: sf.midX - idleW/2, y: sf.minY + bottomOff, width: idleW, height: pillH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
    }

    private func setupViews() {
        contentView = PillContentView(frame: NSRect(x: 0, y: 0, width: idleW, height: pillH))
        contentView.wantsLayer = true
        contentView.onTextClick = { [weak self] in self?.onOpenUI?() }
        contentView.onDragged = { [weak self] in
            guard let s = self else { return }
            s.userPositioned = true
            s.onFrameChanged?(s.window.frame)
        }
        contentView.onPositionChanged = { [weak self] in
            guard let s = self else { return }
            s.onFrameChanged?(s.window.frame)
        }
        window.contentView = contentView

        backgroundView = NSView(frame: NSRect(x: 0, y: 0, width: idleW, height: pillH))
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = radius
        backgroundView.layer?.masksToBounds = true
        backgroundView.layer?.backgroundColor = NSColor(red: 0.067, green: 0.067, blue: 0.078, alpha: 0.82).cgColor
        backgroundView.layer?.borderWidth = 1
        backgroundView.layer?.borderColor = NSColor(white: 1, alpha: 0.08).cgColor
        contentView.addSubview(backgroundView)

        // Mic button
        micButton = MicButton(frame: NSRect(x: 6, y: (pillH - btnSz)/2, width: btnSz, height: btnSz))
        micButton.onClick = { [weak self] in self?.onToggle?() }
        contentView.addSubview(micButton)

        // Waveform bars
        for i in 0..<4 {
            let bar = NSView(frame: NSRect(x: 44 + CGFloat(i)*6, y: (pillH-10)/2, width: 3, height: 10))
            bar.wantsLayer = true
            bar.layer?.cornerRadius = 1.5
            bar.layer?.backgroundColor = accent.withAlphaComponent(0.85).cgColor
            bar.alphaValue = 0
            contentView.addSubview(bar)
            waveformBars.append(bar)
        }

        // Text label leaves room for screenshot, settings, and history buttons on the right.
        let lx: CGFloat = 44
        textLabel = NSTextField(frame: NSRect(
            x: lx, y: (pillH-22)/2,
            width: idleW - lx - ssBtnSz - 4 - settingsBtnSz - 4 - hBtnSz - 16,
            height: 22
        ))
        textLabel.isEditable = false; textLabel.isSelectable = false
        textLabel.isBordered = false; textLabel.drawsBackground = false
        textLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 1; textLabel.usesSingleLineMode = true
        contentView.addSubview(textLabel)

        // Right cluster order: screenshots, history, settings.
        screenshotButton = ScreenshotButton(frame: NSRect(
            x: idleW - settingsBtnSz - 6 - hBtnSz - 4 - ssBtnSz - 8, y: (pillH - ssBtnSz)/2,
            width: ssBtnSz, height: ssBtnSz
        ))
        screenshotButton.onClick = { [weak self] in self?.onScreenshotPaste?() }
        contentView.addSubview(screenshotButton)

        historyButton = HistoryButton(frame: NSRect(
            x: idleW - settingsBtnSz - 6 - hBtnSz - 4, y: (pillH - hBtnSz)/2,
            width: hBtnSz, height: hBtnSz
        ))
        historyButton.onClick = { [weak self] in self?.onHistoryToggle?() }
        contentView.addSubview(historyButton)

        settingsButton = SettingsButton(frame: NSRect(
            x: idleW - settingsBtnSz - 6, y: (pillH - settingsBtnSz)/2,
            width: settingsBtnSz, height: settingsBtnSz
        ))
        settingsButton.onClick = { [weak self] in self?.onSettingsToggle?() }
        contentView.addSubview(settingsButton)
    }

    // MARK: - Public

    func show() {
        window.alphaValue = 0
        window.orderFront(nil)
        window.makeFirstResponder(contentView)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.5; ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }
    }

    func revealOnScreen() {
        guard let screen = activeScreen() else { return }

        userPositioned = false

        let width = max(idleW, window.frame.width)
        let visibleFrame = screen.visibleFrame
        let newFrame = NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.minY + bottomOff,
            width: width,
            height: pillH
        )

        layoutContent(width: width)
        if window.isVisible {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
        }

        window.alphaValue = state == .idle ? 0.7 : 1.0
        window.orderFrontRegardless()
        window.makeFirstResponder(contentView)
        onFrameChanged?(newFrame)
    }

    func setHistoryOpen(_ open: Bool) {
        historyButton.isOpen = open
    }

    func setScreenshotPickerOpen(_ open: Bool) {
        screenshotButton?.isOpen = open
    }

    func setSelectedModel(_ model: STTModel) {
        settingsButton?.setModel(model)
    }

    func hideForScreenshot() { window.alphaValue = 0 }
    func restoreAfterScreenshot() { window.alphaValue = state == .idle ? 0.7 : 1.0 }

    func showScreenshotPreview(_ image: NSImage) {
        previewPanel?.close()
        previewPanel = nil

        // Scale to small thumbnail
        let maxPW: CGFloat = 180
        let maxPH: CGFloat = 120
        let s = image.size
        guard s.width > 0, s.height > 0 else { return }
        let scale = min(maxPW / s.width, maxPH / s.height)
        let pw = ceil(s.width * scale)
        let ph = ceil(s.height * scale)

        // Position above the screenshot button (right cluster of pill)
        let pillFrame = window.frame
        let ssBtnMidX = pillFrame.origin.x + screenshotButton.frame.midX
        let panelX = ssBtnMidX - pw / 2
        let panelY = pillFrame.maxY + 8

        let panel = NSPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: pw, height: ph),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: pw, height: ph))
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(white: 1, alpha: 0.12).cgColor
        panel.contentView = container

        let iv = NSImageView(frame: NSRect(x: 0, y: 0, width: pw, height: ph))
        iv.image = image
        iv.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(iv)

        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1.0
        }
        previewPanel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self, weak panel] in
            guard let panel = panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.close()
                if self?.previewPanel === panel { self?.previewPanel = nil }
            })
        }
    }

    func setIdle() {
        state = .idle; stopWaveform(); hideWaveformBars(); micButton.isRecording = false
        textLabel.stringValue = "fn+Space to dictate"
        textLabel.textColor = NSColor(white: 1, alpha: 0.4)
        textLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textLabel.lineBreakMode = .byTruncatingTail
        resizePill(width: idleW)
        NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.4; window.animator().alphaValue = 0.7 }
    }

    func setRecording() {
        state = .recording; window.alphaValue = 1.0; micButton.isRecording = true
        showWaveformBars(); startWaveform()
        textLabel.stringValue = "Listening..."
        textLabel.textColor = .white
        textLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textLabel.lineBreakMode = .byTruncatingHead
        resizePill(width: activeW)
        let flash = CABasicAnimation(keyPath: "borderColor")
        flash.fromValue = accent.withAlphaComponent(0.6).cgColor
        flash.toValue = NSColor(white: 1, alpha: 0.08).cgColor; flash.duration = 0.6
        backgroundView.layer?.add(flash, forKey: "flash")
    }

    func setProcessing(text: String = "Processing...") {
        state = .processing; stopWaveform(); hideWaveformBars()
        micButton.isRecording = false
        micButton.layer?.backgroundColor = NSColor.systemOrange.cgColor
        textLabel.stringValue = text; textLabel.textColor = .white
    }

    func updateProcessingText(_ text: String) {
        guard state == .processing else { return }
        textLabel.stringValue = text
        textLabel.textColor = NSColor(white: 1, alpha: 0.88)
        resizePill(width: max(activeW, min(maxW, CGFloat(text.count) * 7.2 + 90)))
    }

    func setSuccess(text: String) {
        state = .success; stopWaveform(); hideWaveformBars()
        micButton.isRecording = false
        micButton.layer?.backgroundColor = NSColor.systemGreen.cgColor
        let d = text.count > 55 ? String(text.prefix(52)) + "..." : text
        textLabel.stringValue = "Pasted: \(d)"
        textLabel.textColor = .systemGreen
        textLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .regular)
        textLabel.lineBreakMode = .byTruncatingTail
        resizePill(width: max(activeW, min(maxW, CGFloat(textLabel.stringValue.count) * 7.2 + 90)))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard self?.state == .success else { return }
            self?.setIdle()
        }
    }

    func showError(_ message: String) {
        state = .error; stopWaveform(); hideWaveformBars()
        micButton.isRecording = false
        micButton.layer?.backgroundColor = NSColor.systemYellow.cgColor
        textLabel.stringValue = message; textLabel.textColor = .systemYellow
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard self?.state == .error else { return }
            self?.setIdle()
        }
    }

    func showNotice(_ message: String) {
        state = .notice; stopWaveform(); hideWaveformBars()
        micButton.isRecording = false
        micButton.layer?.backgroundColor = accent.cgColor
        textLabel.stringValue = message
        textLabel.textColor = NSColor(red: 0.655, green: 0.545, blue: 0.98, alpha: 1.0)
        textLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        textLabel.lineBreakMode = .byTruncatingTail
        resizePill(width: max(activeW, min(maxW, CGFloat(message.count) * 7.2 + 104)))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard self?.state == .notice else { return }
            self?.setIdle()
        }
    }

    func updateTranscription(_ text: String) {
        guard state == .recording else { return }
        textLabel.stringValue = text.isEmpty ? "Listening..." : text
        textLabel.textColor = .white
        resizePill(width: max(activeW, min(maxW, CGFloat(text.count) * 7.2 + 90)))
    }

    // MARK: - Animations

    private func showWaveformBars() { waveformBars.forEach { $0.alphaValue = 1.0 } }
    private func hideWaveformBars() { waveformBars.forEach { $0.alphaValue = 0 } }

    private func startWaveform() {
        stopWaveform()
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.13, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            for bar in self.waveformBars {
                let h = CGFloat.random(in: 4...20)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.1
                    bar.animator().frame = NSRect(x: bar.frame.origin.x, y: (self.pillH - h)/2,
                                                  width: bar.frame.width, height: h)
                }
            }
        }
    }

    private func stopWaveform() { waveformTimer?.invalidate(); waveformTimer = nil }

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return mouseScreen
        }
        return window.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func layoutContent(width: CGFloat) {
        backgroundView.frame = NSRect(x: 0, y: 0, width: width, height: pillH)
        let lx = textLabel.frame.origin.x
        let labelWidth = max(0, width - lx - ssBtnSz - 4 - settingsBtnSz - 4 - hBtnSz - 16)
        textLabel.frame = NSRect(x: lx, y: (pillH-22)/2, width: labelWidth, height: 22)
        screenshotButton.frame = NSRect(
            x: width - settingsBtnSz - 6 - hBtnSz - 4 - ssBtnSz - 8,
            y: (pillH - ssBtnSz)/2,
            width: ssBtnSz,
            height: ssBtnSz
        )
        historyButton.frame = NSRect(x: width - settingsBtnSz - 6 - hBtnSz - 4, y: (pillH - hBtnSz)/2, width: hBtnSz, height: hBtnSz)
        settingsButton.frame = NSRect(x: width - settingsBtnSz - 6, y: (pillH - settingsBtnSz)/2, width: settingsBtnSz, height: settingsBtnSz)
    }

    private func resizePill(width: CGFloat) {
        let screen = window.screen ?? activeScreen()
        let visibleFrame = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: maxW + 16, height: 900)
        let fittedWidth = min(width, max(160, visibleFrame.width - 8))
        let proposedX: CGFloat
        if userPositioned {
            proposedX = window.frame.midX - fittedWidth / 2
        } else {
            proposedX = visibleFrame.midX - fittedWidth / 2
        }
        let maxX = max(visibleFrame.minX + 4, visibleFrame.maxX - fittedWidth - 4)
        let newX = min(max(proposedX, visibleFrame.minX + 4), maxX)
        let newFrame = NSRect(x: newX, y: window.frame.origin.y, width: fittedWidth, height: pillH)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25; ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
        layoutContent(width: fittedWidth)
        onFrameChanged?(newFrame)
    }
}
