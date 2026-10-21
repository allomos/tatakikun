import AppKit
import InputMethodKit
import TatakikunCore

/// Maps a key event to the composer's keys; nil for events the input method leaves alone.
func composerKey(for event: NSEvent) -> Key? {
    guard event.type == .keyDown else { return nil }
    if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return nil }
    switch event.keyCode {
    case 51: return .backspace
    case 53: return .escape
    case 49: return .space
    case 36, 76: return .enter
    case 48: return .tab
    case 123: return .left
    case 124: return .right
    case 125: return .down
    case 126: return .up
    default: break
    }
    guard let c = event.characters?.first else { return nil }
    if c.isASCII, c.isLetter { return .letter(c) }
    if let n = c.wholeNumberValue, c.isASCII { return .digit(n) }
    if c.isPunctuation || c.isSymbol || c.isNumber { return .other(c) }
    return nil
}

/// One controller per client text field; InputMethodKit creates it by this Objective-C name.
@objc(TatakikunInputController)
final class InputController: IMKInputController {
    private lazy var composer = Composer(engine: TatakikunApp.engine)

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? (IMKTextInput & NSObjectProtocol), let key = composerKey(for: event) else {
            if composer.isComposing, let client = sender as? (IMKTextInput & NSObjectProtocol), event?.type == .keyDown {
                // A shortcut (⌘, ⌃, ⌥) while composing: insert what is typed first.
                if let text = composer.finish() { client.insertText(text, replacementRange: Self.noRange) }
                refresh(client)
            }
            return false
        }
        composer.textBeforeCursor = { [weak client] in client.flatMap(Self.textBeforeCursor) }
        let update = composer.handle(key)
        if let text = update.commit { client.insertText(text, replacementRange: Self.replacing(update.deleteBefore, in: client)) }
        refresh(client)
        return update.handled
    }

    /// The last few characters before the cursor; nil when the application does not tell.
    static func textBeforeCursor(_ client: IMKTextInput & NSObjectProtocol) -> String? {
        let selection = client.selectedRange()
        guard selection.location != NSNotFound else { return nil }
        guard selection.location > 0 else { return "" }
        let length = min(selection.location, 4)
        return client.attributedSubstring(from: NSRange(location: selection.location - length, length: length))?.string
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? (IMKTextInput & NSObjectProtocol) else { return }
        if let text = composer.finish() { client.insertText(text, replacementRange: Self.noRange) }
        refresh(client)
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        TatakikunApp.panel.hide()
        // Another text field or app: what was typed here says nothing about the next word there.
        TatakikunApp.engine.forgetRecent()
        super.deactivateServer(sender)
    }

    static let noRange = NSRange(location: NSNotFound, length: NSNotFound)

    /// The range of the `count` characters before the cursor, to replace with the inserted text.
    static func replacing(_ count: Int, in client: IMKTextInput & NSObjectProtocol) -> NSRange {
        let selection = client.selectedRange()
        guard count > 0, selection.location != NSNotFound, selection.location >= count else { return noRange }
        return NSRange(location: selection.location - count, length: count + selection.length)
    }

    /// Shows the typed letters underlined in the document and the candidates under them.
    private func refresh(_ client: IMKTextInput & NSObjectProtocol) {
        guard composer.isComposing else {
            client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: Self.noRange)
            TatakikunApp.panel.hide()
            return
        }
        let marked = NSAttributedString(string: composer.input, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ])
        client.setMarkedText(marked, selectionRange: NSRange(location: composer.input.utf16.count, length: 0),
                             replacementRange: Self.noRange)
        var cursor = NSRect.zero
        client.attributes(forCharacterIndex: 0, lineHeightRectangle: &cursor)
        TatakikunApp.panel.show(composer, below: cursor) { [weak self, weak client] row, column in
            guard let self, let client else { return }
            let update = self.composer.choose(row: row, column: column)
            if let text = update.commit { client.insertText(text, replacementRange: Self.noRange) }
            self.refresh(client)
        }
    }
}
