#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Converts typed romaji (Hepburn and Kunrei spellings) into hiragana.
public enum Romaji {
    static let table: [String: String] = {
        var t: [String: String] = [
            "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
            "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
            "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
            "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
            "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
            "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
            "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
            "ya": "や", "yu": "ゆ", "yo": "よ",
            "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
            "wa": "わ", "wi": "うぃ", "we": "うぇ", "wo": "を",
            "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
            "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
            "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
            "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
            "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
            "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
            "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
            "sha": "しゃ", "shu": "しゅ", "she": "しぇ", "sho": "しょ",
            "cha": "ちゃ", "chu": "ちゅ", "che": "ちぇ", "cho": "ちょ",
            "ja": "じゃ", "ju": "じゅ", "je": "じぇ", "jo": "じょ",
            "tsa": "つぁ", "thi": "てぃ", "dhi": "でぃ", "twu": "とぅ", "dwu": "どぅ",
            "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
            // Small kana only through x: l-spellings would turn English words (hello) into kana.
            "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ", "xtu": "っ", "xtsu": "っ", "xwa": "ゎ",
            "nn": "ん", "n'": "ん", "-": "ー",
        ]
        // Contracted sounds: kya, sya, nya, ...
        let rows: [(String, String)] = [("k", "き"), ("s", "し"), ("t", "ち"), ("c", "ち"), ("n", "に"), ("h", "ひ"),
                                        ("m", "み"), ("r", "り"), ("g", "ぎ"), ("z", "じ"), ("j", "じ"), ("d", "ぢ"),
                                        ("b", "び"), ("p", "ぴ")]
        for (c, kana) in rows {
            t[c + "ya"] = kana + "ゃ"; t[c + "yu"] = kana + "ゅ"; t[c + "yo"] = kana + "ょ"
            t[c + "ye"] = kana + "ぇ"; t[c + "yi"] = kana + "ぃ"
        }
        return t
    }()

    static let vowels: Set<Character> = ["a", "i", "u", "e", "o"]

    /// Whether `letters` could be the start of a syllable still being typed (k, ky, sh, ts...).
    public static func isPartialSyllable(_ letters: String) -> Bool {
        let l = letters.lowercased()
        return l.isEmpty || prefixes.contains(l)
    }

    static let prefixes: Set<String> = Set(table.keys.flatMap { key in (1..<key.count).map { String(key.prefix($0)) } })

    /// Hiragana for the whole input, or nil when some letters do not spell kana
    /// (for example `hello`, or a trailing consonant still being typed).
    public static func toHiragana(_ input: String) -> String? {
        let r = convert(input)
        return r.rest.isEmpty ? r.kana : nil
    }

    /// Converts as much of the input as spells kana; `rest` is the unconverted tail.
    public static func convert(_ input: String) -> (kana: String, rest: String) {
        let s = Array(input.lowercased())
        var out = ""
        var i = 0
        while i < s.count {
            let c = s[i]
            // A doubled consonant is a small tsu: kitte, matcha.
            if i + 1 < s.count, c != "n", !vowels.contains(c), c.isLetter,
               s[i + 1] == c || (c == "t" && s[i + 1] == "c") {
                out += "っ"; i += 1; continue
            }
            // "nn" before a vowel is ん plus the next syllable: konnichiha → こんにちは.
            if c == "n", i + 2 < s.count, s[i + 1] == "n", vowels.contains(s[i + 2]) || s[i + 2] == "y" {
                out += "ん"; i += 1; continue
            }
            var matched = false
            for len in stride(from: 4, through: 1, by: -1) where i + len <= s.count {
                let piece = String(s[i..<(i + len)])
                if let kana = table[piece] {
                    out += kana; i += len; matched = true; break
                }
            }
            if matched { continue }
            // A lone n before a consonant, or at the very end, is ん.
            if c == "n", i + 1 == s.count || (!vowels.contains(s[i + 1]) && s[i + 1] != "y") {
                out += "ん"; i += 1; continue
            }
            return (out, String(s[i...]))
        }
        return (out, "")
    }
}
