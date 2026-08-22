import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = Int(CommandLine.arguments[2]) ?? 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("Unable to create bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()
let inset = CGFloat(size) * 0.07
let tile = NSBezierPath(roundedRect: canvas.insetBy(dx: inset, dy: inset), xRadius: CGFloat(size) * 0.205, yRadius: CGFloat(size) * 0.205)
NSGradient(colors: [
    NSColor(calibratedRed: 0.18, green: 0.48, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.38, green: 0.24, blue: 0.88, alpha: 1)
])!.draw(in: tile, angle: -55)

let scale = CGFloat(size) / 1024
let document = NSBezierPath()
document.move(to: NSPoint(x: 310 * scale, y: 230 * scale))
document.line(to: NSPoint(x: 310 * scale, y: 794 * scale))
document.curve(to: NSPoint(x: 370 * scale, y: 854 * scale), controlPoint1: NSPoint(x: 310 * scale, y: 827 * scale), controlPoint2: NSPoint(x: 337 * scale, y: 854 * scale))
document.line(to: NSPoint(x: 590 * scale, y: 854 * scale))
document.line(to: NSPoint(x: 714 * scale, y: 730 * scale))
document.line(to: NSPoint(x: 714 * scale, y: 230 * scale))
document.close()
NSColor.white.setStroke()
document.lineWidth = 45 * scale
document.lineJoinStyle = .round
document.lineCapStyle = .round
document.stroke()

let fold = NSBezierPath()
fold.move(to: NSPoint(x: 590 * scale, y: 848 * scale))
fold.line(to: NSPoint(x: 590 * scale, y: 730 * scale))
fold.line(to: NSPoint(x: 708 * scale, y: 730 * scale))
fold.lineWidth = 34 * scale
fold.lineJoinStyle = .round
fold.stroke()

let plus = NSBezierPath()
plus.move(to: NSPoint(x: 512 * scale, y: 385 * scale))
plus.line(to: NSPoint(x: 512 * scale, y: 605 * scale))
plus.move(to: NSPoint(x: 402 * scale, y: 495 * scale))
plus.line(to: NSPoint(x: 622 * scale, y: 495 * scale))
plus.lineWidth = 52 * scale
plus.lineCapStyle = .round
plus.stroke()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Unable to encode PNG") }
try png.write(to: outputURL)
