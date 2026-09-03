#!/usr/bin/env swift
//
// Renders the DMG installer window background (a branded canvas with a big
// arrow pointing from the app icon to the Applications folder) as a retina
// multi-resolution TIFF that Finder uses as the disk-image window background.
//
// Output: Packaging/dmg-background.tiff  (1x + 2x representations)
//
// Layout constants here MUST match the Finder window geometry in make_dmg.sh:
//   window content  = 640 x 420 pt
//   app icon center = (165, 205)   (Finder top-left coordinates)
//   apps icon center= (475, 205)
//
import AppKit

let W: CGFloat = 640
let H: CGFloat = 420

// Brand palette
let ink   = NSColor(srgbRed: 0.04, green: 0.05, blue: 0.09, alpha: 1)
let muted = NSColor(srgbRed: 0.36, green: 0.38, blue: 0.46, alpha: 1)
let indigo = NSColor(srgbRed: 0.29, green: 0.12, blue: 0.90, alpha: 1)
let teal   = NSColor(srgbRed: 0.07, green: 0.70, blue: 0.65, alpha: 1)

func drawRep(scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(W) * scale,
        pixelsHigh: Int(H) * scale,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: W, height: H)

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // Background: soft vertical gradient, near-white.
    let bg = NSGradient(colors: [
        NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        NSColor(srgbRed: 0.965, green: 0.968, blue: 0.984, alpha: 1)
    ])!
    bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

    // Title + subtitle (top of the window).
    func centered(_ s: String, font: NSFont, color: NSColor, topY: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (s as NSString).size(withAttributes: attrs)
        let x = (W - size.width) / 2
        let y = H - topY - size.height
        (s as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }
    centered("Install TextPolisher",
             font: .systemFont(ofSize: 26, weight: .bold), color: ink, topY: 34)
    centered("Drag the app onto the Applications folder",
             font: .systemFont(ofSize: 13, weight: .regular), color: muted, topY: 72)

    // Big arrow between the two icons (icon centers at top-y 205 -> AppKit y).
    let cy = H - 205
    let shaftLeft: CGFloat = 246
    let shaftRight: CGFloat = 372
    let shaftHeight: CGFloat = 18
    let headTip: CGFloat = 418
    let headHalf: CGFloat = 26

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: shaftLeft, y: cy - shaftHeight / 2))
    arrow.line(to: NSPoint(x: shaftRight, y: cy - shaftHeight / 2))
    arrow.line(to: NSPoint(x: shaftRight, y: cy - headHalf))
    arrow.line(to: NSPoint(x: headTip, y: cy))
    arrow.line(to: NSPoint(x: shaftRight, y: cy + headHalf))
    arrow.line(to: NSPoint(x: shaftRight, y: cy + shaftHeight / 2))
    arrow.line(to: NSPoint(x: shaftLeft, y: cy + shaftHeight / 2))
    arrow.close()

    let arrowGradient = NSGradient(colors: [indigo, teal])!
    arrowGradient.draw(in: arrow, angle: 0)

    // Footer hint.
    centered("After installing, open the app and grant Accessibility access when asked.",
             font: .systemFont(ofSize: 11, weight: .regular), color: muted, topY: H - 30)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let image = NSImage(size: NSSize(width: W, height: H))
image.addRepresentation(drawRep(scale: 1))
image.addRepresentation(drawRep(scale: 2))

guard let tiff = image.tiffRepresentation else {
    FileHandle.standardError.write("Failed to produce TIFF\n".data(using: .utf8)!)
    exit(1)
}

let root = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
    .deletingLastPathComponent().deletingLastPathComponent()
let out = root.appendingPathComponent("Packaging/dmg-background.tiff")
do {
    try tiff.write(to: out)
    print("Wrote \(out.path)")
} catch {
    FileHandle.standardError.write("Write failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
