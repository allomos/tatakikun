#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Words typed by their consonants alone: the first letter of each pinyin syllable (nh → 你好),
/// or the consonant of each kana (wtx → わたし). Only inputs with no vowels are looked up this
/// way, so full spellings rank as before.
public enum Abbreviation {
    static let vowels: Set<Character> = ["a", "e", "i", "o", "u"]

    /// Whether `input` can be an abbreviation: two or more letters, none of them vowels.
    public static func applies(to input: String) -> Bool {
        input.count >= 2 && input.allSatisfy { $0.isASCII && $0.isLetter && !vowels.contains(Character($0.lowercased())) }
    }

    /// The abbreviation of a pinyin key written with `'` between syllables (zhong'guo → zg),
    /// or nil for one syllable or a syllable starting with a vowel (no vowel-free way to type it).
    public static func pinyin(_ key: Substring) -> String? {
        let syllables = key.split(separator: "'")
        guard syllables.count >= 2 else { return nil }
        let initials = syllables.compactMap(\.first)
        guard initials.count == syllables.count, !initials.contains(where: vowels.contains) else { return nil }
        return String(initials)
    }

    /// One letter per kana with a consonant; small kana, vowels and ー are skipped.
    static let kanaConsonant: [Unicode.Scalar: Character] = {
        let rows: [(Character, String)] = [
            ("k", "かきくけこ"), ("g", "がぎぐげご"), ("s", "さしすせそ"), ("z", "ざじずぜぞ"),
            ("t", "たちつてと"), ("d", "だぢづでど"), ("n", "なにぬねのん"), ("h", "はひふへほ"),
            ("b", "ばびぶべぼ"), ("p", "ぱぴぷぺぽ"), ("m", "まみむめも"), ("y", "やゆよ"),
            ("r", "らりるれろ"), ("w", "わを"), ("v", "ゔ"),
        ]
        var t: [Unicode.Scalar: Character] = [:]
        for (letter, kana) in rows { for s in kana.unicodeScalars { t[s] = letter } }
        return t
    }()

    /// The consonants of a hiragana reading (わたし → wts, とうきょう → tk), or nil when fewer than two.
    public static func kana(_ reading: Substring) -> String? {
        var out = ""
        for s in reading.unicodeScalars {
            guard Kana.isHiragana(s) else { return nil }
            if let c = kanaConsonant[s] { out.append(c) }
        }
        return out.count >= 2 ? out : nil
    }

    /// The pinyin abbreviations `input` may stand for: zh, ch, sh are one initial or two (zhg → zg, zhg).
    public static func pinyinKeys(_ input: String) -> [String] {
        expand(Array(input.lowercased()), digraphs: ["zh": "z", "ch": "c", "sh": "s"], aliases: [:])
    }

    /// The kana abbreviations `input` may stand for, in the spellings people use for each consonant:
    /// shi or xi for し, chi or ci for ち, tsu for つ, fu for ふ, ji for じ (wtx, wtsh → wts).
    public static func kanaKeys(_ input: String) -> [String] {
        expand(Array(input.lowercased()), digraphs: ["sh": "s", "ch": "t", "ts": "t"],
               aliases: ["x": "s", "c": "t", "f": "h", "j": "z"])
    }

    private static func expand(_ s: [Character], digraphs: [String: Character], aliases: [Character: Character]) -> [String] {
        var results: [String] = []
        func walk(_ i: Int, _ acc: String) {
            guard results.count < 16 else { return }
            if i == s.count { results.append(acc); return }
            if i + 1 < s.count, let d = digraphs[String(s[i...i + 1])] { walk(i + 2, acc + String(d)) }
            walk(i + 1, acc + String(aliases[s[i]] ?? s[i]))
        }
        walk(0, "")
        return Array(Set(results))
    }
}
