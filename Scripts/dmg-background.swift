import AppKit

// A Retina background in Tapas's native Gráfico palette. Finder supplies the
// actual app and Applications icons; their positions live in dmg-settings.py.
let width: CGFloat = 640, height: CGFloat = 400
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1280, pixelsHigh: 800,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: width, height: height)
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let paper = NSColor(srgbRed: 0.953, green: 0.937, blue: 0.875, alpha: 1)
let ink = NSColor(srgbRed: 0.188, green: 0.231, blue: 0.169, alpha: 1)
let muted = NSColor(srgbRed: 0.37, green: 0.42, blue: 0.29, alpha: 1)
let saffron = NSColor(srgbRed: 0.941, green: 0.780, blue: 0.251, alpha: 1)
paper.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
func text(_ string: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (string as NSString).draw(in: NSRect(x: 24, y: height - top - size * 1.5, width: width - 48, height: size * 1.5),
        withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph])
}
text("Tapas", top: 38, size: 38, weight: .semibold, color: ink)
text("Small tools. Good company.", top: 91, size: 14, weight: .regular, color: muted)
// Arrow between the draggable Finder icons, whose centers are at y = 215.
saffron.setFill()
NSBezierPath(ovalIn: NSRect(x: 291, y: height - 244, width: 58, height: 58)).fill()
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 306, y: height - 215))
arrow.line(to: NSPoint(x: 334, y: height - 215))
arrow.move(to: NSPoint(x: 325, y: height - 206))
arrow.line(to: NSPoint(x: 334, y: height - 215))
arrow.line(to: NSPoint(x: 325, y: height - 224))
arrow.lineWidth = 2.5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
ink.setStroke()
arrow.stroke()
text("Drag Tapas into Applications to install.", top: 322, size: 15, weight: .medium, color: ink)
NSGraphicsContext.restoreGraphicsState()
try bitmap.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
