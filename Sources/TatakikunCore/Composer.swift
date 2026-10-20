import Foundation

/// A key press, as the composer sees it.
public enum Key: Equatable {
    case letter(Character)
    case digit(Int)
    case backspace, escape, space, enter, left, right, up, down, tab
    /// Anything else that types a character (punctuation, symbols).
    case other(Character)
}

/// What the input method should do after a key press.
public struct ComposerUpdate: Equatable {
    /// Whether the key was used; when false the application handles it as usual.
    public var handled: Bool
    /// Text to insert into the document.
    public var commit: String?
}

/// The typing state machine behind the input method, independent of InputMethodKit.
///
/// Keys while composing: letters add to the input; Space inserts the selected candidate
/// (the first one unless moved with ←/→); Return inserts the letters as typed; 1–9 insert that
/// candidate of the row; Backspace removes a letter; Esc cancels. Another typed character inserts
/// the selected candidate and is then typed as usual.
public final class Composer {
    public let engine: Engine
    public private(set) var input = ""
    public private(set) var list = CandidateList(input: "", firstRow: [], more: [])
    /// Index into `list.all` of the highlighted candidate.
    public private(set) var selection = 0

    public init(engine: Engine) { self.engine = engine }

    public var isComposing: Bool { !input.isEmpty }
    public var selected: Candidate? { list.all.indices.contains(selection) ? list.all[selection] : nil }

    public func handle(_ key: Key) -> ComposerUpdate {
        if !isComposing {
            guard case .letter(let c) = key else { return ComposerUpdate(handled: false) }
            setInput(String(c))
            return ComposerUpdate(handled: true)
        }
        switch key {
        case .letter(let c):
            setInput(input + String(c))
        case .backspace:
            setInput(String(input.dropLast()))
        case .escape:
            reset()
        case .space:
            return commit(selected?.text ?? input)
        case .enter:
            return commit(input)
        case .digit(let n):
            guard n >= 1, n <= list.firstRow.count else { return ComposerUpdate(handled: true) }
            return commit(list.firstRow[n - 1].text)
        case .left:
            selection = max(0, selection - 1)
        case .right:
            selection = min(list.all.count - 1, selection + 1)
        case .up, .down, .tab:
            break
        case .other:
            // Insert the selected candidate, then let the application type the character.
            var update = commit(selected?.text ?? input)
            update.handled = false
            return update
        }
        return ComposerUpdate(handled: true)
    }

    /// Ends composition, inserting the selected candidate (used when the input method is switched away).
    public func finish() -> String? {
        guard isComposing else { return nil }
        let text = selected?.text ?? input
        reset()
        return text
    }

    public func reset() { setInput("") }

    private func setInput(_ s: String) {
        input = s
        list = engine.candidates(for: s)
        selection = 0
    }

    private func commit(_ text: String) -> ComposerUpdate {
        reset()
        return ComposerUpdate(handled: true, commit: text)
    }
}
