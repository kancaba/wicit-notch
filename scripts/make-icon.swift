// Renders the Wicit app icon: a dark squircle with the signature notch-shelf
// hanging from the top edge (concave corners) in a violet→blue gradient, and
// mini equalizer bars inside. Outputs build/icon_1024.png.
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background squircle (Apple icon grid: ~100px margin, ~22.4% corner radius).
let margin: CGFloat = 100
let bgRect = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
let bgRadius = bgRect.width * 0.2237
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: bgRadius, yRadius: bgRadius)
NSGradient(
    starting: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.19, alpha: 1),
    ending: NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.05, alpha: 1)
)!.draw(in: bgPath, angle: -90)

// Everything after this stays inside the squircle (keeps the glow contained).
NSGraphicsContext.current?.saveGraphicsState()
bgPath.setClip()

// Notch-shelf shape hanging from the top (concave top corners, convex bottom).
let shelfWidth: CGFloat = 520
let shelfHeight: CGFloat = 300
let tr: CGFloat = 58   // concave top fillet
let br: CGFloat = 92   // convex bottom corner
let minX = (size - shelfWidth) / 2
let maxX = minX + shelfWidth
let yTop = bgRect.maxY
let yBottom = yTop - shelfHeight

let shelf = NSBezierPath()
shelf.move(to: NSPoint(x: minX, y: yTop))
shelf.curve(to: NSPoint(x: minX + tr, y: yTop - tr),
            controlPoint1: NSPoint(x: minX + tr, y: yTop),
            controlPoint2: NSPoint(x: minX + tr, y: yTop))
shelf.line(to: NSPoint(x: minX + tr, y: yBottom + br))
shelf.curve(to: NSPoint(x: minX + tr + br, y: yBottom),
            controlPoint1: NSPoint(x: minX + tr, y: yBottom),
            controlPoint2: NSPoint(x: minX + tr, y: yBottom))
shelf.line(to: NSPoint(x: maxX - tr - br, y: yBottom))
shelf.curve(to: NSPoint(x: maxX - tr, y: yBottom + br),
            controlPoint1: NSPoint(x: maxX - tr, y: yBottom),
            controlPoint2: NSPoint(x: maxX - tr, y: yBottom))
shelf.line(to: NSPoint(x: maxX - tr, y: yTop - tr))
shelf.curve(to: NSPoint(x: maxX, y: yTop),
            controlPoint1: NSPoint(x: maxX - tr, y: yTop),
            controlPoint2: NSPoint(x: maxX - tr, y: yTop))
shelf.close()

// Soft glow behind the shelf.
NSGraphicsContext.current?.saveGraphicsState()
let glow = NSShadow()
glow.shadowColor = NSColor(calibratedRed: 0.45, green: 0.35, blue: 1, alpha: 0.55)
glow.shadowBlurRadius = 60
glow.shadowOffset = .zero
glow.set()
NSColor.black.setFill()
shelf.fill()
NSGraphicsContext.current?.restoreGraphicsState()

NSGradient(
    starting: NSColor(calibratedRed: 0.55, green: 0.36, blue: 0.97, alpha: 1),
    ending: NSColor(calibratedRed: 0.23, green: 0.51, blue: 0.96, alpha: 1)
)!.draw(in: shelf, angle: -90)

// Mini equalizer bars inside the shelf.
let barHeights: [CGFloat] = [74, 118, 88]
let barWidth: CGFloat = 30
let barSpacing: CGFloat = 34
let totalBars = barWidth * 3 + barSpacing * 2
var barX = (size - totalBars) / 2
let barBase = yBottom + 74
NSColor(calibratedWhite: 1, alpha: 0.95).setFill()
for height in barHeights {
    let bar = NSBezierPath(
        roundedRect: NSRect(x: barX, y: barBase, width: barWidth, height: height),
        xRadius: barWidth / 2, yRadius: barWidth / 2
    )
    bar.fill()
    barX += barWidth + barSpacing
}

NSGraphicsContext.current?.restoreGraphicsState()

image.unlockFocus()

// Write PNG.
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encoding failed")
}
let output = URL(fileURLWithPath: "build/icon_1024.png")
try? FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)
try! png.write(to: output)
print("wrote \(output.path)")
