#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Japanese verbs and adjectives in their conjugated forms (たべた → 食べた, いきます → 行きます,
/// たかかった → 高かった). The dictionary keeps every verb and adjective once more in its dictionary
/// form, under its reading with `mark` and its class in front (活一たべる 食べる, 活五かく 書く): no
/// typed reading starts with a kanji, so other lookups never see them. A typed form is read back to
/// that dictionary form by its ending, and the ending put on the word.
public enum Conjugation {
    public static let mark = "活"

    /// How a verb or adjective conjugates; its raw value goes after `mark` in the dictionary key.
    public enum Class: Character, CaseIterable {
        /// 食べる, 見る: drop る.
        case ichidan = "一"
        /// 書く, 飲む, 帰る: the last kana changes by its row.
        case godan = "五"
        /// 行く: like 書く, but 行った.
        case iku = "行"
        /// なさる, いらっしゃる: like 帰る, but なさいます.
        case honorific = "御"
        /// 来る: くる, こない, きます.
        case kuru = "来"
        /// する, 愛する.
        case suru = "為"
        /// 高い: 高かった, 高くない.
        case adjective = "形"
    }

    public static func key(_ c: Class, _ reading: String) -> String { mark + String(c.rawValue) + reading }

    /// One conjugated form: the kana `drop` at the end of the dictionary form give way to `ending`.
    struct Form {
        let type: Class
        let drop: String
        let ending: String
        let cost: Int
    }

    /// Added to a conjugated form's dictionary form; more for the rarer forms.
    static let commonForm = 5
    static let otherForm = 15
    static let imperativeForm = 30
    static let kanaForm = 10

    static let negative = ["ない", "なかった", "なくて", "なければ", "ないで", "ず"]
    static let polite = ["ます", "ました", "ません", "ませんでした", "ましょう", "まして"]
    static let wanting = ["たい", "たかった", "たくない", "たくて"]
    /// The forms typed most: the plain negative, past and て forms and the polite ones.
    static func isCommon(_ ending: String) -> Bool {
        ["ない", "なかった", "ます", "ました", "ません", "たい"].contains { ending.hasSuffix($0) }
            || ending.count <= 2 && "ただてで".contains(ending.last!)
    }

    /// The rows of a godan verb's last kana: the a, i, e and o forms, the sound before た, and た or だ.
    static let godanRows: [Character: (a: String, i: String, e: String, o: String, sound: String, ta: String)] = [
        "う": ("わ", "い", "え", "お", "っ", "た"), "く": ("か", "き", "け", "こ", "い", "た"),
        "ぐ": ("が", "ぎ", "げ", "ご", "い", "だ"), "す": ("さ", "し", "せ", "そ", "し", "た"),
        "つ": ("た", "ち", "て", "と", "っ", "た"), "ぬ": ("な", "に", "ね", "の", "ん", "だ"),
        "ぶ": ("ば", "び", "べ", "ぼ", "ん", "だ"), "む": ("ま", "み", "め", "も", "ん", "だ"),
        "る": ("ら", "り", "れ", "ろ", "っ", "た"),
    ]

    /// Every form, by its ending.
    static let forms: [String: [Form]] = {
        var all: [Form] = []
        func add(_ type: Class, _ drop: String, _ endings: [String], cost: Int? = nil) {
            for e in endings {
                all.append(Form(type: type, drop: drop, ending: e, cost: cost ?? (isCommon(e) ? commonForm : otherForm)))
            }
        }
        // The past and the て forms, from the sound before た (書い, 飲ん, 食べ).
        func past(_ sound: String, _ ta: String) -> [String] {
            let te = ta == "た" ? "て" : "で"
            // With いる after て, as one word (しています, not 指定ます).
            let progressive = ["いる", "います", "いました", "いた", "いない", "いません", "る", "た", "ください"]
            return [sound + ta, sound + te, sound + ta + "ら", sound + ta + "り"] + progressive.map { sound + te + $0 }
        }
        for (u, row) in godanRows {
            let types: [Class] = u == "く" ? [.godan, .iku] : u == "る" ? [.godan, .honorific] : [.godan]
            for type in types {
                let d = String(u)
                add(type, d, (negative + ["せる", "れる"]).map { row.a + $0 })
                add(type, d, (polite + wanting + ["ながら"]).map { (type == .honorific ? "い" : row.i) + $0 })
                add(type, d, past(type == .iku ? "っ" : row.sound, row.ta))
                add(type, d, [row.e + "ば", row.o + "う"])
                add(type, d, [row.e], cost: imperativeForm)
            }
        }
        add(.ichidan, "る", negative + polite + wanting + past("", "た") + ["ながら", "れば", "よう", "られる", "させる"])
        add(.ichidan, "る", ["ろ"], cost: imperativeForm)
        add(.kuru, "くる", negative.map { "こ" + $0 } + (polite + wanting).map { "き" + $0 } + past("き", "た")
                         + ["くれば", "こよう", "こられる", "こさせる"])
        add(.kuru, "くる", ["こい"], cost: imperativeForm)
        add(.suru, "する", (negative + polite + wanting).map { "し" + $0 } + past("し", "た") + ["すれば", "しよう", "される", "させる"])
        add(.suru, "する", ["しろ"], cost: imperativeForm)
        add(.adjective, "い", ["かった", "くない", "くなかった", "くて", "ければ", "く", "さ", "そう"])
        return Dictionary(grouping: all, by: \.ending)
    }()

    static let longestEnding = forms.keys.map(\.count).max() ?? 0

    /// The words `kana` is a conjugated form of, put in that form (たべた → 食べた), cheapest first.
    public static func words(for kana: String, in lexicon: Lexicon) -> [LexiconEntry] {
        let chars = Array(kana)
        var out: [LexiconEntry] = []
        for n in stride(from: min(longestEnding, chars.count), through: 1, by: -1) {
            let ending = String(chars[(chars.count - n)...])
            let stem = String(chars[..<(chars.count - n)])
            for form in forms[ending] ?? [] {
                // Every verb needs some stem before its ending, but 来る and する (きた, した).
                guard !stem.isEmpty || form.type == .kuru || form.type == .suru else { continue }
                for e in lexicon.exact(key(form.type, stem + form.drop)) {
                    let text: String
                    if form.type == .kuru, e.word.hasSuffix("来る") { text = String(e.word.dropLast() + ending.dropFirst()) }
                    else if e.word.hasSuffix(form.drop) { text = String(e.word.dropLast(form.drop.count)) + ending }
                    else { continue }
                    // A verb written in kana gives just the kana typed, offered anyway: after the kanji (いきます, 行きます).
                    let cost = e.cost + form.cost + (text.unicodeScalars.allSatisfy(Kana.isHiragana) ? kanaForm : 0)
                    if !out.contains(where: { $0.word == text }) { out.append(LexiconEntry(key: kana, word: text, cost: cost)) }
                }
            }
        }
        return out.sorted { $0.cost < $1.cost }
    }
}
