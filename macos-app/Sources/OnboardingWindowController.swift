import Cocoa
import AVFoundation
import Speech

class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private var pages: [NSView] = []
    private var pageDots: [NSView] = []
    private var currentPage = 0
    private var needsMoveToApps: Bool

    // Page: permissions indicators
    private var micDot: NSView!
    private var speechDot: NSView!
    private var accessDot: NSView!
    private var micBtn: NSButton!
    private var speechBtn: NSButton!
    private var accessBtn: NSButton!
    private var permTimer: Timer?

    // Page: move to applications
    private var moveArrowLayers: [CALayer] = []
    private var moveArrowTimer: Timer?
    private var moveStatusLabel: NSTextField?
    private var moveButton: NSView?
    private var isMovingToApplications = false

    var onComplete: (() -> Void)?

    private let W: CGFloat = 520
    private let H: CGFloat = 600
    private let pad: CGFloat = 44
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)
    private let accentLight = NSColor(red: 0.655, green: 0.545, blue: 0.98, alpha: 1.0)
    private let bg = NSColor(red: 0.067, green: 0.067, blue: 0.078, alpha: 1.0)

    init(needsMoveToApps: Bool = false) {
        self.needsMoveToApps = needsMoveToApps
        super.init()
        buildWindow()
        if needsMoveToApps { buildMoveToAppsPage() }
        buildPage1()
        buildPage2()
        buildPage3()
        buildDots()
        showPage(0, animated: false)
    }

    // MARK: - Window

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.appearance = NSAppearance(named: .darkAqua)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = bg
        window.delegate = self
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        window.contentView?.wantsLayer = true

        // Gradient glow at top
        let glow = NSView(frame: NSRect(x: 0, y: H - 280, width: W, height: 280))
        glow.wantsLayer = true
        let g = CAGradientLayer()
        g.frame = glow.bounds
        g.colors = [accent.withAlphaComponent(0.10).cgColor, NSColor.clear.cgColor]
        g.startPoint = CGPoint(x: 0.5, y: 1.0)
        g.endPoint = CGPoint(x: 0.5, y: 0.0)
        glow.layer?.addSublayer(g)
        window.contentView?.addSubview(glow)
    }

    // MARK: - Page 0: Move to Applications

    private func buildMoveToAppsPage() {
        guard let cv = window.contentView else { return }
        let page = NSView(frame: cv.bounds)
        let cw = W - pad * 2

        // Title
        let title = singleLbl("Move to Applications", size: 24, weight: .bold, x: pad, y: H - 110, w: cw)
        title.alignment = .center
        page.addSubview(title)

        let sub = multiLbl(
            "For the best experience, VibeTalk\nshould live in your Applications folder.",
            size: 14, x: pad, y: H - 160, w: cw, h: 40
        )
        sub.textColor = NSColor(white: 1, alpha: 0.45)
        sub.alignment = .center
        page.addSubview(sub)

        // Icon row: App icon → animated arrow → Applications folder
        let rowY: CGFloat = H - 310
        let iconSz: CGFloat = 96
        let spacing: CGFloat = 52

        // App icon
        let appIconContainer = NSView(frame: NSRect(
            x: (W / 2) - spacing - iconSz - 20,
            y: rowY, width: iconSz, height: iconSz
        ))
        appIconContainer.wantsLayer = true
        appIconContainer.layer?.cornerRadius = 22
        let grad = CAGradientLayer()
        grad.frame = appIconContainer.bounds
        grad.colors = [accent.cgColor, accentLight.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 0)
        grad.endPoint = CGPoint(x: 1, y: 1)
        grad.cornerRadius = 22
        appIconContainer.layer?.addSublayer(grad)
        appIconContainer.layer?.shadowColor = accent.withAlphaComponent(0.4).cgColor
        appIconContainer.layer?.shadowOffset = CGSize(width: 0, height: -6)
        appIconContainer.layer?.shadowRadius = 18
        appIconContainer.layer?.shadowOpacity = 1.0
        let appMic = NSImageView(frame: NSRect(x: 24, y: 24, width: 48, height: 48))
        if let img = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 30, weight: .medium)) {
            appMic.image = img; appMic.contentTintColor = .white
        }
        appIconContainer.addSubview(appMic)
        page.addSubview(appIconContainer)

        // App label
        let appLabel = singleLbl("VibeTalk", size: 11, weight: .medium,
                                  x: appIconContainer.frame.origin.x - 10,
                                  y: rowY - 24, w: iconSz + 20)
        appLabel.textColor = NSColor(white: 1, alpha: 0.5)
        appLabel.alignment = .center
        page.addSubview(appLabel)

        // Animated arrow (3 chevrons)
        let arrowCenterX = W / 2
        let arrowCenterY = rowY + iconSz / 2
        for i in 0..<3 {
            let chevronLayer = CALayer()
            let chevronSz: CGFloat = 20
            chevronLayer.frame = CGRect(
                x: arrowCenterX - 24 + CGFloat(i) * 18,
                y: arrowCenterY - chevronSz / 2,
                width: chevronSz, height: chevronSz
            )
            if let img = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .semibold)) {
                chevronLayer.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
                chevronLayer.contentsGravity = .resizeAspect
            }
            chevronLayer.opacity = 0.0
            cv.layer?.addSublayer(chevronLayer)
            moveArrowLayers.append(chevronLayer)
        }

        // Applications folder icon
        let appsIconSz: CGFloat = iconSz
        let appsX = W / 2 + spacing + 20
        let appsIconView = NSImageView(frame: NSRect(x: appsX, y: rowY, width: appsIconSz, height: appsIconSz))
        appsIconView.image = NSWorkspace.shared.icon(forFile: "/Applications")
        appsIconView.imageScaling = .scaleProportionallyUpOrDown
        appsIconView.wantsLayer = true
        appsIconView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.3).cgColor
        appsIconView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        appsIconView.layer?.shadowRadius = 8
        appsIconView.layer?.shadowOpacity = 1.0
        page.addSubview(appsIconView)

        let appsLabel = singleLbl("Applications", size: 11, weight: .medium,
                                   x: appsX - 8, y: rowY - 24, w: appsIconSz + 16)
        appsLabel.textColor = NSColor(white: 1, alpha: 0.5)
        appsLabel.alignment = .center
        page.addSubview(appsLabel)

        // Status label (hidden initially)
        let statusLbl = multiLbl("", size: 13, x: pad, y: rowY - 72, w: cw, h: 40)
        statusLbl.alignment = .center
        statusLbl.isHidden = true
        page.addSubview(statusLbl)
        moveStatusLabel = statusLbl

        // Move button
        let moveBtn = accentButton("Move to Applications", action: #selector(doMoveToApplications), width: 260)
        moveBtn.frame.origin = NSPoint(x: (W - 260) / 2, y: 130)
        page.addSubview(moveBtn)
        self.moveButton = moveBtn

        // Not now link
        let laterBtn = NSButton(frame: NSRect(x: (W - 180) / 2, y: 90, width: 180, height: 28))
        laterBtn.title = "Not Now"
        laterBtn.isBordered = false
        laterBtn.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        laterBtn.contentTintColor = NSColor(white: 1, alpha: 0.35)
        laterBtn.target = self
        laterBtn.action = #selector(skipMoveToApps)
        page.addSubview(laterBtn)

        pages.append(page)
        cv.addSubview(page)
    }

    private func startArrowAnimation() {
        guard !moveArrowLayers.isEmpty else { return }
        moveArrowTimer?.invalidate()
        var tick = 0
        moveArrowTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            for (i, layer) in self.moveArrowLayers.enumerated() {
                let phase = (tick - i + 30) % 6
                let alpha: Float = phase < 3 ? (Float(phase) / 2.0 * 0.9) : (Float(6 - phase) / 3.0 * 0.6)
                layer.opacity = max(0.1, alpha)
            }
            tick += 1
        }
    }

    private func stopArrowAnimation() {
        moveArrowTimer?.invalidate()
        moveArrowTimer = nil
        moveArrowLayers.forEach { $0.opacity = 0.0 }
    }

    @objc private func doMoveToApplications() {
        guard !isMovingToApplications else { return }
        isMovingToApplications = true

        let src = Bundle.main.bundleURL
        let dst = URL(fileURLWithPath: "/Applications/VibeTalk.app")

        // Show spinner state
        if let btn = moveButton {
            btn.alphaValue = 0.5
            btn.isHidden = false
        }
        moveStatusLabel?.stringValue = "Moving…"
        moveStatusLabel?.textColor = NSColor(white: 1, alpha: 0.5)
        moveStatusLabel?.isHidden = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            var copyError: Error?
            do {
                if fm.fileExists(atPath: dst.path) {
                    try fm.removeItem(at: dst)
                }
                try fm.copyItem(at: src, to: dst)
            } catch {
                copyError = error
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                if let err = copyError {
                    self.moveStatusLabel?.stringValue = "Couldn't move automatically. Please drag the app to your Applications folder."
                    self.moveStatusLabel?.textColor = NSColor.systemOrange
                    self.moveStatusLabel?.isHidden = false
                    self.moveButton?.alphaValue = 1.0
                    self.isMovingToApplications = false
                    // Open Applications folder in Finder as fallback
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
                    _ = err
                } else {
                    self.showMoveSuccess(newPath: dst)
                }
            }
        }
    }

    private func showMoveSuccess(newPath: URL) {
        stopArrowAnimation()

        // Replace arrow chevrons with a checkmark feel — just update status label
        moveStatusLabel?.stringValue = "Moved successfully!"
        moveStatusLabel?.textColor = .systemGreen
        moveStatusLabel?.isHidden = false

        // Replace move button with Relaunch button
        moveButton?.isHidden = true

        guard let cv = window.contentView, let page = pages.first else { return }

        let relaunchBtn = accentButton("Relaunch VibeTalk", action: #selector(relaunchFromApplications), width: 280)
        relaunchBtn.frame.origin = NSPoint(x: (W - 280) / 2, y: 130)
        relaunchBtn.alphaValue = 0
        page.addSubview(relaunchBtn)

        _ = cv  // used above

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            relaunchBtn.animator().alphaValue = 1.0
        }
    }

    @objc private func relaunchFromApplications() {
        let dst = URL(fileURLWithPath: "/Applications/VibeTalk.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: dst, configuration: config) { _, _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NSApp.terminate(nil)
        }
    }

    @objc private func skipMoveToApps() {
        nextPage()
    }

    // MARK: - Page 1: Welcome

    private func buildPage1() {
        guard let cv = window.contentView else { return }
        let page = NSView(frame: cv.bounds)
        let cw = W - pad * 2

        // App icon — gradient rounded rect with mic
        let iconSz: CGFloat = 80
        let iconBg = NSView(frame: NSRect(x: (W - iconSz) / 2, y: H - 188, width: iconSz, height: iconSz))
        iconBg.wantsLayer = true
        iconBg.layer?.cornerRadius = 22
        let grad = CAGradientLayer()
        grad.frame = iconBg.bounds
        grad.colors = [accent.cgColor, accentLight.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 0)
        grad.endPoint = CGPoint(x: 1, y: 1)
        grad.cornerRadius = 22
        iconBg.layer?.addSublayer(grad)
        iconBg.shadow = NSShadow()
        iconBg.layer?.shadowColor = accent.withAlphaComponent(0.5).cgColor
        iconBg.layer?.shadowOffset = CGSize(width: 0, height: -4)
        iconBg.layer?.shadowRadius = 20
        iconBg.layer?.shadowOpacity = 1.0

        let mic = NSImageView(frame: NSRect(x: 20, y: 20, width: 40, height: 40))
        if let img = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 26, weight: .medium)) {
            mic.image = img; mic.contentTintColor = .white
        }
        iconBg.addSubview(mic)
        page.addSubview(iconBg)

        // Title
        let title = singleLbl("Welcome to VibeTalk", size: 28, weight: .bold, x: pad, y: H - 238, w: cw)
        title.alignment = .center
        page.addSubview(title)

        // Description
        let desc = multiLbl(
            "Talk instead of typing.\nYour voice stays on your Mac — completely\nprivate and forever free.",
            size: 15, x: pad, y: H - 310, w: cw, h: 56
        )
        desc.textColor = NSColor(white: 1, alpha: 0.5)
        desc.alignment = .center
        page.addSubview(desc)

        // Get Started button
        let btn = accentButton("Get Started", action: #selector(nextPage), width: 220)
        btn.frame.origin = NSPoint(x: (W - 220) / 2, y: 90)
        page.addSubview(btn)

        pages.append(page)
        cv.addSubview(page)
    }

    // MARK: - Page 2: Permissions

    private func buildPage2() {
        guard let cv = window.contentView else { return }
        let page = NSView(frame: cv.bounds)
        page.isHidden = true
        let cw = W - pad * 2

        let title = singleLbl("Grant Permissions", size: 28, weight: .bold, x: pad, y: H - 104, w: cw)
        title.alignment = .center
        page.addSubview(title)

        let sub = multiLbl(
            "VibeTalk needs three quick permissions.\nYou can change these in System Settings anytime.",
            size: 14, x: pad, y: H - 162, w: cw, h: 40
        )
        sub.textColor = NSColor(white: 1, alpha: 0.45)
        sub.alignment = .center
        page.addSubview(sub)

        // Permissions card
        let cardH: CGFloat = 250
        let cardY: CGFloat = H - 176 - cardH
        let permCard = makeCard(x: pad, y: cardY, w: cw, h: cardH)
        page.addSubview(permCard)

        var ry: CGFloat = cardH - 26

        let (md, mb) = permRow(icon: "mic.fill", title: "Microphone", desc: "So VibeTalk can hear you", action: #selector(grantMic), parent: permCard, y: &ry, w: cw)
        micDot = md; micBtn = mb

        addSep(to: permCard, y: ry - 8, w: cw - 44)
        ry -= 16

        let (sd, sb) = permRow(icon: "waveform", title: "Speech Recognition", desc: "To turn your voice into text", action: #selector(grantSpeech), parent: permCard, y: &ry, w: cw)
        speechDot = sd; speechBtn = sb

        addSep(to: permCard, y: ry - 8, w: cw - 44)
        ry -= 16

        let (ad, ab) = permRow(icon: "hand.raised.fill", title: "Accessibility", desc: "To paste text where you're typing", action: #selector(grantAccess), parent: permCard, y: &ry, w: cw)
        accessDot = ad; accessBtn = ab

        let btn = accentButton("Continue", action: #selector(nextPage), width: 220)
        btn.frame.origin = NSPoint(x: (W - 220) / 2, y: 90)
        page.addSubview(btn)

        pages.append(page)
        cv.addSubview(page)
    }

    // MARK: - Page 3: How to Use

    private func buildPage3() {
        guard let cv = window.contentView else { return }
        let page = NSView(frame: cv.bounds)
        page.isHidden = true
        let cw = W - pad * 2

        let title = singleLbl("You're all set!", size: 28, weight: .bold, x: pad, y: H - 104, w: cw)
        title.alignment = .center
        page.addSubview(title)

        let sub = singleLbl("Here's how to use VibeTalk:", size: 14, weight: .regular, x: pad, y: H - 138, w: cw)
        sub.textColor = NSColor(white: 1, alpha: 0.45)
        sub.alignment = .center
        page.addSubview(sub)

        // Steps card
        let stepsH: CGFloat = 220
        let stepsY: CGFloat = H - 156 - stepsH
        let stepsCard = makeCard(x: pad, y: stepsY, w: cw, h: stepsH)
        page.addSubview(stepsCard)

        var sy: CGFloat = stepsH - 22
        stepRow("1", "Click into any text field", "Any app — browser, Slack, Notes, anywhere", parent: stepsCard, y: &sy, w: cw)
        addSep(to: stepsCard, y: sy - 6, w: cw - 44)
        sy -= 12
        stepRow("2", "Press fn + Space", "Or Ctrl + Shift + Space to start recording", parent: stepsCard, y: &sy, w: cw)
        addSep(to: stepsCard, y: sy - 6, w: cw - 44)
        sy -= 12
        stepRow("3", "Press the hotkey again", "Your words are pasted right where you were typing", parent: stepsCard, y: &sy, w: cw)

        let note = multiLbl(
            "Look for a small floating pill at the bottom of your\nscreen — it shows when VibeTalk is listening.",
            size: 12, x: pad, y: stepsY - 50, w: cw, h: 34
        )
        note.textColor = NSColor(white: 1, alpha: 0.3)
        note.alignment = .center
        page.addSubview(note)

        let btn = accentButton("Start Using VibeTalk", action: #selector(finish), width: 240)
        btn.frame.origin = NSPoint(x: (W - 240) / 2, y: 90)
        page.addSubview(btn)

        pages.append(page)
        cv.addSubview(page)
    }

    // MARK: - Dots

    private func buildDots() {
        guard let cv = window.contentView else { return }
        let count = pages.count
        let dotSz: CGFloat = 7
        let gap: CGFloat = 10
        let totalW = dotSz * CGFloat(count) + gap * CGFloat(count - 1)
        let startX = (W - totalW) / 2

        for i in 0..<count {
            let dot = NSView(frame: NSRect(x: startX + CGFloat(i) * (dotSz + gap), y: 48, width: dotSz, height: dotSz))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = dotSz / 2
            dot.layer?.backgroundColor = (i == 0 ? accent : NSColor(white: 1, alpha: 0.15)).cgColor
            cv.addSubview(dot)
            pageDots.append(dot)
        }
    }

    // MARK: - Navigation

    private func showPage(_ index: Int, animated: Bool = true) {
        guard index >= 0 && index < pages.count else { return }
        let oldPage = currentPage
        currentPage = index

        for (i, dot) in pageDots.enumerated() {
            dot.layer?.backgroundColor = (i == index ? accent : NSColor(white: 1, alpha: 0.15)).cgColor
        }

        if animated && oldPage != index {
            let oldView = pages[oldPage]
            let newView = pages[index]
            newView.alphaValue = 0
            newView.isHidden = false

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                oldView.animator().alphaValue = 0
                newView.animator().alphaValue = 1
            }) {
                oldView.isHidden = true
                oldView.alphaValue = 1
            }
        } else {
            for (i, page) in pages.enumerated() { page.isHidden = (i != index) }
        }

        // Start or stop arrow animation for the move-to-apps page
        if needsMoveToApps && index == 0 {
            startArrowAnimation()
        } else {
            stopArrowAnimation()
        }

        // Start or stop permission checking for the permissions page
        let permPageIndex = needsMoveToApps ? 2 : 1
        if index == permPageIndex { startPermissionChecking() }
        else { permTimer?.invalidate(); permTimer = nil }
    }

    @objc private func nextPage() { showPage(currentPage + 1) }

    @objc private func finish() { window.close() }

    func windowWillClose(_ notification: Notification) {
        permTimer?.invalidate()
        permTimer = nil
        stopArrowAnimation()
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        onComplete?()
        onComplete = nil
    }

    // MARK: - Permissions

    @objc private func grantMic() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPermissions() }
        }
    }

    @objc private func grantSpeech() {
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPermissions() }
        }
    }

    @objc private func grantAccess() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    private func startPermissionChecking() {
        permTimer?.invalidate()
        refreshPermissions()
        permTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshPermissions()
        }
    }

    private func refreshPermissions() {
        let micOK = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let speechOK = SFSpeechRecognizer.authorizationStatus() == .authorized
        let axOK = AXIsProcessTrusted()

        setPermStatus(dot: micDot, btn: micBtn, granted: micOK)
        setPermStatus(dot: speechDot, btn: speechBtn, granted: speechOK)
        setPermStatus(dot: accessDot, btn: accessBtn, granted: axOK)
    }

    private func setPermStatus(dot: NSView, btn: NSButton, granted: Bool) {
        dot.layer?.backgroundColor = granted ? NSColor.systemGreen.cgColor : NSColor(white: 1, alpha: 0.2).cgColor
        if granted {
            btn.title = "Granted"
            btn.contentTintColor = .systemGreen
            btn.isEnabled = false
        } else {
            btn.title = "Grant"
            btn.contentTintColor = accent
            btn.isEnabled = true
        }
    }

    // MARK: - Show

    func show() {
        window.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) { NSApp.activate() }
        else { NSApp.activate(ignoringOtherApps: true) }
    }

    // MARK: - UI Helpers

    private func singleLbl(_ text: String, size: CGFloat, weight: NSFont.Weight, x: CGFloat, y: CGFloat, w: CGFloat) -> NSTextField {
        let l = NSTextField(frame: NSRect(x: x, y: y, width: w, height: size + 10))
        l.stringValue = text
        l.isEditable = false; l.isSelectable = false; l.isBordered = false; l.drawsBackground = false
        l.font = NSFont.systemFont(ofSize: size, weight: weight)
        l.textColor = .white
        return l
    }

    private func multiLbl(_ text: String, size: CGFloat, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSTextField {
        let l = NSTextField(frame: NSRect(x: x, y: y, width: w, height: h))
        l.stringValue = text
        l.isEditable = false; l.isSelectable = false; l.isBordered = false; l.drawsBackground = false
        l.font = NSFont.systemFont(ofSize: size, weight: .regular)
        l.textColor = .white
        l.maximumNumberOfLines = 0
        l.lineBreakMode = .byWordWrapping
        l.usesSingleLineMode = false
        return l
    }

    private func makeCard(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSView {
        let v = NSView(frame: NSRect(x: x, y: y, width: w, height: h))
        v.wantsLayer = true
        v.layer?.cornerRadius = 16
        v.layer?.backgroundColor = NSColor(white: 0.105, alpha: 1.0).cgColor
        v.layer?.borderWidth = 1
        v.layer?.borderColor = NSColor(white: 1, alpha: 0.055).cgColor
        return v
    }

    private func accentButton(_ title: String, action: Selector, width: CGFloat) -> NSView {
        let h: CGFloat = 46
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: h))
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.backgroundColor = accent.cgColor
        container.shadow = NSShadow()
        container.layer?.shadowColor = accent.withAlphaComponent(0.4).cgColor
        container.layer?.shadowOffset = CGSize(width: 0, height: -4)
        container.layer?.shadowRadius = 16
        container.layer?.shadowOpacity = 1.0

        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: width, height: h))
        btn.title = title
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        btn.contentTintColor = .white
        btn.target = self
        btn.action = action
        container.addSubview(btn)
        return container
    }

    private func permRow(icon: String, title: String, desc: String, action: Selector, parent: NSView, y: inout CGFloat, w: CGFloat) -> (NSView, NSButton) {
        let imgView = NSImageView(frame: NSRect(x: 22, y: y - 14, width: 22, height: 22))
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: title)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .medium)) {
            imgView.image = img
            imgView.contentTintColor = NSColor(white: 1, alpha: 0.5)
        }
        parent.addSubview(imgView)

        let titleLbl = singleLbl(title, size: 14, weight: .semibold, x: 54, y: y - 4, w: w - 160)
        titleLbl.textColor = NSColor(white: 1, alpha: 0.85)
        parent.addSubview(titleLbl)

        let descLbl = singleLbl(desc, size: 11, weight: .regular, x: 54, y: y - 24, w: w - 160)
        descLbl.textColor = NSColor(white: 1, alpha: 0.35)
        parent.addSubview(descLbl)

        // Status dot
        let dot = NSView(frame: NSRect(x: w - 100, y: y - 5, width: 8, height: 8))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = NSColor(white: 1, alpha: 0.2).cgColor
        parent.addSubview(dot)

        // Grant button
        let grantBtn = NSButton(frame: NSRect(x: w - 88, y: y - 14, width: 66, height: 24))
        grantBtn.title = "Grant"
        grantBtn.isBordered = false
        grantBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        grantBtn.contentTintColor = accent
        grantBtn.target = self
        grantBtn.action = action
        parent.addSubview(grantBtn)

        y -= 64
        return (dot, grantBtn)
    }

    private func stepRow(_ num: String, _ title: String, _ desc: String, parent: NSView, y: inout CGFloat, w: CGFloat) {
        let circSz: CGFloat = 28
        let circle = NSView(frame: NSRect(x: 22, y: y - 20, width: circSz, height: circSz))
        circle.wantsLayer = true
        circle.layer?.cornerRadius = circSz / 2
        circle.layer?.backgroundColor = accent.withAlphaComponent(0.15).cgColor
        circle.layer?.borderWidth = 1
        circle.layer?.borderColor = accent.withAlphaComponent(0.3).cgColor

        let numLbl = singleLbl(num, size: 13, weight: .bold, x: 0, y: 4, w: circSz)
        numLbl.alignment = .center
        numLbl.textColor = accentLight
        circle.addSubview(numLbl)
        parent.addSubview(circle)

        let titleLbl = singleLbl(title, size: 14, weight: .semibold, x: 62, y: y - 4, w: w - 84)
        titleLbl.textColor = NSColor(white: 1, alpha: 0.85)
        parent.addSubview(titleLbl)

        let descLbl = singleLbl(desc, size: 11, weight: .regular, x: 62, y: y - 24, w: w - 84)
        descLbl.textColor = NSColor(white: 1, alpha: 0.35)
        parent.addSubview(descLbl)

        y -= 56
    }

    private func addSep(to parent: NSView, y: CGFloat, w: CGFloat) {
        let sep = NSView(frame: NSRect(x: 22, y: y, width: w, height: 1))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
        parent.addSubview(sep)
    }

    deinit {
        permTimer?.invalidate()
        stopArrowAnimation()
    }
}
