import AppKit
import TatakikunCore

/// A floating, non-activating panel that shows candidates in a horizontal row under the text.
final class CandidatePanel: NSPanel {
    private let candidateView = CandidateView()
    private let background = NSVisualEffectView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
        background.layer?.masksToBounds = true
        background.addSubview(candidateView)
        contentView = background
    }

    /// Shows the composer's candidates below `cursor` (a rectangle in screen coordinates).
    func show(_ composer: Composer, below cursor: NSRect) {
        guard composer.isComposing else { hide(); return }
        candidateView.update(composer)
        let size = candidateView.frame.size
        background.frame = NSRect(origin: .zero, size: size)
        candidateView.frame.origin = .zero
        let screen = NSScreen.screens.first { $0.frame.intersects(cursor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 10_000, height: 10_000)
        var origin = NSPoint(x: cursor.minX, y: cursor.minY - size.height - 4)
        if origin.y < visible.minY { origin.y = cursor.maxY + 4 }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        setFrame(NSRect(origin: origin, size: size), display: true)
        orderFrontRegardless()
    }

    func hide() { orderOut(nil) }
}

/// Draws the first row: "1 你好 中  2 にはお あ  …", with the selected candidate highlighted.
final class CandidateView: NSView {
    private var cells: [(rect: NSRect, number: String, text: String, tag: String, selected: Bool)] = []
    private var inputText = ""

    static let textFont = NSFont.systemFont(ofSize: 17)
    static let smallFont = NSFont.systemFont(ofSize: 10)
    static let padding: CGFloat = 8
    static let rowHeight: CGFloat = 30
    static let inputHeight: CGFloat = 18

    override var isFlipped: Bool { true }

    func update(_ composer: Composer) {
        inputText = composer.input
        cells = []
        var x = Self.padding
        let y = Self.inputHeight + 2
        for (i, c) in composer.list.firstRow.enumerated() {
            let number = "\(i + 1)"
            let w = width(number, Self.smallFont) + 4 + width(c.text, Self.textFont) + 3 + width(c.kind.tag, Self.smallFont) + 14
            cells.append((NSRect(x: x, y: y, width: w, height: Self.rowHeight), number, c.text, c.kind.tag, i == composer.selection))
            x += w
        }
        let inputWidth = width(inputText, Self.smallFont) + 2 * Self.padding
        setFrameSize(NSSize(width: max(x + Self.padding, inputWidth, 120), height: y + Self.rowHeight + 6))
        needsDisplay = true
    }

    private func width(_ s: String, _ font: NSFont) -> CGFloat { ceil((s as NSString).size(withAttributes: [.font: font]).width) }

    override func draw(_ dirtyRect: NSRect) {
        let secondary: [NSAttributedString.Key: Any] = [.font: Self.smallFont, .foregroundColor: NSColor.secondaryLabelColor]
        (inputText as NSString).draw(at: NSPoint(x: Self.padding, y: 4), withAttributes: secondary)
        for cell in cells {
            if cell.selected {
                NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
                NSBezierPath(roundedRect: cell.rect.insetBy(dx: 2, dy: 1), xRadius: 5, yRadius: 5).fill()
            }
            var x = cell.rect.minX + 6
            let mid = cell.rect.midY
            let numberSize = (cell.number as NSString).size(withAttributes: secondary)
            (cell.number as NSString).draw(at: NSPoint(x: x, y: mid - numberSize.height / 2), withAttributes: secondary)
            x += numberSize.width + 4
            let main: [NSAttributedString.Key: Any] = [.font: Self.textFont, .foregroundColor: NSColor.labelColor]
            let textSize = (cell.text as NSString).size(withAttributes: main)
            (cell.text as NSString).draw(at: NSPoint(x: x, y: mid - textSize.height / 2), withAttributes: main)
            x += textSize.width + 3
            let tag: [NSAttributedString.Key: Any] = [.font: Self.smallFont, .foregroundColor: NSColor.tertiaryLabelColor]
            (cell.tag as NSString).draw(at: NSPoint(x: x, y: mid - 2), withAttributes: tag)
        }
    }
}

extension CandidateView {
    /// Renders the candidate view for `composer` into a PNG file (for checking the layout without a screen).
    static func snapshot(_ composer: Composer, to url: URL, appearance: NSAppearance.Name = .aqua) throws {
        let view = CandidateView()
        view.appearance = NSAppearance(named: appearance)
        view.update(composer)
        let box = NSView(frame: view.frame)
        box.appearance = view.appearance
        box.wantsLayer = true
        box.layer?.backgroundColor = (appearance == .darkAqua ? NSColor(white: 0.18, alpha: 1) : NSColor(white: 0.96, alpha: 1)).cgColor
        box.addSubview(view)
        let rep = box.bitmapImageRepForCachingDisplay(in: box.bounds)!
        box.cacheDisplay(in: box.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }
}
