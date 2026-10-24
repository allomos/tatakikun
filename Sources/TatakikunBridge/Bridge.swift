#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import TatakikunCore

// The engine for apps written in other languages (the Android keyboard, through JNI): plain C
// functions over one Composer. Each call returns the composer's state as JSON, which the caller
// frees with ttk_free.

/// One keyboard: its composer, and the text before the cursor the app last told.
final class Keyboard {
    let composer: Composer
    var before: String?

    init(engine: Engine) {
        composer = Composer(engine: engine)
        composer.textBeforeCursor = { [unowned self] in self.before }
    }
}

/// What the keyboard shows after a key, and what to insert.
struct State: Encodable {
    struct Item: Encodable { let text: String; let kind: String; let exact: Bool }
    let handled: Bool
    let commit: String?
    let input: String
    let rows: [[Item]]
    let selectedRow: Int
    let selectedColumn: Int
    let expanded: Bool
    let canExpand: Bool
}

func state(_ k: Keyboard, _ update: ComposerUpdate) -> UnsafeMutablePointer<CChar>? {
    let c = k.composer
    let s = State(handled: update.handled, commit: update.commit, input: c.input,
                  rows: c.visibleRows.map { $0.map { State.Item(text: $0.text, kind: $0.kind.tag, exact: $0.isExact) } },
                  selectedRow: c.selectedRow, selectedColumn: c.selectedColumn,
                  expanded: c.isExpanded, canExpand: c.canExpand)
    guard let data = try? JSONEncoder().encode(s) else { return nil }
    return strdupBytes(Array(data))
}

/// A C string the caller frees with ttk_free.
func strdupBytes(_ bytes: [UInt8]) -> UnsafeMutablePointer<CChar> {
    let p = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count + 1)
    for (i, b) in bytes.enumerated() { p[i] = CChar(bitPattern: b) }
    p[bytes.count] = 0
    return p
}

/// Opens the language packs in `packs` (<packs>/<zh|ja|en>/<lang>.ttkd) and keeps what is learned
/// in `data` (history.tsv, custom-words.tsv). Nil when the packs cannot be read.
@_cdecl("ttk_create")
public func ttk_create(_ packs: UnsafePointer<CChar>, _ data: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    let folder = URL(fileURLWithPath: String(cString: packs))
    let dataFolder = URL(fileURLWithPath: String(cString: data))
    guard let engine = try? Engine(packFolders: [folder]) else { return nil }
    engine.history = UserHistory(url: dataFolder.appendingPathComponent("history.tsv"))
    engine.customWords = CustomWords(url: dataFolder.appendingPathComponent("custom-words.tsv"))
    return Unmanaged.passRetained(Keyboard(engine: engine)).toOpaque()
}

@_cdecl("ttk_destroy")
public func ttk_destroy(_ handle: UnsafeMutableRawPointer) {
    Unmanaged<Keyboard>.fromOpaque(handle).release()
}

/// The text just before the cursor, so punctuation and spaces follow the language there.
@_cdecl("ttk_set_text_before")
public func ttk_set_text_before(_ handle: UnsafeMutableRawPointer, _ text: UnsafePointer<CChar>?) {
    Unmanaged<Keyboard>.fromOpaque(handle).takeUnretainedValue().before = text.map { String(cString: $0) }
}

/// A key: `kind` 0 letter, 1 digit, 2 backspace, 3 escape, 4 space, 5 enter, 6 left, 7 right,
/// 8 up, 9 down, 10 tab, 11 other character; `scalar` the character for 0, 1 and 11.
/// The languages turned off in the settings, as their pack names separated by commas ("ja,en"; "" for none).
@_cdecl("ttk_set_turned_off")
public func ttk_set_turned_off(_ handle: UnsafeMutableRawPointer, _ languages: UnsafePointer<CChar>) {
    let names = String(cString: languages).split(separator: ",")
    Unmanaged<Keyboard>.fromOpaque(handle).takeUnretainedValue().composer.engine.turnedOff =
        Set(names.compactMap { LanguagePacks.Language(rawValue: String($0)) })
}

@_cdecl("ttk_key")
public func ttk_key(_ handle: UnsafeMutableRawPointer, _ kind: Int32, _ scalar: UInt32) -> UnsafeMutablePointer<CChar>? {
    let k = Unmanaged<Keyboard>.fromOpaque(handle).takeUnretainedValue()
    let c = Character(Unicode.Scalar(scalar) ?? " ")
    let key: Key
    switch kind {
    case 0: key = .letter(c)
    case 1: key = .digit(c.wholeNumberValue ?? 0)
    case 2: key = .backspace
    case 3: key = .escape
    case 4: key = .space
    case 5: key = .enter
    case 6: key = .left
    case 7: key = .right
    case 8: key = .up
    case 9: key = .down
    case 10: key = .tab
    default: key = .other(c)
    }
    return state(k, k.composer.handle(key))
}

/// A candidate tapped in the bar (row 0) or the rows below it.
@_cdecl("ttk_choose")
public func ttk_choose(_ handle: UnsafeMutableRawPointer, _ row: Int32, _ column: Int32) -> UnsafeMutablePointer<CChar>? {
    let k = Unmanaged<Keyboard>.fromOpaque(handle).takeUnretainedValue()
    return state(k, k.composer.choose(row: Int(row), column: Int(column)))
}

/// Ends composing (the keyboard is closed or the field changes): inserts what is typed.
@_cdecl("ttk_finish")
public func ttk_finish(_ handle: UnsafeMutableRawPointer) -> UnsafeMutablePointer<CChar>? {
    let k = Unmanaged<Keyboard>.fromOpaque(handle).takeUnretainedValue()
    let text = k.composer.finish()
    k.composer.engine.forgetRecent()
    return state(k, ComposerUpdate(handled: text != nil, commit: text))
}

/// What each punctuation key would type now (`ttk_marks`): the keys show it.
let markKeys: [Character] = Array(",.?!:;()[]{}<>\\/~^_$\"'@#%&-+*=|")

/// What each punctuation key would type now, as a JSON object ({",": "，", ...}), for the keys to
/// show; it changes with the text before the cursor and the candidate being composed.
@_cdecl("ttk_marks")
public func ttk_marks(_ handle: UnsafeMutableRawPointer) -> UnsafeMutablePointer<CChar>? {
    let k = Unmanaged<Keyboard>.fromOpaque(handle).takeUnretainedValue()
    var marks: [String: String] = [:]
    for c in markKeys { marks[String(c)] = k.composer.mark(for: c) }
    guard let data = try? JSONEncoder().encode(marks) else { return nil }
    return strdupBytes(Array(data))
}

@_cdecl("ttk_free")
public func ttk_free(_ p: UnsafeMutablePointer<CChar>?) { p?.deallocate() }
