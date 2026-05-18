import Cocoa

// Subclass so buttons in a non-activating panel still accept clicks
class HistoryRowButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

class HistoryWindowController: NSObject {

    private var panel: NSPanel!
    private var bgView: NSView!

    private var completedEntries: [String] = []  // max 9 finalized recordings
    private var liveEntry: String = ""           // current in-progress recording

    private let maxCompleted = 9
    private let rowH: CGFloat   = 36
    private let vPad: CGFloat   = 8
    private let hPad: CGFloat   = 14
    private let panelW: CGFloat = 340
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)

    override init() {
        super.init()
        buildPanel()
    }

    // MARK: - Public

    /// Call on every partial result while recording — updates the live bottom row
    func updateLive(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard liveEntry != t else { return }
        liveEntry = t
        rebuildRows()
    }

    /// Call when a recording is finalized — locks in the entry
    func finalizeLive(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty {
            completedEntries.append(t)
            if completedEntries.count > maxCompleted { completedEntries.removeFirst() }
        }
        liveEntry = ""
        rebuildRows()
    }

    private(set) var isVisible = false

    var hasContent: Bool { !completedEntries.isEmpty || !liveEntry.isEmpty }

    func toggle() -> Bool {
        if isVisible { close(); return false }
        else {
            open()
            return isVisible
        }
    }

    func open() {
        guard hasContent else { return }
        rebuildRows()
        isVisible = true
        panel.orderFront(nil)
    }

    func close() {
        isVisible = false
        panel.orderOut(nil)
    }

    /// Reposition just above the right end of the pill. Call whenever the pill moves or resizes.
    func updatePosition(pillFrame: NSRect) {
        let h = totalHeight()
        var x = pillFrame.maxX - panelW
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(pillFrame) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            x = max(frame.minX + 4, min(x, frame.maxX - panelW - 4))
        }
        let y = pillFrame.maxY + 6
        panel.setFrame(NSRect(x: x, y: y, width: panelW, height: h), display: false)
        if isVisible { panel.orderFront(nil) }
    }

    // MARK: - Panel setup

    private func buildPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelW, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false

        bgView = NSView()
        bgView.wantsLayer = true
        bgView.layer?.cornerRadius = 14
        bgView.layer?.backgroundColor = NSColor(red: 0.067, green: 0.067, blue: 0.078, alpha: 0.97).cgColor
        bgView.layer?.borderWidth = 1
        bgView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.09).cgColor
        panel.contentView = bgView
    }

    // MARK: - Rendering

    private func allRows() -> [String] {
        var rows = completedEntries
        if !liveEntry.isEmpty { rows.append(liveEntry) }
        return rows
    }

    private func totalHeight() -> CGFloat {
        let rows = allRows()
        return CGFloat(max(1, rows.count)) * rowH + vPad * 2
    }

    private func rebuildRows() {
        bgView.subviews.forEach { $0.removeFromSuperview() }

        let rows = allRows()
        let h = totalHeight()
        bgView.frame = NSRect(x: 0, y: 0, width: panelW, height: h)
        panel.setContentSize(NSSize(width: panelW, height: h))

        guard !rows.isEmpty else { close(); return }

        let count        = rows.count
        let isLivePresent = !liveEntry.isEmpty
        let copyBtnW: CGFloat = 28

        for (i, text) in rows.enumerated() {
            let isLive    = isLivePresent && i == count - 1
            let age       = count - 1 - i              // 0 = newest / live
            let baseAlpha = max(0.22, 1.0 - CGFloat(age) * 0.11)
            let y         = vPad + CGFloat(i) * rowH

            // Dot
            let dotSz: CGFloat = 5
            let dot = NSView(frame: NSRect(x: hPad, y: y + (rowH - dotSz) / 2 + 1, width: dotSz, height: dotSz))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = dotSz / 2
            dot.layer?.backgroundColor = isLive
                ? NSColor.systemGreen.cgColor
                : accent.withAlphaComponent(baseAlpha * 0.7).cgColor
            bgView.addSubview(dot)

            // Copy button (hidden for live entry)
            let copyBtn = HistoryRowButton(frame: NSRect(
                x: panelW - hPad - copyBtnW,
                y: y + (rowH - 22) / 2,
                width: copyBtnW, height: 22
            ))
            if !isLive {
                let cfg = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
                if let img = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")?
                    .withSymbolConfiguration(cfg) {
                    copyBtn.image = img
                }
                copyBtn.isBordered     = false
                copyBtn.bezelStyle     = .inline
                copyBtn.wantsLayer     = true
                copyBtn.layer?.cornerRadius = 5
                copyBtn.layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
                copyBtn.contentTintColor = NSColor(white: 1, alpha: baseAlpha * 0.6)
                let capturedText = text
                copyBtn.target = self
                copyBtn.action = #selector(copyTapped(_:))
                copyBtn.toolTip = capturedText  // store full text in toolTip for retrieval
                bgView.addSubview(copyBtn)
            }

            // Text label
            let lx  = hPad + dotSz + 8
            let lw  = panelW - lx - (isLive ? hPad : copyBtnW + hPad + 4)
            let lbl = NSTextField(frame: NSRect(x: lx, y: y + 5, width: lw, height: rowH - 8))
            let display = text.count > 42 ? String(text.prefix(39)) + "…" : text
            lbl.stringValue    = display
            lbl.isEditable     = false
            lbl.isSelectable   = false
            lbl.isBordered     = false
            lbl.drawsBackground = false
            lbl.font           = NSFont.systemFont(ofSize: 12.5,
                                                   weight: isLive ? .semibold : (age == 0 ? .medium : .regular))
            lbl.textColor      = isLive
                ? NSColor.systemGreen.withAlphaComponent(0.9)
                : NSColor(white: 1, alpha: baseAlpha)
            lbl.lineBreakMode  = .byTruncatingHead   // show latest words
            bgView.addSubview(lbl)
        }
    }

    @objc private func copyTapped(_ sender: NSButton) {
        if let text = sender.toolTip, !text.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)

            // Brief visual feedback
            sender.contentTintColor = NSColor.systemGreen.withAlphaComponent(0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                sender.contentTintColor = NSColor(white: 1, alpha: 0.4)
            }
        }
    }
}
