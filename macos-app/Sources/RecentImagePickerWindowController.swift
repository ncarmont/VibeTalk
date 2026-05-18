import Cocoa
import ImageIO
import UniformTypeIdentifiers

struct RecentDesktopImage {
    let url: URL
    let image: NSImage
    let sortDate: Date
}

private func pasteboardType(for url: URL) -> NSPasteboard.PasteboardType? {
    guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
    return NSPasteboard.PasteboardType(type.identifier)
}

private final class ImageFileDataProvider: NSObject, NSPasteboardItemDataProvider {
    private let url: URL
    init(url: URL) { self.url = url }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        guard let data = try? Data(contentsOf: url) else { return }
        item.setData(data, forType: type)
    }

    func pasteboardFinishedWithDataProvider(_ pasteboard: NSPasteboard) {}
}

final class RecentImageThumbnailView: NSView, NSDraggingSource {
    let item: RecentDesktopImage
    var onClick: ((RecentDesktopImage) -> Void)?
    var onDragCompleted: (() -> Void)?

    private let imageView = NSImageView()
    private let isLatest: Bool
    private var mouseDownPoint: NSPoint?
    private var didStartDrag = false
    private var tracking: NSTrackingArea?
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)

    init(frame: NSRect, item: RecentDesktopImage, isLatest: Bool = false) {
        self.item = item
        self.isLatest = isLatest
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        applyBaseStyle()

        imageView.image = item.image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = bounds.insetBy(dx: 4, dy: 4)
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)

        if isLatest {
            let badge = NSTextField(frame: NSRect(x: 6, y: bounds.height - 22, width: 42, height: 16))
            badge.stringValue = "latest"
            badge.isEditable = false
            badge.isSelectable = false
            badge.isBordered = false
            badge.drawsBackground = false
            badge.alignment = .center
            badge.font = NSFont.systemFont(ofSize: 9, weight: .semibold)
            badge.textColor = .white
            badge.wantsLayer = true
            badge.layer?.cornerRadius = 8
            badge.layer?.masksToBounds = true
            badge.layer?.backgroundColor = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 0.92).cgColor
            badge.autoresizingMask = [.minYMargin]
            addSubview(badge)

            let pulse = CABasicAnimation(keyPath: "borderColor")
            pulse.fromValue = accent.withAlphaComponent(0.78).cgColor
            pulse.toValue = accent.withAlphaComponent(0.34).cgColor
            pulse.duration = 0.85
            pulse.autoreverses = true
            pulse.repeatCount = 2
            layer?.add(pulse, forKey: "latestScreenshotPulse")
        }

        toolTip = "Click to paste \(item.url.lastPathComponent). Drag and drop images to the AI chat."
    }

    private func applyBaseStyle() {
        if isLatest {
            layer?.backgroundColor = accent.withAlphaComponent(0.13).cgColor
            layer?.borderColor = accent.withAlphaComponent(0.48).cgColor
            layer?.shadowColor = accent.withAlphaComponent(0.28).cgColor
            layer?.shadowOpacity = 1
            layer?.shadowRadius = 8
            layer?.shadowOffset = .zero
        } else {
            layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
            layer?.borderColor = NSColor(white: 1, alpha: 0.10).cgColor
            layer?.shadowOpacity = 0
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // point is in superview coordinate space; use frame (also superview space) not bounds
        frame.contains(point) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        if let tracking { addTrackingArea(tracking) }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = accent.withAlphaComponent(0.24).cgColor
        layer?.borderColor = accent.withAlphaComponent(0.66).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        applyBaseStyle()
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        didStartDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        guard !didStartDrag, hypot(current.x - start.x, current.y - start.y) > 4 else { return }

        didStartDrag = true

        let pasteboardItem = Self.makePasteboardItem(for: item)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: item.image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownPoint = nil
            didStartDrag = false
        }
        guard !didStartDrag else { return }
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onClick?(item)
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            onDragCompleted?()
        }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    static func makePasteboardItem(for item: RecentDesktopImage) -> NSPasteboardItem {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.url.absoluteString, forType: .fileURL)
        pasteboardItem.setString(item.url.path, forType: .string)

        if let type = pasteboardType(for: item.url) {
            let provider = ImageFileDataProvider(url: item.url)
            pasteboardItem.setDataProvider(provider, forTypes: [type])
        }
        if let tiffData = item.image.tiffRepresentation {
            pasteboardItem.setData(tiffData, forType: .tiff)
        }

        return pasteboardItem
    }
}

final class CarouselArrowButton: NSView {
    var onHover: (() -> Void)?
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

    var pointingLeft = false

    func configure() {
        wantsLayer = true
        layer?.cornerRadius = max(bounds.width, bounds.height) / 2
        layer?.backgroundColor = accent.withAlphaComponent(0.22).cgColor
        iconLayer.contentsGravity = .resizeAspect
        if iconLayer.superlayer == nil {
            layer?.addSublayer(iconLayer)
        }
        let symbol = pointingLeft ? "chevron.left" : "chevron.right"
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .bold)) {
            iconLayer.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
            iconLayer.opacity = 0.95
        }
        toolTip = pointingLeft ? "Previous 3 screenshots" : "Next 3 screenshots"
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        iconLayer.frame = bounds.insetBy(dx: 8, dy: 7)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        if let tracking { addTrackingArea(tracking) }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = accent.withAlphaComponent(0.42).cgColor
        onHover?()
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = accent.withAlphaComponent(0.22).cgColor
    }

    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onClick?()
        }
    }
}

final class RecentImagePickerWindowController: NSObject {
    private var panel: NSPanel!
    private var bgView: NSView!
    private var anchorFrame: NSRect = .zero
    private var targetApp: NSRunningApplication?
    private var cachedItems: [RecentDesktopImage] = []
    private var hasLoadedCache = false
    private var loadGeneration = 0
    private var pageStart = 0
    private var isAnimatingPage = false
    private var carouselClipView: NSView?
    private var carouselRowView: NSView?
    private var autoPasteGeneration = 0
    private var autoPasteScheduledGeneration: Int?
    private let imageQueue = DispatchQueue(label: "com.vibetalk.recent-images", qos: .userInitiated)

    private(set) var isVisible = false
    var onImageSelected: ((RecentDesktopImage, NSRunningApplication?) -> Void)?
    var onVisibilityChanged: ((Bool) -> Void)?

    private let panelW: CGFloat = 342
    private let panelH: CGFloat = 126
    private let headerH: CGFloat = 34
    private let hPad: CGFloat = 16
    private let gap: CGFloat = 8
    private let pageSize = 3
    private let maxCachedScreenshots = 18
    private let thumbW: CGFloat = 78
    private let thumbH: CGFloat = 64
    private let arrowSize: CGFloat = 28
    private let accent = NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)
    private var rowW: CGFloat {
        CGFloat(pageSize) * thumbW + CGFloat(pageSize - 1) * gap
    }

    override init() {
        super.init()
        buildPanel()
        refreshRecentImages()
    }

    func toggle(anchorFrame: NSRect, targetApp: NSRunningApplication?) -> Bool {
        if isVisible {
            close()
            return false
        }
        open(anchorFrame: anchorFrame, targetApp: targetApp)
        return isVisible
    }

    func open(anchorFrame: NSRect, targetApp: NSRunningApplication?) {
        autoPasteGeneration += 1
        self.anchorFrame = anchorFrame
        self.targetApp = targetApp
        showPanel(isLoading: !hasLoadedCache)
        refreshRecentImages()
    }

    func openAndPasteLatest(anchorFrame: NSRect, targetApp: NSRunningApplication?) {
        autoPasteGeneration += 1
        let generation = autoPasteGeneration
        autoPasteScheduledGeneration = nil
        pageStart = 0
        self.anchorFrame = anchorFrame
        self.targetApp = targetApp
        showPanel(isLoading: !hasLoadedCache)
        refreshRecentImages { [weak self] items in
            guard let self else { return }
            guard self.autoPasteGeneration == generation else { return }
            guard let latest = items.first else {
                self.showCenteredMessage("No recent screenshots found on Desktop")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard self?.autoPasteGeneration == generation else { return }
                    self?.close()
                }
                return
            }
            self.scheduleLatestPaste(latest, generation: generation)
        }
    }

    func close() {
        autoPasteGeneration += 1
        autoPasteScheduledGeneration = nil
        isVisible = false
        targetApp = nil
        panel.orderOut(nil)
        onVisibilityChanged?(false)
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

    private func showPanel(isLoading: Bool) {
        rebuild(items: cachedItems, isLoading: isLoading)
        updatePosition(anchorFrame: anchorFrame)
        isVisible = true
        onVisibilityChanged?(true)
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1.0
        }
    }

    private func buildPanel() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelW, height: panelH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
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

    private func rebuild(items: [RecentDesktopImage], isLoading: Bool = false) {
        bgView.subviews.forEach { $0.removeFromSuperview() }
        carouselClipView = nil
        carouselRowView = nil
        isAnimatingPage = false

        let title = NSTextField(frame: NSRect(x: hPad, y: panelH - headerH + 8, width: panelW - hPad * 2, height: 18))
        title.stringValue = "Drag and drop images to the AI chat"
        title.isEditable = false
        title.isSelectable = false
        title.isBordered = false
        title.drawsBackground = false
        title.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        title.textColor = NSColor(white: 1, alpha: 0.82)
        bgView.addSubview(title)

        if isLoading {
            showCenteredMessage("Loading recent Desktop images...")
            return
        }

        guard !items.isEmpty else {
            showCenteredMessage("No recent screenshots found on Desktop")
            return
        }

        if pageStart >= items.count { pageStart = 0 }

        let showLeftArrow = pageStart > 0
        let clipX: CGFloat = showLeftArrow ? hPad + arrowSize + 4 : hPad

        let clip = NSView(frame: NSRect(x: clipX, y: 12, width: rowW, height: thumbH + 4))
        clip.wantsLayer = true
        clip.layer?.masksToBounds = true
        bgView.addSubview(clip)
        carouselClipView = clip

        let row = makeCarouselRow(items: items, start: pageStart)
        clip.addSubview(row)
        carouselRowView = row

        if items.count > pageSize {
            let rightArrow = CarouselArrowButton(frame: NSRect(
                x: panelW - hPad - arrowSize,
                y: 12 + (thumbH + 4 - arrowSize) / 2,
                width: arrowSize,
                height: arrowSize
            ))
            rightArrow.onHover = { [weak self] in self?.advanceCarousel() }
            rightArrow.onClick = { [weak self] in self?.advanceCarousel() }
            bgView.addSubview(rightArrow)
        }

        if showLeftArrow {
            let leftArrow = CarouselArrowButton(frame: NSRect(
                x: hPad,
                y: 12 + (thumbH + 4 - arrowSize) / 2,
                width: arrowSize,
                height: arrowSize
            ))
            leftArrow.pointingLeft = true
            leftArrow.configure()
            leftArrow.onHover = { [weak self] in self?.retreatCarousel() }
            leftArrow.onClick = { [weak self] in self?.retreatCarousel() }
            bgView.addSubview(leftArrow)
        }
    }

    private func makeCarouselRow(items: [RecentDesktopImage], start: Int) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: rowW, height: thumbH + 4))
        let end = min(start + pageSize, items.count)
        guard start < end else { return row }

        for (offset, item) in items[start..<end].enumerated() {
            let thumb = RecentImageThumbnailView(
                frame: NSRect(x: CGFloat(offset) * (thumbW + gap), y: 2, width: thumbW, height: thumbH),
                item: item,
                isLatest: start + offset == 0
            )
            thumb.onClick = { [weak self] selected in
                guard let self else { return }
                let app = self.targetApp
                self.close()
                self.onImageSelected?(selected, app)
            }
            thumb.onDragCompleted = { [weak self] in
                self?.close()
            }
            row.addSubview(thumb)
        }

        return row
    }

    private func advanceCarousel() {
        guard !isAnimatingPage, cachedItems.count > pageSize else { return }
        let nextStart = pageStart + pageSize >= cachedItems.count ? 0 : pageStart + pageSize
        animateCarousel(to: nextStart)
    }

    private func retreatCarousel() {
        guard !isAnimatingPage, pageStart > 0 else { return }
        let prevStart = max(0, pageStart - pageSize)
        animateCarousel(to: prevStart, direction: -1)
    }

    private func animateCarousel(to nextStart: Int, direction: CGFloat = 1) {
        guard let clip = carouselClipView,
              let oldRow = carouselRowView,
              nextStart != pageStart else { return }

        isAnimatingPage = true
        pageStart = nextStart

        let travel = rowW + gap
        let newRow = makeCarouselRow(items: cachedItems, start: nextStart)
        newRow.frame.origin.x = direction * travel
        clip.addSubview(newRow)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            oldRow.animator().frame.origin.x = -direction * travel
            newRow.animator().frame.origin.x = 0
        }, completionHandler: { [weak self, weak oldRow, weak newRow] in
            oldRow?.removeFromSuperview()
            self?.carouselRowView = newRow
            self?.isAnimatingPage = false
            // Rebuild so left/right arrows update correctly after navigation
            if let self, self.isVisible {
                self.rebuild(items: self.cachedItems)
            }
        })
    }

    private func showCenteredMessage(_ message: String) {
        let label = NSTextField(frame: NSRect(x: hPad, y: 42, width: panelW - hPad * 2, height: 18))
        label.stringValue = message
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = NSColor(white: 1, alpha: 0.48)
        bgView.addSubview(label)
    }

    private func scheduleLatestPaste(_ item: RecentDesktopImage, generation: Int) {
        guard autoPasteScheduledGeneration != generation else { return }
        autoPasteScheduledGeneration = generation

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) { [weak self] in
            guard let self else { return }
            guard self.autoPasteGeneration == generation, self.isVisible else { return }
            let app = self.targetApp
            self.onImageSelected?(item, app)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) { [weak self] in
                guard self?.autoPasteGeneration == generation else { return }
                self?.close()
            }
        }
    }

    private func refreshRecentImages(completion: (([RecentDesktopImage]) -> Void)? = nil) {
        loadGeneration += 1
        let generation = loadGeneration

        imageQueue.async { [weak self] in
            let items = Self.loadRecentDesktopScreenshots(limit: self?.maxCachedScreenshots ?? 18)
            DispatchQueue.main.async {
                guard let self, self.loadGeneration == generation else { return }
                self.cachedItems = items
                self.hasLoadedCache = true
                self.pageStart = 0
                if self.isVisible {
                    self.rebuild(items: items)
                    self.updatePosition(anchorFrame: self.anchorFrame)
                }
                completion?(items)
            }
        }
    }

    private static func loadRecentDesktopScreenshots(limit: Int) -> [RecentDesktopImage] {
        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            return []
        }

        let allowedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif", "webp", "bmp"]
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .creationDateKey]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: desktopURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let candidates = urls.compactMap { url -> (url: URL, date: Date)? in
            guard allowedExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            guard isScreenshotURL(url) else { return nil }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { return nil }
            let date = values.contentModificationDate ?? values.creationDate ?? .distantPast
            return (url, date)
        }
        .sorted { $0.date > $1.date }

        var items: [RecentDesktopImage] = []
        for candidate in candidates {
            guard let image = makeThumbnail(for: candidate.url, maxPixelSize: 220) else { continue }
            items.append(RecentDesktopImage(url: candidate.url, image: image, sortDate: candidate.date))
            if items.count == limit { break }
        }
        return items
    }

    private static func isScreenshotURL(_ url: URL) -> Bool {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        return name.contains("screenshot")
            || name.contains("screen shot")
            || name.contains("cleanshot")
            || name.contains("clean shot")
            || name.contains("shottr")
    }

    private static func makeThumbnail(for url: URL, maxPixelSize: CGFloat) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }
}
