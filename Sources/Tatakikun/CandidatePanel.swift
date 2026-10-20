import AppKit
import TatakikunCore

/// A floating, non-activating panel under the text: a horizontal bar of candidates that expands
/// downward into more rows, which scroll when there are more than fit.
final class CandidatePanel: NSPanel {
    private let background = NSVisualEffectView()
    let content = PanelContentView()

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
        background.addSubview(content)
        contentView = background
    }

    /// Shows the composer's candidates below `cursor` (a rectangle in screen coordinates);
    /// `onChoose` is called with the row and column of a clicked candidate.
    func show(_ composer: Composer, below cursor: NSRect, onChoose: @escaping (Int, Int) -> Void) {
        guard composer.isComposing else { hide(); return }
        let screen = NSScreen.screens.first { $0.frame.intersects(cursor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 10_000, height: 10_000)
        content.update(composer, maxWidth: visible.width - 20)
        content.candidates.onChoose = onChoose
        let size = content.frame.size
        background.frame = NSRect(origin: .zero, size: size)
        var origin = NSPoint(x: cursor.minX, y: cursor.minY - size.height - 4)
        if origin.y < visible.minY { origin.y = cursor.maxY + 4 }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        setFrame(NSRect(origin: origin, size: size), display: true)
        content.scrollToSelection()
        orderFrontRegardless()
    }

    func hide() { orderOut(nil) }
}

/// The input as typed (with a hint when more candidates are available) above the candidate rows.
final class PanelContentView: NSView {
    let candidates = CandidateView()
    private let scroll = NSScrollView()
    private var header = ""
    private var hint = ""

    static let headerHeight: CGFloat = 20
    static let maxVisibleRows = 6

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        scroll.documentView = candidates
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        addSubview(scroll)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(_ composer: Composer, maxWidth: CGFloat = 1000) {
        header = composer.input
        hint = composer.isExpanded ? "↑ 收起  Esc" : (composer.canExpand ? "↓ 更多" : "")
        candidates.update(composer)
        let rows = composer.visibleRows.count
        let visibleHeight = CGFloat(min(max(rows, 1), Self.maxVisibleRows)) * CandidateView.rowHeight + 4
        let headerWidth = CandidateView.width(header + "    " + hint, CandidateView.smallFont) + 2 * CandidateView.padding
        let width = min(max(candidates.frame.width, headerWidth, 160), maxWidth)
        setFrameSize(NSSize(width: width, height: Self.headerHeight + visibleHeight))
        scroll.frame = NSRect(x: 0, y: Self.headerHeight, width: width, height: visibleHeight)
        candidates.setFrameSize(NSSize(width: width, height: max(candidates.frame.height, visibleHeight)))
        needsDisplay = true
    }

    func scrollToSelection() {
        if let rect = candidates.selectedRect { candidates.scrollToVisible(rect.insetBy(dx: 0, dy: -2)) }
        else { candidates.scroll(.zero) }
    }

    override func draw(_ dirtyRect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [.font: CandidateView.smallFont, .foregroundColor: NSColor.secondaryLabelColor]
        (header as NSString).draw(at: NSPoint(x: CandidateView.padding, y: 4), withAttributes: attrs)
        let hintWidth = CandidateView.width(hint, CandidateView.smallFont)
        (hint as NSString).draw(at: NSPoint(x: bounds.width - hintWidth - CandidateView.padding, y: 4), withAttributes: attrs)
    }
}

/// Draws the candidate rows: "1 你好 中  2 にはお あ  …". The row holding the selection is numbered
/// 1–9 (the digit keys pick from it) and the selected candidate is highlighted.
final class CandidateView: NSView {
    private struct Cell { let rect: NSRect; let row: Int; let column: Int; let text: String; let tag: String; let partial: Bool }
    private var cells: [Cell] = []
    private var selectedRow = 0
    private var selectedColumn = 0
    var onChoose: ((Int, Int) -> Void)?

    static let textFont = NSFont.systemFont(ofSize: 17)
    static let smallFont = NSFont.systemFont(ofSize: 10)
    static let padding: CGFloat = 8
    static let rowHeight: CGFloat = 30

    override var isFlipped: Bool { true }

    static func width(_ s: String, _ font: NSFont) -> CGFloat { ceil((s as NSString).size(withAttributes: [.font: font]).width) }

    var selectedRect: NSRect? { cells.first { $0.row == selectedRow && $0.column == selectedColumn }?.rect }

    func update(_ composer: Composer) {
        selectedRow = composer.selectedRow
        selectedColumn = composer.selectedColumn
        cells = []
        var maxX: CGFloat = 0
        for (r, row) in composer.visibleRows.enumerated() {
            var x = Self.padding
            let y = CGFloat(r) * Self.rowHeight + 2
            for (c, cand) in row.enumerated() {
                let w = Self.width("9", Self.smallFont) + 4 + Self.width(cand.text, Self.textFont) + 3
                    + Self.width(cand.kind.tag, Self.smallFont) + 14
                cells.append(Cell(rect: NSRect(x: x, y: y, width: w, height: Self.rowHeight), row: r, column: c,
                                  text: cand.text, tag: cand.kind.tag, partial: !cand.isExact))
                x += w
            }
            maxX = max(maxX, x)
        }
        let rows = composer.visibleRows.count
        setFrameSize(NSSize(width: maxX + Self.padding, height: CGFloat(rows) * Self.rowHeight + 4))
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let cell = cells.first(where: { $0.rect.contains(p) }) { onChoose?(cell.row, cell.column) }
    }

    override func draw(_ dirtyRect: NSRect) {
        let secondary: [NSAttributedString.Key: Any] = [.font: Self.smallFont, .foregroundColor: NSColor.secondaryLabelColor]
        let tag: [NSAttributedString.Key: Any] = [.font: Self.smallFont, .foregroundColor: NSColor.tertiaryLabelColor]
        for cell in cells where cell.rect.intersects(dirtyRect) {
            if cell.row == selectedRow && cell.column == selectedColumn {
                NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
                NSBezierPath(roundedRect: cell.rect.insetBy(dx: 2, dy: 1), xRadius: 5, yRadius: 5).fill()
            }
            var x = cell.rect.minX + 6
            let mid = cell.rect.midY
            let number = cell.row == selectedRow ? "\(cell.column + 1)" : ""
            let numberSize = ("9" as NSString).size(withAttributes: secondary)
            (number as NSString).draw(at: NSPoint(x: x, y: mid - numberSize.height / 2), withAttributes: secondary)
            x += numberSize.width + 4
            let color: NSColor = cell.partial ? .secondaryLabelColor : .labelColor
            let main: [NSAttributedString.Key: Any] = [.font: Self.textFont, .foregroundColor: color]
            let textSize = (cell.text as NSString).size(withAttributes: main)
            (cell.text as NSString).draw(at: NSPoint(x: x, y: mid - textSize.height / 2), withAttributes: main)
            x += textSize.width + 3
            (cell.tag as NSString).draw(at: NSPoint(x: x, y: mid - 2), withAttributes: tag)
        }
    }
}

extension PanelContentView {
    /// Renders the panel for `composer` into a PNG file (for checking the layout without a screen).
    static func snapshot(_ composer: Composer, to url: URL, appearance: NSAppearance.Name = .aqua) throws {
        let view = PanelContentView()
        view.appearance = NSAppearance(named: appearance)
        view.update(composer)
        view.scrollToSelection()
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
