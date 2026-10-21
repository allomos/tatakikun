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
    /// Characters before the cursor to remove before inserting `commit` (the space that followed
    /// an English word, when punctuation comes next).
    public var deleteBefore = 0

    public init(handled: Bool, commit: String? = nil, deleteBefore: Int = 0) {
        self.handled = handled
        self.commit = commit
        self.deleteBefore = deleteBefore
    }
}

/// The typing state machine behind the input method, independent of InputMethodKit.
///
/// Keys while composing: letters add to the input; Space inserts the selected candidate
/// (the first one unless moved), followed by a half-width space when it is English or the letters
/// as typed; Return inserts the letters as typed; 1–9 insert that candidate
/// of the selected row; ←/→ move the selection; ↓ or Tab expands the bar into more rows (and then
/// moves down a row), ↑ moves up a row and collapses from the first; Backspace removes a letter;
/// Esc collapses, or cancels when not expanded. Punctuation inserts the selected candidate and
/// then the punctuation, full-width after Chinese or Japanese candidates and as typed after
/// English ones. Choosing a candidate that covers only the start of the letters inserts it and
/// leaves the rest to go on typing.
///
/// Not composing, punctuation and Space follow the text before the cursor (`textBeforeCursor`,
/// or what was inserted last when the application does not tell): full-width after Chinese or
/// Japanese, otherwise left to the application. Punctuation that closes a word (`,.!?;:)]}`) typed
/// right after the space Space added to an English word takes that space's place (`hello,`).
public final class Composer {
    public let engine: Engine
    public private(set) var input = ""
    public private(set) var list = CandidateList(input: "", firstRow: [], more: [])
    /// The candidates in rows: the first row is the bar, the others are shown when expanded.
    public private(set) var rows: [[Candidate]] = []
    public private(set) var isExpanded = false
    /// Row and column of the highlighted candidate.
    public private(set) var selectedRow = 0
    public private(set) var selectedColumn = 0
    /// Candidates per row when expanded.
    public var columns = 9
    /// The text before the cursor in the document, when the application tells it.
    public var textBeforeCursor: (() -> String?)?
    /// The script of what was inserted last.
    public private(set) var lastScript = TextScript.latin
    private var punctuation = Punctuation()
    /// The result being built from several picks (nihaoma: 你好, then 吗): the letters it started
    /// from, the text inserted so far, how many picks, and whether one was not the first candidate.
    private var built: (input: String, text: String, picks: Int, byHand: Bool)?
    /// Whether the last key inserted an English word followed by a space of its own.
    private var spaceAdded = false
    static let closingPunctuation: Set<Character> = [",", ".", "!", "?", ";", ":", ")", "]", "}"]

    public init(engine: Engine) { self.engine = engine }

    public var isComposing: Bool { !input.isEmpty }
    public var selected: Candidate? {
        rows.indices.contains(selectedRow) && rows[selectedRow].indices.contains(selectedColumn)
            ? rows[selectedRow][selectedColumn] : nil
    }
    /// The rows to show: just the bar, or all of them when expanded.
    public var visibleRows: [[Candidate]] { isExpanded ? rows : Array(rows.prefix(1)) }
    public var canExpand: Bool { rows.count > 1 }

    public func handle(_ key: Key) -> ComposerUpdate {
        let afterAddedSpace = spaceAdded
        spaceAdded = false
        if !isComposing {
            switch key {
            case .letter(let c):
                setInput(String(c))
                return ComposerUpdate(handled: true)
            case .space:
                return typeAsScript(" ")
            case .other(let c):
                if afterAddedSpace, Self.closingPunctuation.contains(c), textBeforeCursor?()?.hasSuffix(" ") ?? true {
                    return ComposerUpdate(handled: true, commit: String(c), deleteBefore: 1)
                }
                return typeAsScript(c)
            default:
                return ComposerUpdate(handled: false)
            }
        }
        switch key {
        case .letter(let c):
            setInput(input + String(c))
        case .backspace:
            setInput(String(input.dropLast()))
        case .escape:
            if isExpanded { collapse() } else { reset() }
        case .space:
            return choose(selected, spaceAfter: true)
        case .enter:
            engine.history?.record(input: input, text: input)
            engine.noteInserted(.raw)
            return commit(input, script: .latin)
        case .digit(let n):
            let row = rows.indices.contains(selectedRow) ? rows[selectedRow] : []
            guard n >= 1, n <= row.count else { return ComposerUpdate(handled: true) }
            return choose(row[n - 1])
        case .left:
            if selectedColumn > 0 { selectedColumn -= 1 }
            else if isExpanded, selectedRow > 0 { selectedRow -= 1; selectedColumn = rows[selectedRow].count - 1 }
        case .right:
            if selectedColumn + 1 < rows[selectedRow].count { selectedColumn += 1 }
            else if isExpanded, selectedRow + 1 < rows.count { selectedRow += 1; selectedColumn = 0 }
        case .down, .tab:
            if !isExpanded { isExpanded = canExpand }
            else if selectedRow + 1 < rows.count {
                selectedRow += 1
                selectedColumn = min(selectedColumn, rows[selectedRow].count - 1)
            }
        case .up:
            if selectedRow > 0 {
                selectedRow -= 1
                selectedColumn = min(selectedColumn, rows[selectedRow].count - 1)
            } else if isExpanded { collapse() }
        case .other(let c):
            // Insert the selected candidate, then the punctuation in its script.
            let candidate = selected?.consumed == nil ? selected : nil
            let script = TextScript(candidate?.kind ?? .raw)
            engine.noteInserted(candidate?.kind ?? .raw)
            let text = (candidate?.text ?? input) + punctuation.convert(c, for: script)
            return commit(text, script: script)
        }
        return ComposerUpdate(handled: true)
    }

    /// Chooses a candidate by position (a click in the panel).
    public func choose(row: Int, column: Int) -> ComposerUpdate {
        guard rows.indices.contains(row), rows[row].indices.contains(column) else { return ComposerUpdate(handled: true) }
        return choose(rows[row][column])
    }

    /// Ends composition, inserting the selected candidate (used when the input method is switched away).
    public func finish() -> String? {
        guard isComposing else { return nil }
        let candidate = selected?.consumed == nil ? selected : nil
        lastScript = TextScript(candidate?.kind ?? .raw)
        engine.noteInserted(candidate?.kind ?? .raw)
        reset()
        return candidate?.text ?? input
    }

    public func reset() {
        built = nil
        setInput("")
    }

    private func collapse() {
        isExpanded = false
        selectedRow = 0
        selectedColumn = min(selectedColumn, max(0, (rows.first?.count ?? 1) - 1))
    }

    private func setInput(_ s: String) {
        input = s
        list = engine.candidates(for: s)
        rows = list.firstRow.isEmpty ? [] : [list.firstRow]
        var rest = list.more[...]
        while !rest.isEmpty {
            rows.append(Array(rest.prefix(columns)))
            rest = rest.dropFirst(columns)
        }
        isExpanded = false
        selectedRow = 0
        selectedColumn = 0
    }

    /// With `spaceAfter` (chosen with Space), an English candidate or the letters as typed is
    /// followed by a half-width space, so the next word can be typed straight away.
    private func choose(_ candidate: Candidate?, spaceAfter: Bool = false) -> ComposerUpdate {
        let space = spaceAfter ? " " : ""
        guard let candidate else {
            engine.noteInserted(.raw)
            spaceAdded = spaceAfter
            return commit(input + space, script: .latin)
        }
        engine.history?.record(input: input, text: candidate.text)
        engine.noteInserted(candidate.kind)
        let byHand = (built?.byHand ?? false) || candidate != rows.first?.first
        let soFar = (input: built?.input ?? input, text: (built?.text ?? "") + candidate.text,
                     picks: (built?.picks ?? 0) + 1, byHand: byHand)
        if let n = candidate.consumed, n < input.count {
            // Covers only the start: insert it and keep composing the rest.
            lastScript = TextScript(candidate.kind)
            setInput(String(input.dropFirst(n)))
            built = soFar
            return ComposerUpdate(handled: true, commit: candidate.text)
        }
        if soFar.byHand || soFar.picks > 1 { remember(soFar.input, soFar.text, last: candidate.kind) }
        let script = TextScript(candidate.kind)
        spaceAdded = spaceAfter && script == .latin
        return commit(candidate.text + (script == .latin ? space : ""), script: script)
    }

    /// A result built by hand becomes a custom word under all the letters typed for it, when it is
    /// 2–4 Chinese or Japanese characters (CustomWords decides). Built from several picks, it is
    /// also learned for those letters, so it comes first next time.
    private func remember(_ input: String, _ text: String, last kind: CandidateKind) {
        let kind: CandidateKind = kind == .chinese ? .chinese : JapaneseConverter.kind(of: text)
        if engine.customWords?.add(input: input, word: text, kind: kind) == true, built != nil {
            engine.history?.record(input: input, text: text)
        }
    }

    private func commit(_ text: String, script: TextScript) -> ComposerUpdate {
        lastScript = script
        reset()
        return ComposerUpdate(handled: true, commit: text)
    }

    /// Not composing: types `c` full-width after Chinese or Japanese text, or lets the application type it.
    private func typeAsScript(_ c: Character) -> ComposerUpdate {
        let script = Punctuation.script(before: textBeforeCursor?(), fallback: lastScript)
        lastScript = script
        let text = punctuation.convert(c, for: script)
        return text == String(c) ? ComposerUpdate(handled: false) : ComposerUpdate(handled: true, commit: text)
    }
}
