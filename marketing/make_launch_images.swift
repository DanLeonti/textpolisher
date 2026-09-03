#!/usr/bin/env swift
//
// Renders Product Hunt gallery images for TextPolisher at 1280x800 @2x.
// Output: marketing/ph-privacy.png, marketing/ph-features.png
//
import AppKit

let W: CGFloat = 1280, H: CGFloat = 800

let ink    = NSColor(srgbRed: 0.04, green: 0.05, blue: 0.09, alpha: 1)
let muted   = NSColor(srgbRed: 0.40, green: 0.42, blue: 0.50, alpha: 1)
let faint   = NSColor(srgbRed: 0.62, green: 0.64, blue: 0.70, alpha: 1)
let indigo  = NSColor(srgbRed: 0.29, green: 0.12, blue: 0.90, alpha: 1)
let teal    = NSColor(srgbRed: 0.07, green: 0.70, blue: 0.65, alpha: 1)

// Convert a top-left rect to AppKit (bottom-left) coordinates.
func r(_ topY: CGFloat, _ height: CGFloat, _ x: CGFloat, _ width: CGFloat) -> NSRect {
    NSRect(x: x, y: H - topY - height, width: width, height: height)
}

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func paragraph(_ align: NSTextAlignment, lineSpacing: CGFloat = 0) -> NSParagraphStyle {
    let p = NSMutableParagraphStyle()
    p.alignment = align
    p.lineBreakMode = .byWordWrapping
    p.lineSpacing = lineSpacing
    return p
}

func draw(_ s: String, in rect: NSRect, font: NSFont, color: NSColor, align: NSTextAlignment, spacing: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: paragraph(align, lineSpacing: spacing),
    ]
    (s as NSString).draw(in: rect, withAttributes: attrs)
}

func lightBackground() {
    let bg = NSGradient(colors: [
        NSColor.white,
        NSColor(srgbRed: 0.961, green: 0.965, blue: 0.984, alpha: 1),
    ])!
    bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
}

func brandMark(topY: CGFloat) {
    let dot = rounded(r(topY, 26, 64, 26), 8)
    NSGradient(colors: [indigo, teal])!.draw(in: dot, angle: 45)
    draw("TextPolisher", in: r(topY - 2, 30, 100, 300),
         font: .systemFont(ofSize: 20, weight: .semibold), color: ink, align: .left)
}

func gradientArrow(centerY: CGFloat, fromX: CGFloat, toTip: CGFloat) {
    let cy = H - centerY
    let shaftRight = toTip - 34
    let p = NSBezierPath()
    p.move(to: NSPoint(x: fromX, y: cy - 9))
    p.line(to: NSPoint(x: shaftRight, y: cy - 9))
    p.line(to: NSPoint(x: shaftRight, y: cy - 24))
    p.line(to: NSPoint(x: toTip, y: cy))
    p.line(to: NSPoint(x: shaftRight, y: cy + 24))
    p.line(to: NSPoint(x: shaftRight, y: cy + 9))
    p.line(to: NSPoint(x: fromX, y: cy + 9))
    p.close()
    NSGradient(colors: [indigo, teal])!.draw(in: p, angle: 0)
}

func render(_ name: String, _ body: () -> Void) {
    let scale = 2
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(W) * scale, pixelsHigh: Int(H) * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    body()
    NSGraphicsContext.restoreGraphicsState()
    let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("marketing")
        .appendingPathComponent(name)
    try! rep.representation(using: .png, properties: [:])!.write(to: outputURL)
    print("wrote \(outputURL.path)")
}

// MARK: - Image A: Privacy

render("ph-privacy.png") {
    lightBackground()
    brandMark(topY: 48)

    // Pill: On-device · Works offline
    let pillText = "ON-DEVICE · WORKS OFFLINE"
    let pillFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
    let pw = (pillText as NSString).size(withAttributes: [.font: pillFont]).width + 44
    let pill = r(206, 42, (W - pw) / 2, pw)
    NSGradient(colors: [indigo, teal])!.draw(in: rounded(pill, 21), angle: 0)
    draw(pillText, in: r(216, 24, 0, W), font: pillFont, color: .white, align: .center, spacing: 0)

    draw("Any app. Zero internet.", in: r(280, 120, 0, W),
         font: .systemFont(ofSize: 86, weight: .bold), color: ink, align: .center)

    draw("Works anywhere you can select text — Slack, Mail, Notes, your browser, your IDE. "
         + "No network, no API calls, no telemetry. 0 bytes ever leave your Mac.",
         in: r(428, 150, (W - 940) / 2, 940),
         font: .systemFont(ofSize: 26, weight: .regular), color: muted, align: .center, spacing: 6)

    draw("textpolisher.app", in: r(716, 28, 0, W),
         font: .systemFont(ofSize: 18, weight: .medium), color: faint, align: .center)
}

// MARK: - Image B: Features / before-after

render("ph-features.png") {
    lightBackground()
    brandMark(topY: 48)

    draw("Fix your writing in any app — in one keystroke.",
         in: r(122, 60, 0, W),
         font: .systemFont(ofSize: 42, weight: .bold), color: ink, align: .center)

    let cardW: CGFloat = 380, cardH: CGFloat = 180, top: CGFloat = 250
    let leftX: CGFloat = 150, rightX: CGFloat = W - 150 - cardW

    // Before card
    let before = r(top, cardH, leftX, cardW)
    NSColor(srgbRed: 0.95, green: 0.95, blue: 0.97, alpha: 1).setFill()
    rounded(before, 18).fill()
    draw("BEFORE", in: r(top + 18, 18, leftX + 22, 200),
         font: .systemFont(ofSize: 13, weight: .semibold), color: faint, align: .left)
    draw("hey so i think we shud maybe push the launch?? lmk what u think",
         in: r(top + 48, 110, leftX + 22, cardW - 44),
         font: .systemFont(ofSize: 21, weight: .regular), color: muted, align: .left, spacing: 4)

    // After card
    let after = r(top, cardH, rightX, cardW)
    NSColor.white.setFill()
    rounded(after, 18).fill()
    let border = rounded(after.insetBy(dx: 1, dy: 1), 17)
    border.lineWidth = 2
    indigo.setStroke()
    border.stroke()
    draw("AFTER", in: r(top + 18, 18, rightX + 22, 200),
         font: .systemFont(ofSize: 13, weight: .semibold), color: indigo, align: .left)
    draw("Hey — I think we should push the launch. Let me know your thoughts.",
         in: r(top + 48, 110, rightX + 22, cardW - 44),
         font: .systemFont(ofSize: 21, weight: .medium), color: ink, align: .left, spacing: 4)

    gradientArrow(centerY: top + cardH / 2, fromX: leftX + cardW + 24, toTip: rightX - 24)

    // Tone chips
    let chips = ["Fix Grammar", "Professional", "Friendly", "Concise"]
    let chipFont = NSFont.systemFont(ofSize: 18, weight: .medium)
    var widths: [CGFloat] = []
    for c in chips { widths.append((c as NSString).size(withAttributes: [.font: chipFont]).width + 40) }
    let gap: CGFloat = 16
    let totalW = widths.reduce(0, +) + gap * CGFloat(chips.count - 1)
    var x = (W - totalW) / 2
    let chipTop: CGFloat = 520
    for (i, c) in chips.enumerated() {
        let rect = r(chipTop, 46, x, widths[i])
        NSColor(srgbRed: 0.95, green: 0.95, blue: 0.97, alpha: 1).setFill()
        rounded(rect, 23).fill()
        draw(c, in: r(chipTop + 11, 24, x, widths[i]), font: chipFont, color: ink, align: .center)
        x += widths[i] + gap
    }

    draw("⌥⌘P preview   ·   ⌥⇧⌘P instant replace   ·   fully customizable shortcuts",
         in: r(620, 28, 0, W),
         font: .systemFont(ofSize: 19, weight: .regular), color: muted, align: .center)

    draw("textpolisher.app", in: r(712, 28, 0, W),
         font: .systemFont(ofSize: 18, weight: .medium), color: faint, align: .center)
}
