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

    /// Letters with "-" for the long vowel mark ー after them (sute-tasu), never leading.
    static func hasLongVowelMarks(_ input: String) -> Bool {
        input.first?.isLetter == true && input.contains("-")
            && input.allSatisfy { ($0.isASCII && $0.isLetter) || $0 == "-" }
    }

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
    /// Where an `n` before a vowel could also be ん, this is the な-row reading (unei → うねい);
    /// `readings` gives the others.
    public static func convert(_ input: String) -> (kana: String, rest: String) {
        var first: (kana: String, rest: String)?
        walk(Array(input.lowercased()), from: 0, kana: "", alternatives: false) { first = first ?? $0; return false }
        return first!
    }

    /// Every way the whole input spells kana, the な-row reading of each `n` before a vowel first:
    /// unei → [うねい, うんえい], unnei → [うんねい, うんえい]. Empty when some letters do not spell kana.
    /// At most `limit` readings.
    public static func readings(_ input: String, limit: Int = 8) -> [String] {
        var out: [String] = []
        walk(Array(input.lowercased()), from: 0, kana: "", alternatives: true) {
            if $0.rest.isEmpty, !out.contains($0.kana) { out.append($0.kana) }
            return out.count < limit
        }
        return out
    }

    /// Converts from `start`, calling `found` with each complete walk (the kana and the
    /// unconverted tail): the straight reading first, then, with `alternatives`, the readings with
    /// an `n` before a vowel as ん, nearest first. `found` returns whether to go on.
    @discardableResult
    private static func walk(_ s: [Character], from start: Int, kana: String, alternatives: Bool,
                             _ found: ((kana: String, rest: String)) -> Bool) -> Bool {
        var out = kana
        var i = start
        var branches: [(from: Int, kana: String)] = []
        var rest = ""
        loop: while i < s.count {
            let c = s[i]
            // A doubled consonant is a small tsu: kitte, matcha.
            if i + 1 < s.count, c != "n", !vowels.contains(c), c.isLetter,
               s[i + 1] == c || (c == "t" && s[i + 1] == "c") {
                out += "っ"; i += 1; continue
            }
            let beforeVowel = i + 1 < s.count && (vowels.contains(s[i + 1]) || s[i + 1] == "y")
            // "nn" before a vowel is ん plus the next syllable: konnichiha → こんにちは;
            // or, as in other input methods, ん and then the vowel: unnei → うんえい.
            if c == "n", i + 2 < s.count, s[i + 1] == "n", vowels.contains(s[i + 2]) || s[i + 2] == "y" {
                branches.append((i + 2, out + "ん"))
                out += "ん"; i += 1; continue
            }
            // A lone n before a vowel is the な-row syllable (unei → うねい), but can also be ん
            // closing a word: unei → うんえい (運営), renai → れんあい (恋愛). Never at the start.
            if c == "n", beforeVowel, i > 0, s[i - 1] != "n" {
                branches.append((i + 1, out + "ん"))
            }
            for len in stride(from: 4, through: 1, by: -1) where i + len <= s.count {
                if let kana = table[String(s[i..<(i + len)])] {
                    out += kana; i += len; continue loop
                }
            }
            // A lone n before a consonant, or at the very end, is ん.
            if c == "n", !beforeVowel {
                out += "ん"; i += 1; continue
            }
            rest = String(s[i...]); break
        }
        guard found((out, rest)) else { return false }
        if alternatives {
            for b in branches where !walk(s, from: b.from, kana: b.kana, alternatives: true, found) { return false }
        }
        return true
    }
}
