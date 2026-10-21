import AppKit
import TatakikunCore

/// `Tatakikun --demo`: a text window that types through the composer, without registering the input method.
final class DemoWindow: NSWindow {
    init() {
        super.init(contentRect: NSRect(x: 200, y: 400, width: 640, height: 240),
                   styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        title = "Tatakikun Demo"
        let scroll = NSTextView.scrollableTextView()
        let text = scroll.documentView as! NSTextView
        let demo = DemoTextView(frame: text.frame)
        demo.autoresizingMask = text.autoresizingMask
        demo.font = .systemFont(ofSize: 20)
        demo.isRichText = false
        scroll.documentView = demo
        contentView = scroll
        makeFirstResponder(demo)
        isReleasedWhenClosed = false
    }
}

final class DemoTextView: NSTextView {
    private lazy var composer: Composer = {
        let composer = Composer(engine: TatakikunApp.engine)
        composer.textBeforeCursor = { [weak self] in
            guard let self, let text = self.textStorage?.string as NSString? else { return nil }
            return text.substring(to: min(self.selectedRange().location, text.length))
        }
        return composer
    }()

    override func keyDown(with event: NSEvent) {
        guard let key = composerKey(for: event) else {
            if let text = composer.finish() { insertText(text, replacementRange: selectedRange()) }
            refresh()
            super.keyDown(with: event)
            return
        }
        let update = composer.handle(key)
        if let text = update.commit {
            var range = markedRangeOrSelection()
            if update.deleteBefore > 0, range.location >= update.deleteBefore {
                range = NSRange(location: range.location - update.deleteBefore, length: range.length + update.deleteBefore)
            }
            insertText(text, replacementRange: range)
        }
        refresh()
        if !update.handled { super.keyDown(with: event) }
    }

    private func markedRangeOrSelection() -> NSRange { hasMarkedText() ? markedRange() : selectedRange() }

    private func refresh() {
        if composer.isComposing {
            let marked = NSAttributedString(string: composer.input, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
            setMarkedText(marked, selectedRange: NSRange(location: composer.input.utf16.count, length: 0),
                          replacementRange: markedRangeOrSelection())
            let start = markedRange().location
            let cursor = firstRect(forCharacterRange: NSRange(location: start, length: 0), actualRange: nil)
            TatakikunApp.panel.show(composer, below: cursor) { [weak self] row, column in
                guard let self else { return }
                let update = self.composer.choose(row: row, column: column)
                if let text = update.commit { self.insertText(text, replacementRange: self.markedRangeOrSelection()) }
                self.refresh()
            }
        } else {
            unmarkText()
            TatakikunApp.panel.hide()
        }
    }
}
