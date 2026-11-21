import AppKit
import CoreGraphics
import Foundation

// Renders GraviHUD's macOS AppIcon.iconset PNGs using pure CoreGraphics (zero dependencies).
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: outDir)
try! fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // macOS icon padding (~7% margin around squircle)
    let pad = s * 0.075
    let bodyRect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let bodyRadius = bodyRect.width * 0.225
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil)

    // Subtle drop shadow under squircle
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.015), blur: s * 0.04, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(CGColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Background slate gradient
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let bgColors = [
        CGColor(red: 0.055, green: 0.090, blue: 0.165, alpha: 1.0), // #0E172A
        CGColor(red: 0.118, green: 0.161, blue: 0.231, alpha: 1.0), // #1E293B
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: bodyRect.minX, y: bodyRect.maxY),
        end: CGPoint(x: bodyRect.maxX, y: bodyRect.minY),
        options: []
    )

    // Soft top-left ambient glow
    let glowColors = [
        CGColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 0.20),
        CGColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 0.0),
    ] as CFArray
    let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(
        glowGrad,
        startCenter: CGPoint(x: bodyRect.minX + bodyRect.width * 0.25, y: bodyRect.maxY - bodyRect.height * 0.2),
        startRadius: 0,
        endCenter: CGPoint(x: bodyRect.minX + bodyRect.width * 0.25, y: bodyRect.maxY - bodyRect.height * 0.2),
        endRadius: bodyRect.width * 0.7,
        options: []
    )
    ctx.restoreGState()

    // Outer subtle metallic border
    ctx.addPath(bodyPath)
    ctx.setStrokeColor(CGColor(red: 0.35, green: 0.45, blue: 0.58, alpha: 0.45))
    ctx.setLineWidth(max(1.0, s * 0.015))
    ctx.strokePath()

    // Inner glass HUD card
    let innerPad = s * 0.195
    let cardRect = CGRect(x: innerPad, y: innerPad, width: s - innerPad * 2, height: s - innerPad * 2)
    let cardRadius = cardRect.width * 0.22
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
    ctx.addPath(cardPath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.065))
    ctx.fillPath()
    ctx.addPath(cardPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.setLineWidth(max(1.0, s * 0.011))
    ctx.strokePath()

    // Live green indicator dot (top-left inside HUD card)
    let dotR = s * 0.036
    let dotCx = cardRect.minX + cardRect.width * 0.18
    let dotCy = cardRect.maxY - cardRect.height * 0.18
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.03, color: CGColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 0.85))
    ctx.setFillColor(CGColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1.0)) // #22C55E
    ctx.fillEllipse(in: CGRect(x: dotCx - dotR, y: dotCy - dotR, width: dotR * 2, height: dotR * 2))
    ctx.restoreGState()

    // Header pill bar next to dot
    let hdrH = s * 0.044
    let hdrRect = CGRect(
        x: dotCx + dotR + s * 0.042,
        y: dotCy - hdrH / 2,
        width: cardRect.width * 0.46,
        height: hdrH
    )
    let hdrPath = CGPath(roundedRect: hdrRect, cornerWidth: hdrH / 2, cornerHeight: hdrH / 2, transform: nil)
    ctx.addPath(hdrPath)
    ctx.setFillColor(CGColor(red: 0.58, green: 0.64, blue: 0.72, alpha: 0.45))
    ctx.fillPath()

    // Three token composition bars (Blue = Input, Emerald = Cache, Violet = Output)
    let bars: [(xFrac: CGFloat, hFrac: CGFloat, top: [CGFloat], bot: [CGFloat])] = [
        (0.14, 0.34, [0.376, 0.647, 0.980, 1.0], [0.145, 0.388, 0.922, 1.0]), // Blue
        (0.41, 0.54, [0.204, 0.827, 0.600, 1.0], [0.020, 0.588, 0.412, 1.0]), // Emerald
        (0.68, 0.43, [0.655, 0.545, 0.980, 1.0], [0.486, 0.227, 0.929, 1.0]), // Violet
    ]

    let barW = cardRect.width * 0.18
    let baseY = cardRect.minY + cardRect.height * 0.14

    for b in bars {
        let barH = cardRect.height * b.hFrac
        let rect = CGRect(x: cardRect.minX + cardRect.width * b.xFrac, y: baseY, width: barW, height: barH)
        let r = min(barW * 0.36, barH * 0.36)
        let p = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)

        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        let cols = [
            CGColor(red: b.top[0], green: b.top[1], blue: b.top[2], alpha: b.top[3]),
            CGColor(red: b.bot[0], green: b.bot[1], blue: b.bot[2], alpha: b.bot[3]),
        ] as CFArray
        let g = CGGradient(colorsSpace: colorSpace, colors: cols, locations: [0.0, 1.0])!
        ctx.drawLinearGradient(
            g,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            options: []
        )
        ctx.restoreGState()
    }

    let cgImg = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: cgImg)
    return rep.representation(using: .png, properties: [:])!
}

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in specs {
    let data = drawIcon(size: px)
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("Generated iconset in \(outDir)")
