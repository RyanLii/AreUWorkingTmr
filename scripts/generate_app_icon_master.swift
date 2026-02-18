import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "artifacts/icon-build/icon-master-1024.png"

let width = 1024
let height = 1024

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create CGContext")
}

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

func cg(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a).cgColor
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawSparkle(center: CGPoint, size: CGFloat, alpha: CGFloat) {
    ctx.setStrokeColor(cg(1, 1, 1, alpha))
    ctx.setLineWidth(8)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: center.x, y: center.y + size))
    ctx.addLine(to: CGPoint(x: center.x, y: center.y - size))
    ctx.move(to: CGPoint(x: center.x - size, y: center.y))
    ctx.addLine(to: CGPoint(x: center.x + size, y: center.y))
    ctx.strokePath()
}

let bgGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [cg(0.08, 0.08, 0.10), cg(0.14, 0.12, 0.15), cg(0.22, 0.18, 0.14)] as CFArray,
    locations: [0.0, 0.58, 1.0]
)!
ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

ctx.setFillColor(cg(1.0, 0.74, 0.46, 0.24))
ctx.fillEllipse(in: CGRect(x: 560, y: 560, width: 500, height: 500))

ctx.setFillColor(cg(0.52, 0.75, 0.70, 0.18))
ctx.fillEllipse(in: CGRect(x: -70, y: 70, width: 430, height: 430))

let panelRect = CGRect(x: 210, y: 210, width: 604, height: 604)
ctx.addPath(roundedRect(panelRect, 176))
ctx.setFillColor(cg(0.01, 0.03, 0.06, 0.36))
ctx.fillPath()

ctx.addPath(roundedRect(panelRect, 176))
ctx.setStrokeColor(cg(1, 1, 1, 0.22))
ctx.setLineWidth(18)
ctx.strokePath()

let mugRect = CGRect(x: 270, y: 230, width: 420, height: 520)
ctx.addPath(roundedRect(mugRect, 110))
ctx.setFillColor(cg(0.04, 0.05, 0.07, 0.62))
ctx.fillPath()

ctx.addPath(roundedRect(mugRect, 110))
ctx.setStrokeColor(cg(1, 1, 1, 0.30))
ctx.setLineWidth(16)
ctx.strokePath()

ctx.addArc(
    center: CGPoint(x: 730, y: 490),
    radius: 130,
    startAngle: CGFloat.pi * 0.42,
    endAngle: CGFloat.pi * 1.64,
    clockwise: false
)
ctx.setStrokeColor(cg(1, 1, 1, 0.30))
ctx.setLineWidth(32)
ctx.setLineCap(.round)
ctx.strokePath()

let liquidRect = CGRect(x: 300, y: 250, width: 360, height: 360)
ctx.saveGState()
ctx.addPath(roundedRect(liquidRect, 68))
ctx.clip()
let beerGradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [cg(1.00, 0.82, 0.44, 0.97), cg(0.96, 0.60, 0.31, 0.95)] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(
    beerGradient,
    start: CGPoint(x: 0, y: liquidRect.maxY),
    end: CGPoint(x: 0, y: liquidRect.minY),
    options: []
)
ctx.restoreGState()

let foamBubbles: [(CGFloat, CGFloat, CGFloat)] = [
    (325, 620, 44),
    (385, 638, 48),
    (455, 642, 54),
    (528, 636, 48),
    (595, 620, 44)
]
ctx.setFillColor(cg(1, 1, 1, 0.90))
for (x, y, r) in foamBubbles {
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

ctx.setFillColor(cg(1, 1, 1, 0.22))
ctx.fillEllipse(in: CGRect(x: 350, y: 470, width: 70, height: 52))

drawSparkle(center: CGPoint(x: 250, y: 760), size: 30, alpha: 0.58)
drawSparkle(center: CGPoint(x: 770, y: 310), size: 24, alpha: 0.50)

guard let cgImage = ctx.makeImage() else {
    fatalError("Failed to make CGImage")
}

let rep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to encode PNG")
}

let outURL = URL(fileURLWithPath: outPath)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try pngData.write(to: outURL)
print("Wrote \(outPath)")
