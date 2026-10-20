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
/// (the first one unless moved); Return inserts the letters as typed; 1–9 insert that candidate
/// of the selected row; ←/→ move the selection; ↓ or Tab expands the bar into more rows (and then
/// moves down a row), ↑ moves up a row and collapses from the first; Backspace removes a letter;
/// Esc collapses, or cancels when not expanded. Another typed character inserts the selected
/// candidate and is then typed as usual. Choosing a candidate that covers only the start of the
/// letters inserts it and leaves the rest to go on typing.
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
            if isExpanded { collapse() } else { reset() }
        case .space:
            return choose(selected)
        case .enter:
            return commit(input)
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
        case .other:
            // Insert the selected candidate, then let the application type the character.
            var update = commit(selected?.consumed == nil ? (selected?.text ?? input) : input)
            update.handled = false
            return update
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
        let text = selected?.consumed == nil ? (selected?.text ?? input) : input
        reset()
        return text
    }

    public func reset() { setInput("") }

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

    private func choose(_ candidate: Candidate?) -> ComposerUpdate {
        guard let candidate else { return commit(input) }
        if let n = candidate.consumed, n < input.count {
            // Covers only the start: insert it and keep composing the rest.
            setInput(String(input.dropFirst(n)))
            return ComposerUpdate(handled: true, commit: candidate.text)
        }
        return commit(candidate.text)
    }

    private func commit(_ text: String) -> ComposerUpdate {
        reset()
        return ComposerUpdate(handled: true, commit: text)
    }
}
