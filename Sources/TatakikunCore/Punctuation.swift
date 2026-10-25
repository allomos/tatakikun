#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The kind of text being written, which decides full-width or half-width punctuation and spaces.
public enum TextScript: Equatable {
    case latin, chinese, japanese

    public init(_ kind: CandidateKind) {
        switch kind {
        case .english, .spanish, .french, .hindi, .bengali, .arabic, .raw: self = .latin
        case .chinese: self = .chinese
        case .kanji, .hiragana, .katakana: self = .japanese
        }
    }

    public var isFullWidth: Bool { self != .latin }
}

/// Turns typed punctuation and spaces into the full-width forms of Chinese or Japanese text,
/// or leaves them as typed in English text.
public struct Punctuation {
    /// Whether the next double / single quote opens (“ ‘) or closes (” ’).
    private var doubleOpen = true
    private var singleOpen = true

    public init() {}

    static let chinese: [Character: String] = [
        ",": "，", ".": "。", "?": "？", "!": "！", ":": "：", ";": "；",
        "(": "（", ")": "）", "[": "【", "]": "】", "<": "《", ">": "》",
        "\\": "、", "~": "～", "^": "……", "_": "——", "$": "￥",
    ]
    static let japanese: [Character: String] = [
        ",": "、", ".": "。", "?": "？", "!": "！", ":": "：", ";": "；",
        "(": "（", ")": "）", "[": "「", "]": "」", "{": "『", "}": "』",
        "~": "〜", "/": "・", "\\": "＼",
    ]

    /// The text to type for `c` in text of this script.
    public mutating func convert(_ c: Character, for script: TextScript) -> String {
        guard script.isFullWidth else { return String(c) }
        switch c {
        case "\"":
            defer { doubleOpen.toggle() }
            return doubleOpen ? "“" : "”"
        case "'":
            defer { singleOpen.toggle() }
            return singleOpen ? "‘" : "’"
        case " ":
            return "\u{3000}"
        default:
            return (script == .chinese ? Self.chinese : Self.japanese)[c] ?? String(c)
        }
    }

    /// The marks a punctuation key offers as candidates (on the Mac), after the one it types now.
    static let alternatives: [Character: [String]] = [
        ",": ["、", "，", ","], ".": ["。", "．", "."], "?": ["？", "?"], "!": ["！", "!"],
        ":": ["：", ":"], ";": ["；", ";"], "(": ["（", "(", "〔", "｟"], ")": ["）", ")", "〕", "｠"],
        "[": ["「", "【", "[", "『", "［", "〔", "〖"], "]": ["」", "】", "]", "』", "］", "〕", "〗"],
        "{": ["『", "｛", "{", "〘"], "}": ["』", "｝", "}", "〙"],
        "<": ["《", "〈", "＜", "<", "≪"], ">": ["》", "〉", "＞", ">", "≫"],
        "/": ["・", "／", "/"], "\\": ["＼", "、", "\\", "￥"], "~": ["〜", "～", "~"],
        "^": ["……", "＾", "^"], "_": ["——", "＿", "_"], "$": ["￥", "＄", "$"],
        "\"": ["“", "”", "「", "」", "＂", "\""], "'": ["‘", "’", "『", "』", "＇", "'"],
    ]

    /// The marks key `c` offers in text of this script: the one it types now first, then the
    /// others; empty when it has no others.
    public func marks(for c: Character, script: TextScript) -> [String] {
        guard let others = Self.alternatives[c] else { return [] }
        var copy = self
        var marks = [copy.convert(c, for: script)]
        for mark in others where !marks.contains(mark) { marks.append(mark) }
        return marks
    }

    /// Notes a mark typed some other way (a candidate), so the next quote opens or closes after it.
    public mutating func noteTyped(_ mark: String) {
        switch mark {
        case "“": doubleOpen = false
        case "”": doubleOpen = true
        case "‘": singleOpen = false
        case "’": singleOpen = true
        default: break
        }
    }

    static let japaneseOnly: Set<Character> = ["、", "「", "」", "『", "』", "・", "〜", "ー"]
    static let chineseOnly: Set<Character> = ["，", "“", "”", "‘", "’", "【", "】", "《", "》", "～", "…", "—", "￥"]

    /// The script of the text that ends with `text`, judged by its last character; `fallback`
    /// when that does not tell (no text, a line break, a han character or a mark both languages use).
    /// Han characters and shared marks count as Japanese only when the fallback is Japanese.
    public static func script(before text: String?, fallback: TextScript) -> TextScript {
        guard let c = text?.last, !c.isNewline else { return fallback }
        let cjk: TextScript = fallback == .japanese ? .japanese : .chinese
        if japaneseOnly.contains(c) { return .japanese }
        if chineseOnly.contains(c) { return .chinese }
        guard let scalar = c.unicodeScalars.first else { return fallback }
        switch scalar.value {
        case 0x3040...0x30FF, 0x31F0...0x31FF, 0xFF66...0xFF9F: return .japanese   // kana
        case 0x3000...0x303F, 0xFF01...0xFF65: return cjk                          // CJK marks, full-width forms
        case 0x3400...0x9FFF, 0xF900...0xFAFF, 0x20000...0x3FFFF: return cjk       // han
        default: break
        }
        if c.isASCII || c.isLetter || c.isNumber || c.isPunctuation || c.isWhitespace { return .latin }
        return fallback
    }
}
