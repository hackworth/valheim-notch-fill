// Draws the app icon (a notched laptop screen filled edge to edge) and writes
// AppIcon.icns next to this file. Run: swift app/make-icon.swift
import AppKit

let here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let size = 1024.0

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(px) / size, y: CGFloat(px) / size)

    // Tile
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.20, blue: 0.27, alpha: 1),
               ending: NSColor(srgbRed: 0.06, green: 0.08, blue: 0.11, alpha: 1))!.draw(in: tile, angle: -90)

    // Laptop base
    NSColor(srgbRed: 0.62, green: 0.66, blue: 0.72, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 168, y: 280, width: 688, height: 30), xRadius: 15, yRadius: 15).fill()

    // Screen, filled right to the top edge
    let screen = NSRect(x: 214, y: 326, width: 596, height: 420)
    let screenPath = NSBezierPath(roundedRect: screen, xRadius: 28, yRadius: 28)
    NSGradient(colors: [NSColor(srgbRed: 0.10, green: 0.30, blue: 0.42, alpha: 1),
                        NSColor(srgbRed: 0.20, green: 0.78, blue: 0.56, alpha: 1),
                        NSColor(srgbRed: 0.45, green: 0.36, blue: 0.95, alpha: 1)])!.draw(in: screenPath, angle: 60)

    // Notch, hanging from the screen's top edge
    NSGraphicsContext.saveGraphicsState()
    screenPath.addClip()
    NSColor.black.setFill()
    NSBezierPath(roundedRect: NSRect(x: 452, y: 698, width: 120, height: 90), xRadius: 18, yRadius: 18).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", here.appendingPathComponent("AppIcon.icns").path]
try! p.run()
p.waitUntilExit()
print("Wrote", here.appendingPathComponent("AppIcon.icns").path)
