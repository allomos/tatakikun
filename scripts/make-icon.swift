// Draws the menu bar icon: a filled rounded square with "た" cut out, like the system's own input
// source badges (A, あ, 拼). Info.plist marks it as a template (TISIconIsTemplate), so macOS
// recolors it: gray in lists, white on the blue selection, light in dark menu bars. It must be
// filled: a thin outline turns faint gray as a template and all but disappears.
// 16pt with 1x and 2x representations. Usage: swift make-icon.swift <out.tiff>
import AppKit
func rep(scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 16 * scale, pixelsHigh: 16 * scale, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 16, height: 16)
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    NSColor.black.setFill()
    NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 14, height: 14), xRadius: 3, yRadius: 3).fill()
    context.compositingOperation = .destinationOut
    let text = "た" as NSString
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.black]
    let ts = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: (16 - ts.width) / 2, y: (16 - ts.height) / 2), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
let tiff = NSBitmapImageRep.tiffRepresentationOfImageReps(in: [rep(scale: 1), rep(scale: 2)], using: .none, factor: 0)!
try! tiff.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
