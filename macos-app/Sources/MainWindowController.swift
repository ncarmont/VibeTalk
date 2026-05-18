import Cocoa
import AVFoundation
import QuartzCore
import Speech

class MainWindowController: NSObject {
    private var window: NSWindow!
    private var refreshTimer: Timer?
    private var animatedViews: [NSView] = []
    private var animationFrames: [ObjectIdentifier: NSRect] = [:]

    // Permissions
    private var micDot: NSView!
    private var speechDot: NSView!
    private var accessDot: NSView!
    private var inputMonitorDot: NSView!
    private var tapDot: NSView!
    private var micLabel: NSTextField!
    private var speechLabel: NSTextField!
    private var accessLabel: NSTextField!
    private var inputMonitorLabel: NSTextField!
    private var tapLabel: NSTextField!
    private var micButton: NSButton!
    private var speechButton: NSButton!
    private var accessButton: NSButton!
    private var inputMonitorButton: NSButton!
    private var tapButton: NSButton!

    // Model
    private var modelPopup: NSPopUpButton!
    private var inputDevicePopup: NSPopUpButton!
    private var claudeTabButton: NSButton!
    private var selectedModel: STTModel = ModelPreferences.selectedModel
    private var manageModelsButton: NSButton!
    private var testModelButton: NSButton!
    private var modelTestStatusLabel: NSTextField!

    // Settings
    private var launchAtLoginToggle: NSSwitch!
    private var transcriptCleanupToggle: NSSwitch!

    // Status bar
    private var statusLabel: NSTextField!
    private var statusGeneration = 0

    // Callbacks
    var onRecordToggle: (() -> Void)?
    var onModelChange: ((STTModel) -> Void)?
    var onManageModels: (() -> Void)?
    var onTestSelectedModel: (() -> Void)?
    var onLaunchAtLoginChange: ((Bool) -> Void)?
    var onTranscriptCleanupChange: ((Bool) -> Void)?
    var onShowFloatingPill: (() -> Void)?
    var onInputDeviceChange: ((String?) -> Void)?
    var hotkeyManager: HotkeyManager?
    var isRecording = false
    var launchAtLoginEnabled = false {
        didSet { launchAtLoginToggle?.state = launchAtLoginEnabled ? .on : .off }
    }
    var transcriptCleanupEnabled = TranscriptCleanupPreferences.isEnabled {
        didSet { transcriptCleanupToggle?.state = transcriptCleanupEnabled ? .on : .off }
    }

    private let W: CGFloat = 760
    private let H: CGFloat = 800
    private let pad: CGFloat = 28
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)
    private let accentLight = NSColor(red: 0.66, green: 0.55, blue: 0.98, alpha: 1.0)
    private let bg = NSColor(red: 0.055, green: 0.055, blue: 0.07, alpha: 1.0)
    private let cardBg = NSColor(red: 0.095, green: 0.095, blue: 0.112, alpha: 1.0)
    private let cardBg2 = NSColor(red: 0.075, green: 0.075, blue: 0.092, alpha: 1.0)
    private let textDim = NSColor(white: 1.0, alpha: 0.48)

    override init() {
        super.init()
        setupWindow()
        setupUI()
        startPermissionRefresh()
    }

    // MARK: - Window

    private func setupWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "VibeTalk"
        window.isReleasedWhenClosed = false
        window.center()
        window.appearance = NSAppearance(named: .darkAqua)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = bg

        let cv = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        cv.wantsLayer = true
        cv.layer?.backgroundColor = bg.cgColor
        window.contentView = cv
    }

    // MARK: - UI

    private func setupUI() {
        guard let cv = window.contentView else { return }
        let cw = W - pad * 2

        addBackground(to: cv)

        // Header
        let header = NSView(frame: NSRect(x: pad, y: H - 108, width: cw, height: 68))
        cv.addSubview(header)
        track(header)

        let icon = appIcon(frame: NSRect(x: 0, y: 10, width: 46, height: 46))
        header.addSubview(icon)

        let title = lbl("VibeTalk", size: 28, weight: .bold, x: 62, y: 35, w: 240, h: 32)
        title.textColor = .white
        header.addSubview(title)

        let subtitle = lbl("Private dictation, screenshots, zero cloud.", size: 13, weight: .medium, x: 64, y: 14, w: 430, h: 18)
        subtitle.textColor = textDim
        header.addSubview(subtitle)

        let version = pillBadge("v1.0")
        version.frame.origin = NSPoint(x: cw - version.frame.width, y: 34)
        header.addSubview(version)

        let cleanupHint = lbl("LLM formatting  +~2s", size: 10.5, weight: .medium, x: cw - 210, y: 9, w: 158, h: 15)
        cleanupHint.textColor = NSColor(white: 1, alpha: 0.36)
        cleanupHint.alignment = .right
        cleanupHint.toolTip = TranscriptCleanupRuntime.tooltip
        header.addSubview(cleanupHint)

        transcriptCleanupToggle = NSSwitch(frame: NSRect(x: cw - 48, y: 2, width: 42, height: 24))
        transcriptCleanupToggle.target = self
        transcriptCleanupToggle.action = #selector(transcriptCleanupChanged)
        transcriptCleanupToggle.state = transcriptCleanupEnabled ? .on : .off
        transcriptCleanupToggle.toolTip = TranscriptCleanupRuntime.tooltip
        header.addSubview(transcriptCleanupToggle)

        // Hero status
        let hero = card(x: pad, y: H - 252, w: cw, h: 112, emphasized: true)
        cv.addSubview(hero)
        track(hero)

        let heroLeftW = cw - 292

        let heroEyebrow = lbl("READY", size: 11, weight: .semibold, x: 26, y: 80, w: heroLeftW, h: 16)
        heroEyebrow.textColor = accentLight.withAlphaComponent(0.92)
        hero.addSubview(heroEyebrow)

        let heroTitle = lbl("Press fn+Space to dictate.", size: 23, weight: .bold, x: 26, y: 48, w: heroLeftW, h: 30)
        heroTitle.textColor = .white
        hero.addSubview(heroTitle)

        let heroDesc = lbl("Speak naturally. Press again to paste. Press fn+i for the latest screenshot.", size: 13, weight: .regular, x: 26, y: 25, w: heroLeftW, h: 18)
        heroDesc.textColor = NSColor(white: 1, alpha: 0.62)
        hero.addSubview(heroDesc)

        let controls = NSView(frame: NSRect(x: cw - 252, y: 26, width: 226, height: 60))
        controls.wantsLayer = true
        controls.layer?.cornerRadius = 16
        controls.layer?.backgroundColor = NSColor(white: 1, alpha: 0.045).cgColor
        controls.layer?.borderWidth = 1
        controls.layer?.borderColor = NSColor(white: 1, alpha: 0.075).cgColor
        hero.addSubview(controls)

        let hotkey = hotkeyChip("fn", "Space", x: 30, y: 15)
        controls.addSubview(hotkey)

        // Main grid — absolute y so card height changes don't shift into the hero card
        let gridY: CGFloat = 302
        let workflowW: CGFloat = 360
        let gap: CGFloat = 16
        let permissionsW = cw - workflowW - gap

        let workflow = card(x: pad, y: gridY, w: workflowW, h: 240)
        cv.addSubview(workflow)
        track(workflow)

        sectionTitle("How To Get Started", parent: workflow, y: 201, w: workflowW)
        var stepY: CGFloat = 151
        modernStep(num: "1", icon: "cursorarrow.click.2", title: "Click into any text field", desc: "Claude Code, Cursor, Codex, any terminal or text field.", parent: workflow, y: &stepY, w: workflowW)
        modernStep(num: "2", icon: "mic.fill", title: "Press fn+Space and speak", desc: "VibeTalk listens until you press again.", parent: workflow, y: &stepY, w: workflowW)
        modernStep(num: "3", icon: "doc.on.clipboard", title: "Press fn+Space to paste", desc: "Words are instantly typed into whatever is focused.", parent: workflow, y: &stepY, w: workflowW)

        let permissions = card(x: pad + workflowW + gap, y: gridY, w: permissionsW, h: 240)
        cv.addSubview(permissions)
        track(permissions)

        sectionTitle("System Access", parent: permissions, y: 201, w: permissionsW)
        var permY: CGFloat = 163
        let (md, ml, mb) = statusRow("mic.fill", "Microphone", parent: permissions, y: &permY, w: permissionsW, action: #selector(requestMicrophoneAccess))
        micDot = md; micLabel = ml; micButton = mb
        let (sd, sl, sb) = statusRow("waveform", "Speech", parent: permissions, y: &permY, w: permissionsW, action: #selector(requestSpeechAccess))
        speechDot = sd; speechLabel = sl; speechButton = sb
        let (ad, al, ab) = statusRow("hand.raised.fill", "Accessibility", parent: permissions, y: &permY, w: permissionsW, action: #selector(requestAccessibilityAccess))
        accessDot = ad; accessLabel = al; accessButton = ab
        let (imd, iml, imb) = statusRow("eye.fill", "Input Monitoring", parent: permissions, y: &permY, w: permissionsW, action: #selector(requestInputMonitoringAccess))
        inputMonitorDot = imd; inputMonitorLabel = iml; inputMonitorButton = imb
        let (td, tl, tb) = statusRow("keyboard", "Hotkeys", parent: permissions, y: &permY, w: permissionsW, action: #selector(fixHotkeysAccess))
        tapDot = td; tapLabel = tl; tapButton = tb

        // Claude Code Tab Labels card
        let tabLabelsCard = card(x: pad, y: 66, w: cw, h: 86)
        cv.addSubview(tabLabelsCard)
        track(tabLabelsCard)

        let tabIconBg = NSView(frame: NSRect(x: 20, y: 22, width: 40, height: 40))
        tabIconBg.wantsLayer = true
        tabIconBg.layer?.cornerRadius = 12
        tabIconBg.layer?.backgroundColor = accent.withAlphaComponent(0.18).cgColor
        tabIconBg.layer?.borderWidth = 1
        tabIconBg.layer?.borderColor = accentLight.withAlphaComponent(0.28).cgColor
        let tabIconView = NSImageView(frame: NSRect(x: 11, y: 11, width: 18, height: 18))
        if let img = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium)) {
            tabIconView.image = img
            tabIconView.contentTintColor = accentLight.withAlphaComponent(0.88)
        }
        tabIconBg.addSubview(tabIconView)
        tabLabelsCard.addSubview(tabIconBg)

        let tabTitleBar = NSView(frame: NSRect(x: 74, y: 64, width: 3, height: 13))
        tabTitleBar.wantsLayer = true
        tabTitleBar.layer?.cornerRadius = 1.5
        tabTitleBar.layer?.backgroundColor = accentLight.withAlphaComponent(0.55).cgColor
        tabLabelsCard.addSubview(tabTitleBar)
        let tabTitleLbl = lbl("CLAUDE CODE TAB LABELS", size: 11, weight: .semibold, x: 86, y: 63, w: cw - 86 - 155, h: 16)
        tabTitleLbl.textColor = NSColor(white: 1, alpha: 0.50)
        tabLabelsCard.addSubview(tabTitleLbl)

        let tabDesc = lbl("Show the current folder in each tab — stop guessing which project is open.", size: 12.5, weight: .semibold, x: 74, y: 38, w: cw - 240, h: 18)
        tabDesc.textColor = NSColor(white: 1, alpha: 0.76)
        tabLabelsCard.addSubview(tabDesc)

        let tabNote = lbl("Zero dependencies · one-click install · works in every project", size: 11, weight: .regular, x: 74, y: 22, w: cw - 240, h: 15)
        tabNote.textColor = NSColor(white: 1, alpha: 0.38)
        tabLabelsCard.addSubview(tabNote)

        let isInstalled = MainWindowController.isClaudeTabLabelsInstalled()
        claudeTabButton = primaryButton(isInstalled ? "✓ Active" : "Install", x: cw - 144, y: 24, w: 120, action: #selector(claudeTabPressed))
        if isInstalled {
            claudeTabButton.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.22).cgColor
            claudeTabButton.contentTintColor = .white
            claudeTabButton.isEnabled = false
        }
        tabLabelsCard.addSubview(claudeTabButton)

        // Speech model
        let pref = card(x: pad, y: 164, w: cw, h: 126)
        cv.addSubview(pref)
        track(pref)

        sectionTitle("Speech Model", parent: pref, y: 92, w: cw)

        let langLbl = lbl("Active model", size: 12.5, weight: .semibold, x: 24, y: 67, w: 120, h: 18)
        langLbl.textColor = NSColor(white: 1, alpha: 0.76)
        pref.addSubview(langLbl)

        // Model picker (narrowed to leave room for device picker on the right)
        modelPopup = NSPopUpButton(frame: NSRect(x: 24, y: 31, width: 278, height: 34))
        modelPopup.bezelStyle = .shadowlessSquare
        modelPopup.isBordered = false
        modelPopup.wantsLayer = true
        modelPopup.layer?.cornerRadius = 12
        modelPopup.layer?.backgroundColor = NSColor(white: 1, alpha: 0.055).cgColor
        modelPopup.layer?.borderWidth = 1
        modelPopup.layer?.borderColor = NSColor(white: 1, alpha: 0.09).cgColor
        modelPopup.contentTintColor = NSColor(white: 1, alpha: 0.88)
        modelPopup.cell?.lineBreakMode = .byTruncatingTail
        modelPopup.controlSize = .large
        modelPopup.font = NSFont.systemFont(ofSize: 13.5, weight: .medium)
        modelPopup.target = self
        modelPopup.action = #selector(modelChanged)
        pref.addSubview(modelPopup)
        reloadModelPopup()

        testModelButton = secondaryButton("Test Model", x: 312, y: 33, w: 96, action: #selector(testModelPressed))
        pref.addSubview(testModelButton)

        modelTestStatusLabel = lbl("Choose model. Manage downloads; Test Model verifies runtime and transcription.", size: 11.2, weight: .regular, x: 24, y: 11, w: 452, h: 16)
        modelTestStatusLabel.textColor = NSColor(white: 1, alpha: 0.38)
        pref.addSubview(modelTestStatusLabel)

        // Audio input device picker
        let inputDeviceLbl = lbl("Microphone", size: 12.5, weight: .semibold, x: 506, y: 67, w: 160, h: 18)
        inputDeviceLbl.textColor = NSColor(white: 1, alpha: 0.76)
        pref.addSubview(inputDeviceLbl)

        inputDevicePopup = NSPopUpButton(frame: NSRect(x: 504, y: 31, width: 174, height: 34))
        inputDevicePopup.bezelStyle = .shadowlessSquare
        inputDevicePopup.isBordered = false
        inputDevicePopup.wantsLayer = true
        inputDevicePopup.layer?.cornerRadius = 12
        inputDevicePopup.layer?.backgroundColor = NSColor(white: 1, alpha: 0.055).cgColor
        inputDevicePopup.layer?.borderWidth = 1
        inputDevicePopup.layer?.borderColor = NSColor(white: 1, alpha: 0.09).cgColor
        inputDevicePopup.contentTintColor = NSColor(white: 1, alpha: 0.88)
        inputDevicePopup.cell?.lineBreakMode = .byTruncatingTail
        inputDevicePopup.controlSize = .large
        inputDevicePopup.font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        inputDevicePopup.target = self
        inputDevicePopup.action = #selector(inputDeviceChanged)
        pref.addSubview(inputDevicePopup)

        let loginTitle = lbl("Launch at login", size: 11, weight: .medium, x: cw - 176, y: 92, w: 112, h: 16)
        loginTitle.textColor = NSColor(white: 1, alpha: 0.42)
        pref.addSubview(loginTitle)

        launchAtLoginToggle = NSSwitch(frame: NSRect(x: cw - 64, y: 87, width: 42, height: 24))
        launchAtLoginToggle.target = self
        launchAtLoginToggle.action = #selector(launchAtLoginChanged)
        launchAtLoginToggle.state = launchAtLoginEnabled ? .on : .off
        pref.addSubview(launchAtLoginToggle)

        // Footer status
        let footer = NSView(frame: NSRect(x: pad, y: 20, width: cw, height: 34))
        cv.addSubview(footer)
        track(footer)

        let readyDot = NSView(frame: NSRect(x: 0, y: 13, width: 8, height: 8))
        readyDot.wantsLayer = true
        readyDot.layer?.cornerRadius = 4
        readyDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        footer.addSubview(readyDot)

        statusLabel = lbl("Ready - press fn+Space to dictate", size: 12.5, weight: .medium, x: 18, y: 8, w: cw - 220, h: 20)
        statusLabel.textColor = NSColor(white: 1, alpha: 0.42)
        footer.addSubview(statusLabel)

        let showPillButton = secondaryButton("Show Floating Pill", x: cw - 190, y: 2, w: 190, action: #selector(showFloatingPill))
        footer.addSubview(showPillButton)

        refreshPermissions()
    }

    private func addBackground(to cv: NSView) {
        let top = NSView(frame: NSRect(x: 0, y: H - 260, width: W, height: 260))
        top.wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.frame = top.bounds
        gradient.colors = [
            accent.withAlphaComponent(0.20).cgColor,
            NSColor(red: 0.12, green: 0.10, blue: 0.18, alpha: 0.35).cgColor,
            NSColor.clear.cgColor
        ]
        gradient.locations = [0, 0.46, 1]
        gradient.startPoint = CGPoint(x: 0.15, y: 1)
        gradient.endPoint = CGPoint(x: 0.85, y: 0)
        top.layer?.addSublayer(gradient)
        cv.addSubview(top)

        let hairline = NSView(frame: NSRect(x: pad, y: H - 128, width: W - pad * 2, height: 1))
        hairline.wantsLayer = true
        hairline.layer?.backgroundColor = NSColor(white: 1, alpha: 0.065).cgColor
        cv.addSubview(hairline)
    }

    // MARK: - UI Helpers

    private func lbl(_ text: String, size: CGFloat, weight: NSFont.Weight, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat? = nil) -> NSTextField {
        let l = NSTextField(frame: NSRect(x: x, y: y, width: w, height: h ?? size + 8))
        l.stringValue = text
        l.isEditable = false
        l.isSelectable = false
        l.isBordered = false
        l.drawsBackground = false
        l.font = NSFont.systemFont(ofSize: size, weight: weight)
        l.textColor = .white
        return l
    }

    private func track(_ view: NSView) {
        animatedViews.append(view)
        animationFrames[ObjectIdentifier(view)] = view.frame
    }

    private func appIcon(frame: NSRect) -> NSView {
        let iconBg = NSView(frame: frame)
        iconBg.wantsLayer = true
        iconBg.layer?.cornerRadius = 14
        iconBg.layer?.shadowColor = accent.withAlphaComponent(0.45).cgColor
        iconBg.layer?.shadowOffset = CGSize(width: 0, height: -6)
        iconBg.layer?.shadowRadius = 18
        iconBg.layer?.shadowOpacity = 1

        let grad = CAGradientLayer()
        grad.frame = iconBg.bounds
        grad.colors = [accent.cgColor, accentLight.cgColor]
        grad.startPoint = CGPoint(x: 0.1, y: 0.05)
        grad.endPoint = CGPoint(x: 1, y: 1)
        grad.cornerRadius = 14
        iconBg.layer?.addSublayer(grad)

        let mic = NSImageView(frame: NSRect(x: 13, y: 13, width: 22, height: 22))
        if let img = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .bold)) {
            mic.image = img
            mic.contentTintColor = .white
        }
        iconBg.addSubview(mic)
        return iconBg
    }

    private func card(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, emphasized: Bool = false) -> NSView {
        let v = NSView(frame: NSRect(x: x, y: y, width: w, height: h))
        v.wantsLayer = true
        v.layer?.cornerRadius = 20
        v.layer?.masksToBounds = false
        v.layer?.backgroundColor = (emphasized ? cardBg : cardBg2).cgColor
        v.layer?.borderWidth = 1
        v.layer?.borderColor = (emphasized ? accent.withAlphaComponent(0.20) : NSColor(white: 1, alpha: 0.075)).cgColor
        v.layer?.shadowColor = NSColor.black.withAlphaComponent(0.34).cgColor
        v.layer?.shadowOffset = CGSize(width: 0, height: -8)
        v.layer?.shadowRadius = 18
        v.layer?.shadowOpacity = 0.9

        if emphasized {
            let glow = CAGradientLayer()
            glow.frame = v.bounds
            glow.colors = [accent.withAlphaComponent(0.13).cgColor, NSColor.clear.cgColor]
            glow.startPoint = CGPoint(x: 0, y: 1)
            glow.endPoint = CGPoint(x: 1, y: 0)
            glow.cornerRadius = 20
            v.layer?.insertSublayer(glow, at: 0)
        }
        return v
    }

    private func sectionTitle(_ text: String, parent: NSView, y: CGFloat, w: CGFloat) {
        let bar = NSView(frame: NSRect(x: 20, y: y + 1, width: 3, height: 14))
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 1.5
        bar.layer?.backgroundColor = accentLight.withAlphaComponent(0.55).cgColor
        parent.addSubview(bar)
        let l = lbl(text.uppercased(), size: 11, weight: .semibold, x: 32, y: y, w: w - 54, h: 16)
        l.textColor = NSColor(white: 1, alpha: 0.50)
        parent.addSubview(l)
    }

    private func pillBadge(_ text: String) -> NSView {
        let w: CGFloat = CGFloat(text.count) * 8 + 20
        let h: CGFloat = 24
        let v = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        v.wantsLayer = true
        v.layer?.cornerRadius = h / 2
        v.layer?.backgroundColor = accent.withAlphaComponent(0.18).cgColor
        v.layer?.borderWidth = 1
        v.layer?.borderColor = accent.withAlphaComponent(0.36).cgColor
        let l = lbl(text, size: 11, weight: .semibold, x: 0, y: 4, w: w, h: 16)
        l.alignment = .center
        l.textColor = accentLight
        v.addSubview(l)
        return v
    }

    private func hotkeyChip(_ first: String, _ second: String, x: CGFloat, y: CGFloat) -> NSView {
        let v = NSView(frame: NSRect(x: x, y: y, width: 166, height: 30))
        let firstChip = keyCap(first, x: 0)
        let plus = lbl("+", size: 12, weight: .semibold, x: 58, y: 7, w: 14, h: 16)
        plus.textColor = NSColor(white: 1, alpha: 0.38)
        let secondChip = keyCap(second, x: 78, width: 88)
        v.addSubview(firstChip)
        v.addSubview(plus)
        v.addSubview(secondChip)
        return v
    }

    private func keyCap(_ text: String, x: CGFloat, width: CGFloat = 48) -> NSView {
        let v = NSView(frame: NSRect(x: x, y: 0, width: width, height: 30))
        v.wantsLayer = true
        v.layer?.cornerRadius = 8
        v.layer?.backgroundColor = NSColor(white: 1, alpha: 0.075).cgColor
        v.layer?.borderWidth = 1
        v.layer?.borderColor = NSColor(white: 1, alpha: 0.12).cgColor
        let l = lbl(text, size: 12, weight: .semibold, x: 0, y: 7, w: width, h: 16)
        l.alignment = .center
        l.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        l.textColor = NSColor(white: 1, alpha: 0.86)
        v.addSubview(l)
        return v
    }

    private func primaryButton(_ title: String, x: CGFloat, y: CGFloat, w: CGFloat, action: Selector) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: y, width: w, height: 34))
        button.title = title
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 12
        button.layer?.backgroundColor = accent.cgColor
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.contentTintColor = .white
        button.target = self
        button.action = action
        return button
    }

    private func secondaryButton(_ title: String, x: CGFloat, y: CGFloat, w: CGFloat, action: Selector) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: y, width: w, height: 30))
        button.title = title
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor(white: 1, alpha: 0.10).cgColor
        button.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        button.contentTintColor = NSColor(white: 1, alpha: 0.72)
        button.target = self
        button.action = action
        return button
    }

    private func modernStep(num: String, icon: String, title: String, desc: String, parent: NSView, y: inout CGFloat, w: CGFloat) {
        let row = NSView(frame: NSRect(x: 16, y: y, width: w - 32, height: 40))
        row.wantsLayer = true
        row.layer?.cornerRadius = 10
        row.layer?.backgroundColor = NSColor(white: 1, alpha: 0.04).cgColor
        row.layer?.borderWidth = 1
        row.layer?.borderColor = NSColor(white: 1, alpha: 0.07).cgColor
        parent.addSubview(row)

        // Accent circle step-number (more intentional than a key cap)
        let numCircle = NSView(frame: NSRect(x: 10, y: 9, width: 22, height: 22))
        numCircle.wantsLayer = true
        numCircle.layer?.cornerRadius = 11
        numCircle.layer?.backgroundColor = accent.withAlphaComponent(0.22).cgColor
        numCircle.layer?.borderWidth = 1
        numCircle.layer?.borderColor = accentLight.withAlphaComponent(0.45).cgColor
        let numLabel = lbl(num, size: 11.5, weight: .bold, x: 0, y: 3, w: 22, h: 16)
        numLabel.alignment = .center
        numLabel.textColor = accentLight
        numCircle.addSubview(numLabel)
        row.addSubview(numCircle)

        let iconView = NSImageView(frame: NSRect(x: 46, y: 12, width: 16, height: 16))
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold)) {
            iconView.image = img
            iconView.contentTintColor = accentLight.withAlphaComponent(0.88)
        }
        row.addSubview(iconView)

        let titleLbl = lbl(title, size: 12.5, weight: .semibold, x: 70, y: 22, w: w - 104, h: 16)
        titleLbl.textColor = NSColor(white: 1, alpha: 0.92)
        row.addSubview(titleLbl)

        let descLbl = lbl(desc, size: 11, weight: .regular, x: 70, y: 5, w: w - 104, h: 15)
        descLbl.textColor = NSColor(white: 1, alpha: 0.54)
        descLbl.cell?.lineBreakMode = .byTruncatingTail
        row.addSubview(descLbl)

        y -= 46
    }

    private func statusRow(_ icon: String, _ title: String, parent: NSView, y: inout CGFloat, w: CGFloat, action: Selector) -> (NSView, NSTextField, NSButton) {
        let rowW = w - 36
        let row = NSView(frame: NSRect(x: 18, y: y, width: rowW, height: 30))
        parent.addSubview(row)

        let imgView = NSImageView(frame: NSRect(x: 0, y: 7, width: 15, height: 15))
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: title)?
            .withSymbolConfiguration(.init(pointSize: 10.5, weight: .medium)) {
            imgView.image = img
            imgView.contentTintColor = NSColor(white: 1, alpha: 0.46)
        }
        row.addSubview(imgView)

        let t = lbl(title, size: 12.5, weight: .medium, x: 26, y: 5, w: rowW - 172, h: 18)
        t.textColor = NSColor(white: 1, alpha: 0.80)
        row.addSubview(t)

        let dot = NSView(frame: NSRect(x: rowW - 138, y: 11, width: 8, height: 8))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = NSColor.systemGray.cgColor
        row.addSubview(dot)

        let s = lbl("...", size: 11.5, weight: .semibold, x: rowW - 126, y: 5, w: 56, h: 18)
        s.alignment = .right
        s.textColor = NSColor(white: 1, alpha: 0.48)
        row.addSubview(s)

        let button = permissionActionButton(x: rowW - 58, action: action)
        row.addSubview(button)

        y -= 34
        return (dot, s, button)
    }

    private func permissionActionButton(x: CGFloat, action: Selector) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: 3, width: 58, height: 24))
        button.title = "Grant"
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 9
        button.layer?.backgroundColor = accent.withAlphaComponent(0.18).cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = accent.withAlphaComponent(0.30).cgColor
        button.font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        button.contentTintColor = accentLight
        button.target = self
        button.action = action
        return button
    }

    // MARK: - Permissions

    @objc func refreshPermissions() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let micOK = micStatus == .authorized
        setStatus(
            dot: micDot,
            label: micLabel,
            button: micButton,
            ok: micOK,
            okText: "Granted",
            failText: "Missing",
            actionText: micStatus == .notDetermined ? "Grant" : "Open"
        )

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let speechOK = speechStatus == .authorized
        setStatus(
            dot: speechDot,
            label: speechLabel,
            button: speechButton,
            ok: speechOK,
            okText: "Granted",
            failText: "Missing",
            actionText: speechStatus == .notDetermined ? "Grant" : "Open"
        )

        let axOK = AXIsProcessTrusted()
        setStatus(
            dot: accessDot,
            label: accessLabel,
            button: accessButton,
            ok: axOK,
            okText: "Granted",
            failText: "Missing",
            actionText: "Open"
        )

        let tapOK = hotkeyManager?.eventTapActive ?? false

        // Only show Input Monitoring row when hotkeys aren't working — it's a fallback diagnostic
        let inputMonOK = CGPreflightListenEventAccess()
        inputMonitorDot.superview?.isHidden = tapOK
        if !tapOK {
            setStatus(
                dot: inputMonitorDot,
                label: inputMonitorLabel,
                button: inputMonitorButton,
                ok: inputMonOK,
                okText: "Granted",
                failText: "Missing",
                actionText: "Open"
            )
        }
        setStatus(
            dot: tapDot,
            label: tapLabel,
            button: tapButton,
            ok: tapOK,
            okText: "Active",
            failText: "Inactive",
            actionText: axOK && !inputMonOK ? "Fix" : "Fix"
        )
    }

    private func setStatus(dot: NSView, label: NSTextField, button: NSButton, ok: Bool, okText: String, failText: String, actionText: String) {
        let color = ok ? NSColor.systemGreen : NSColor.systemRed
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.shadowColor = color.withAlphaComponent(0.7).cgColor
        dot.layer?.shadowRadius = ok ? 7 : 4
        dot.layer?.shadowOpacity = 0.75
        dot.layer?.shadowOffset = .zero
        label.stringValue = ok ? okText : failText
        label.textColor = color

        button.title = ok ? "Done" : actionText
        button.isEnabled = !ok
        button.contentTintColor = ok ? NSColor.systemGreen.withAlphaComponent(0.78) : accentLight
        button.layer?.backgroundColor = (ok ? NSColor.systemGreen : accent).withAlphaComponent(ok ? 0.10 : 0.18).cgColor
        button.layer?.borderColor = (ok ? NSColor.systemGreen : accent).withAlphaComponent(ok ? 0.20 : 0.30).cgColor
    }

    private func startPermissionRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshPermissions()
        }
    }

    @objc private func requestMicrophoneAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            refreshPermissions()
            showStatusMessage("Microphone access is already granted.", color: .systemGreen)
        case .notDetermined:
            micButton.isEnabled = false
            micButton.title = "Asking"
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshPermissions()
                    self?.showStatusMessage("Microphone permission updated.", color: .systemYellow)
                }
            }
        case .denied, .restricted:
            openPrivacySettings("Privacy_Microphone")
            showStatusMessage("Enable VibeTalk in Microphone, then return here.", color: .systemYellow)
        @unknown default:
            openPrivacySettings("Privacy_Microphone")
        }
    }

    @objc private func requestSpeechAccess() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            refreshPermissions()
            showStatusMessage("Speech Recognition is already granted.", color: .systemGreen)
        case .notDetermined:
            speechButton.isEnabled = false
            speechButton.title = "Asking"
            SFSpeechRecognizer.requestAuthorization { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshPermissions()
                }
            }
        case .denied, .restricted:
            openPrivacySettings("Privacy_SpeechRecognition")
            showStatusMessage("Enable VibeTalk in Speech Recognition, then return here.", color: .systemYellow)
        @unknown default:
            openPrivacySettings("Privacy_SpeechRecognition")
        }
    }

    @objc private func requestAccessibilityAccess() {
        if AXIsProcessTrusted() {
            refreshPermissions()
            showStatusMessage("Accessibility already granted — checking hotkeys...", color: .systemGreen)
            hotkeyManager?.retryWithAccessibility()
            return
        }
        // Prompt adds VibeTalk to the Accessibility list if it's absent, then open Settings
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        openPrivacySettings("Privacy_Accessibility")
        showStatusMessage("Enable VibeTalk in Accessibility, then return here.", color: .systemYellow)
        startPermissionPolling()
    }

    @objc private func requestInputMonitoringAccess() {
        if CGPreflightListenEventAccess() {
            refreshPermissions()
            showStatusMessage("Input Monitoring already granted.", color: .systemGreen)
            return
        }
        openPrivacySettings("Privacy_ListenEvent")
        showStatusMessage("Add VibeTalk in Input Monitoring, then return here.", color: .systemYellow)
        startPermissionPolling()
    }

    @objc private func fixHotkeysAccess() {
        guard AXIsProcessTrusted() else {
            openPrivacySettings("Privacy_Accessibility")
            showStatusMessage("Enable VibeTalk in Accessibility, then return here.", color: .systemYellow)
            startPermissionPolling()
            return
        }

        hotkeyManager?.retryWithAccessibility()
        refreshPermissions()

        if hotkeyManager?.eventTapActive == true {
            showStatusMessage("Hotkeys active! Press fn+Space from any app to test.", color: .systemGreen)
        } else if !CGPreflightListenEventAccess() {
            openPrivacySettings("Privacy_ListenEvent")
            showStatusMessage("Also enable VibeTalk in Input Monitoring, then return here.", color: .systemYellow)
            startPermissionPolling()
        } else {
            // Both granted but tap still failed — toggle Accessibility off/on
            openPrivacySettings("Privacy_Accessibility")
            showStatusMessage("Toggle VibeTalk off then back on in Accessibility, then return here.", color: .systemYellow)
            startPermissionPolling()
        }
    }

    // Polls every 0.4s for up to 30s after the user goes to System Settings,
    // so the UI updates the moment they return and grant the permission.
    private func startPermissionPolling() {
        var ticks = 0
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] timer in
            ticks += 1
            guard let self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                self.hotkeyManager?.retryWithAccessibility()
            }
            self.refreshPermissions()
            // Stop after 30s or once everything is good
            let allGood = AXIsProcessTrusted()
                && CGPreflightListenEventAccess()
                && (self.hotkeyManager?.eventTapActive ?? false)
            if ticks >= 75 || allGood { timer.invalidate() }
        }
    }

    private func openPrivacySettings(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Model

    @objc private func modelChanged() {
        guard let id = modelPopup.selectedItem?.representedObject as? String,
              let model = ModelPreferences.model(for: id) else { return }
        guard model.isAvailable else {
            reloadModelPopup()
            return
        }
        selectedModel = model
        onModelChange?(model)
    }

    @objc private func manageModelsPressed() {
        onManageModels?()
    }

    @objc private func testModelPressed() {
        onTestSelectedModel?()
    }

    func setSelectedModel(_ model: STTModel) {
        selectedModel = model
        reloadModelPopup()
        if modelTestStatusLabel != nil {
            modelTestStatusLabel.stringValue = "Selected \(model.shortName). Click Test Model to verify runtime, files, and transcription."
            modelTestStatusLabel.textColor = NSColor(white: 1, alpha: 0.42)
        }
    }

    func setModelTestRunning(_ model: STTModel) {
        testModelButton?.isEnabled = false
        modelTestStatusLabel?.stringValue = "Testing \(model.shortName)..."
        modelTestStatusLabel?.textColor = accentLight
    }

    func setModelTestResult(success: Bool, message: String) {
        testModelButton?.isEnabled = true
        modelTestStatusLabel?.stringValue = message
        modelTestStatusLabel?.textColor = success ? NSColor.systemGreen : NSColor.systemYellow
    }

    var modelSettingsAnchorFrame: NSRect {
        guard let button = manageModelsButton,
              let buttonWindow = button.window else {
            return window?.frame ?? .zero
        }
        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        return buttonWindow.convertToScreen(buttonFrameInWindow)
    }

    private func iconForModel(_ model: STTModel) -> NSImage? {
        let symbolName: String
        switch model.engine {
        case .appleSpeech:  symbolName = "applelogo"
        case .whisperCpp:   symbolName = "waveform"
        case .parakeetCLI:  symbolName = "bird"
        case .voxtralMLX:   symbolName = "sparkles"
        }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }

    private func reloadModelPopup() {
        if modelPopup == nil { return }

        modelPopup.removeAllItems()
        for model in availableModels {
            let suffix: String
            if model.isAvailable {
                suffix = ""
            } else if model.needsDownload {
                suffix = " (download in settings)"
            } else {
                suffix = " (\(model.statusText.lowercased()))"
            }
            modelPopup.addItem(withTitle: "\(model.name)\(suffix)")
            let item = modelPopup.lastItem
            item?.representedObject = model.id
            item?.isEnabled = model.isAvailable
            item?.image = iconForModel(model)
        }

        if let index = availableModels.firstIndex(of: selectedModel) {
            modelPopup.selectItem(at: index)
        }
    }

    // MARK: - Input Device

    func refreshInputDevices(selectedUID: String?) {
        guard inputDevicePopup != nil else { return }
        inputDevicePopup.removeAllItems()
        inputDevicePopup.addItem(withTitle: "System Default")
        inputDevicePopup.item(at: 0)?.representedObject = Optional<String>.none as Any

        for (name, uid) in TranscriptionEngine.availableInputDevices() {
            inputDevicePopup.addItem(withTitle: name)
            inputDevicePopup.lastItem?.representedObject = uid as Any
        }

        if let uid = selectedUID,
           let match = inputDevicePopup.itemArray.first(where: { ($0.representedObject as? String) == uid }) {
            inputDevicePopup.select(match)
        } else {
            inputDevicePopup.selectItem(at: 0)
        }
    }

    @objc private func inputDeviceChanged() {
        let uid = inputDevicePopup.selectedItem?.representedObject as? String
        onInputDeviceChange?(uid)
    }

    // MARK: - Settings

    @objc private func launchAtLoginChanged() {
        let enabled = launchAtLoginToggle.state == .on
        launchAtLoginEnabled = enabled
        onLaunchAtLoginChange?(enabled)
    }

    @objc private func transcriptCleanupChanged() {
        let enabled = transcriptCleanupToggle.state == .on
        transcriptCleanupEnabled = enabled
        onTranscriptCleanupChange?(enabled)

        showStatusMessage(enabled ? "LLM formatting enabled." : "LLM formatting disabled.", color: enabled ? accentLight : NSColor(white: 1, alpha: 0.46))
    }

    @objc private func showFloatingPill() {
        onShowFloatingPill?()
    }

    // MARK: - Claude Code Tab Labels

    @objc private func claudeTabPressed() {
        do {
            try MainWindowController.installClaudeTabLabels()
            claudeTabButton.title = "✓ Active"
            claudeTabButton.isEnabled = false
            claudeTabButton.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.22).cgColor
            claudeTabButton.contentTintColor = .white
            claudeTabButton.layer?.borderColor = nil
            showStatusMessage("Installed! Restart Claude Code to see tab labels.", color: .systemGreen)
        } catch {
            showStatusMessage("Install failed: \(error.localizedDescription)", color: .systemYellow)
        }
    }

    static func isClaudeTabLabelsInstalled() -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sl = json["statusLine"] as? [String: Any],
              sl["type"] as? String == "command" else { return false }
        return true
    }

    static func installClaudeTabLabels() throws {
        let fm = FileManager.default
        let claudeDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        try fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        let scriptURL = claudeDir.appendingPathComponent("statusline.sh")
        let script = """
        #!/bin/bash
        input=$(cat)
        dir=$(printf "%s" "$input" | python3 -c 'import sys,json; print((json.load(sys.stdin).get("workspace") or {}).get("current_dir",""))')
        python3 - <<'PY' "$dir"
        import os, sys
        p = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] else ""
        parts = [x for x in p.split(os.sep) if x]
        if len(parts) >= 2:
            print(f"{parts[-1]} 🚀 in {parts[-2]}")
        elif len(parts) == 1:
            print(f"{parts[-1]} 🚀")
        else:
            print("root 🚀")
        PY
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let settingsURL = claudeDir.appendingPathComponent("settings.json")
        var settings: [String: Any] = [:]
        if let d = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            settings = existing
        }
        settings["statusLine"] = ["type": "command", "command": "~/.claude/statusline.sh"]
        let out = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
        try out.write(to: settingsURL)
    }

    // MARK: - Recording feedback

    func updateRecordButton() {}

    func updateTranscription(_ text: String) {
        statusGeneration += 1
        statusLabel.stringValue = text.isEmpty ? "Listening..." : text
        statusLabel.textColor = NSColor(white: 1, alpha: 0.68)
    }

    func showResult(_ text: String) {
        statusGeneration += 1
        if text.isEmpty {
            setReadyStatus()
        } else {
            let display = text.count > 74 ? String(text.prefix(71)) + "..." : text
            statusLabel.stringValue = "Pasted: \(display)"
            statusLabel.textColor = .systemGreen
            let generation = statusGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                guard self?.statusGeneration == generation else { return }
                self?.setReadyStatus()
            }
        }
    }

    private func showStatusMessage(_ msg: String, color: NSColor) {
        statusGeneration += 1
        statusLabel.stringValue = msg
        statusLabel.textColor = color
        let generation = statusGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard self?.statusGeneration == generation else { return }
            self?.setReadyStatus()
        }
    }

    func showError(_ msg: String) {
        showStatusMessage(msg, color: .systemYellow)
    }

    private func setReadyStatus() {
        statusLabel.stringValue = "Ready - press fn+Space to start dictating"
        statusLabel.textColor = NSColor(white: 1, alpha: 0.38)
    }

    // MARK: - Show

    func show() {
        let shouldAnimate = !window.isVisible
        window.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) { NSApp.activate() }
        else { NSApp.activate(ignoringOtherApps: true) }
        if shouldAnimate { animateOnLoad() }
    }

    private func animateOnLoad() {
        for (index, view) in animatedViews.enumerated() {
            guard let targetFrame = animationFrames[ObjectIdentifier(view)] else { continue }
            view.layer?.removeAllAnimations()
            view.alphaValue = 0
            view.frame = targetFrame.offsetBy(dx: 0, dy: -12)

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.055) {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.34
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    view.animator().alphaValue = 1
                    view.animator().frame = targetFrame
                }
            }
        }
    }

    deinit { refreshTimer?.invalidate() }
}
