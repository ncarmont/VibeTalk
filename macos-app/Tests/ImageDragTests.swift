import Cocoa
import Foundation
import UniformTypeIdentifiers

struct ImageDragTestFailure: Error, CustomStringConvertible {
    let description: String
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw ImageDragTestFailure(description: message)
    }
}

func makePNGFixture() throws -> (url: URL, image: NSImage) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 8,
        pixelsHigh: 8,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )

    guard let rep else {
        throw ImageDragTestFailure(description: "Could not create bitmap fixture.")
    }

    for x in 0..<8 {
        for y in 0..<8 {
            let color = x == y
                ? NSColor(calibratedRed: 0.45, green: 0.35, blue: 0.95, alpha: 1.0)
                : NSColor(calibratedRed: 0.20, green: 0.85, blue: 0.35, alpha: 1.0)
            rep.setColor(color, atX: x, y: y)
        }
    }

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw ImageDragTestFailure(description: "Could not encode PNG fixture.")
    }

    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("Screenshot VibeTalk Drag Test.png")
    try data.write(to: url, options: .atomic)

    guard let image = NSImage(data: data) else {
        throw ImageDragTestFailure(description: "Could not create NSImage fixture.")
    }

    return (url, image)
}

func runImageDragTests() throws {
    let fixture = try makePNGFixture()
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    let item = RecentDesktopImage(url: fixture.url, image: fixture.image, sortDate: Date())
    let pasteboardItem = RecentImageThumbnailView.makePasteboardItem(for: item)

    try require(
        pasteboardItem.string(forType: .fileURL) == fixture.url.absoluteString,
        "Drag pasteboard is missing the file URL."
    )
    try require(
        pasteboardItem.string(forType: .string) == fixture.url.path,
        "Drag pasteboard is missing the plain file path."
    )
    let pngType = NSPasteboard.PasteboardType(UTType.png.identifier)
    try require(
        pasteboardItem.data(forType: pngType) != nil,
        "Drag pasteboard is missing PNG data."
    )
    try require(
        pasteboardItem.data(forType: .tiff) != nil,
        "Drag pasteboard is missing TIFF fallback data."
    )

    let thumb = RecentImageThumbnailView(
        frame: NSRect(x: 0, y: 0, width: 78, height: 64),
        item: item
    )
    try require(
        thumb.hitTest(NSPoint(x: 10, y: 10)) === thumb,
        "Thumbnail hit testing should return the draggable thumbnail, not its image subview."
    )
    try require(
        thumb.hitTest(NSPoint(x: 100, y: 100)) == nil,
        "Thumbnail hit testing should ignore outside points."
    )

    print("Image drag tests passed.")
}

@main
struct ImageDragTestRunner {
    static func main() {
        do {
            try runImageDragTests()
        } catch {
            fputs("Image drag tests failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
