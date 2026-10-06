// Draws the app icon and saves it as a 1024 px PNG. Usage: swift make_icon.swift out.png
import AppKit

let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()

let base = NSBezierPath(roundedRect: NSRect(x: 90, y: 90, width: 844, height: 844), xRadius: 190, yRadius: 190)
NSGradient(starting: NSColor(srgbRed: 0.15, green: 0.47, blue: 0.75, alpha: 1),
           ending: NSColor(srgbRed: 0.07, green: 0.27, blue: 0.55, alpha: 1))!.draw(in: base, angle: -90)

let body = NSBezierPath(roundedRect: NSRect(x: 230, y: 364, width: 564, height: 280), xRadius: 56, yRadius: 56)
NSColor(srgbRed: 0.94, green: 0.96, blue: 0.97, alpha: 1).setFill()
body.fill()
NSGraphicsContext.saveGraphicsState()
body.addClip()
NSColor(srgbRed: 0.80, green: 0.84, blue: 0.88, alpha: 1).setFill()
NSRect(x: 230, y: 364, width: 564, height: 100).fill()
NSGraphicsContext.restoreGraphicsState()

NSColor(srgbRed: 0.24, green: 0.78, blue: 0.47, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 660, y: 392, width: 40, height: 40)).fill()

NSColor(srgbRed: 0.84, green: 0.87, blue: 0.90, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 290, y: 524, width: 444, height: 60), xRadius: 30, yRadius: 30).fill()
NSColor(srgbRed: 0.94, green: 0.63, blue: 0.16, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 290, y: 524, width: 270, height: 60), xRadius: 30, yRadius: 30).fill()

func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ s: CGFloat, _ color: NSColor) {
    let unit: [(CGFloat, CGFloat)] = [(0, 1), (0.25, 0.25), (1, 0), (0.25, -0.25), (0, -1), (-0.25, -0.25), (-1, 0), (-0.25, 0.25)]
    let path = NSBezierPath()
    for (i, u) in unit.enumerated() {
        let point = NSPoint(x: cx + u.0 * s, y: cy + u.1 * s)
        if i == 0 { path.move(to: point) } else { path.line(to: point) }
    }
    path.close()
    color.setFill()
    path.fill()
}
sparkle(760, 724, 80, .white)
sparkle(640, 774, 40, NSColor(srgbRed: 1, green: 0.90, blue: 0.67, alpha: 1))

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
