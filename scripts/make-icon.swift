// Draws the menu bar icon: a "た" in a rounded square. Usage: swift make-icon.swift <out.tiff>
import AppKit
let size = NSSize(width: 16, height: 16)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.black.setStroke()
let box = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 14, height: 14), xRadius: 3, yRadius: 3)
box.lineWidth = 1.2
box.stroke()
let text = "た" as NSString
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.black]
let ts = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: (16 - ts.width) / 2, y: (16 - ts.height) / 2), withAttributes: attrs)
NSGraphicsContext.restoreGraphicsState()
try! rep.tiffRepresentation!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
