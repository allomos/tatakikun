import Foundation
import TatakikunCore

// Languages written in a Brahmic script and typed by sound in Latin letters (Hindi: namaste →
// नमस्ते). Their packs key every word by the ways people spell it in Latin letters: spellings made
// from the letters by the table below, and the ones people really used (Aksharantar's pairs).

/// A Brahmic script: Devanagari and Bengali share one layout, offset from the start of their
/// Unicode block (क U+0915 and ক U+0995 are both 0x15).
struct IndicScript {
    let base: UInt32
    /// The vowel a consonant carries when it has no vowel sign (Hindi a, Bengali o).
    let inherent: [(String, Int)]
    /// Whether an unwritten vowel inside a word is dropped as Hindi speakers do (namaste, not
    /// namasate; kamra, not kamara): see `syllables`.
    let dropsVowels: Bool
    /// This script's own spellings of letters, signs and marks, in place of the shared table's.
    var overrides: [UInt32: [(String, Int)]] = [:]
    /// Spellings of a consonant that follows another in a cluster, where it differs (Bengali ্য, ্ব).
    var afterConsonant: [UInt32: [(String, Int)]] = [:]

    static let devanagari = IndicScript(base: 0x900, inherent: [("a", 0)], dropsVowels: true)

    /// Bengali: the unwritten vowel is o (কেমন kemon), ৈ ৌ are oi ou, ং is ng (বাংলা bangla), য
    /// starting a syllable is j (যদি jodi); after a consonant, য and ব mostly double it
    /// (ধন্যবাদ dhonnobad, বিশ্ব bishsho), and are also written y and b.
    static let bengaliBase: UInt32 = 0x980
    static let bengali = IndicScript(
        base: bengaliBase, inherent: [("o", 0), ("a", 2)], dropsVowels: true,
        overrides: [0x48: [("oi", 0), ("ai", 2)], 0x4C: [("ou", 0), ("au", 2)], 0x10: [("oi", 0)], 0x14: [("ou", 0)],
                    0x02: [("ng", 0), ("n", 1)], 0x01: [("", 0), ("n", 2)], 0x2F: [("j", 0), ("y", 2)],
                    0x36: [("sh", 0), ("s", 2)], 0x37: [("sh", 0), ("s", 2)], 0x38: [("s", 0), ("sh", 1)],
                    0x2C: [("b", 0)], 0x2B: [("ph", 0), ("f", 1)], 0x3E: [("a", 0)], 0x06: [("a", 0)]],
        afterConsonant: [0x2F: [("", 0), ("y", 1)], 0x2C: [("", 0), ("b", 2), ("w", 2)]])

    func letter(_ o: UInt32) -> [(String, Int)]? {
        o == 0x4E && base == Self.bengaliBase ? [("t", 0)] : Self.consonants[o].map { overrides[o] ?? $0 }
    }
    func vowelSign(_ o: UInt32) -> [(String, Int)]? { Self.vowelSigns[o].map { overrides[o] ?? $0 } }
    func vowel(_ o: UInt32) -> [(String, Int)]? { Self.vowels[o].map { overrides[o] ?? $0 } }
    func mark(_ o: UInt32) -> [(String, Int)]? { Self.marks[o].map { overrides[o] ?? $0 } }

    /// Spellings of each letter, by offset, the usual one first, each with what it adds to the cost.
    static let consonants: [UInt32: [(String, Int)]] = [
        0x15: [("k", 0)], 0x16: [("kh", 0)], 0x17: [("g", 0)], 0x18: [("gh", 0)], 0x19: [("n", 0), ("ng", 3)],
        0x1A: [("ch", 0), ("c", 4)], 0x1B: [("chh", 0), ("ch", 2)], 0x1C: [("j", 0)], 0x1D: [("jh", 0)], 0x1E: [("n", 0)],
        0x1F: [("t", 0)], 0x20: [("th", 0)], 0x21: [("d", 0)], 0x22: [("dh", 0)], 0x23: [("n", 0)],
        0x24: [("t", 0)], 0x25: [("th", 0)], 0x26: [("d", 0)], 0x27: [("dh", 0)], 0x28: [("n", 0)], 0x29: [("n", 0)],
        0x2A: [("p", 0)], 0x2B: [("ph", 0), ("f", 2)], 0x2C: [("b", 0)], 0x2D: [("bh", 0)], 0x2E: [("m", 0)],
        0x2F: [("y", 0)], 0x30: [("r", 0)], 0x31: [("r", 0)], 0x32: [("l", 0)], 0x33: [("l", 0)], 0x34: [("l", 0)],
        0x35: [("v", 0), ("w", 2)], 0x36: [("sh", 0)], 0x37: [("sh", 0)], 0x38: [("s", 0)], 0x39: [("h", 0)],
        // With a nukta (क़ ख़ ग़ ज़ ड़ ढ़ फ़ य़).
        0x58: [("q", 0), ("k", 2)], 0x59: [("kh", 0)], 0x5A: [("g", 0)], 0x5B: [("z", 0), ("j", 2)],
        0x5C: [("r", 0), ("d", 3)], 0x5D: [("rh", 0), ("dh", 3)], 0x5E: [("f", 0), ("ph", 2)], 0x5F: [("y", 0)],
    ]
    /// A consonant with a nukta after it: the precomposed letter's offset.
    static let nukta: [UInt32: UInt32] = [0x15: 0x58, 0x16: 0x59, 0x17: 0x5A, 0x1C: 0x5B, 0x21: 0x5C, 0x22: 0x5D, 0x2B: 0x5E, 0x2F: 0x5F]
    static let vowelSigns: [UInt32: [(String, Int)]] = [
        0x3E: [("a", 0), ("aa", 2)], 0x3F: [("i", 0)], 0x40: [("i", 0), ("ee", 2)], 0x41: [("u", 0)],
        0x42: [("u", 0), ("oo", 2)], 0x43: [("ri", 0)], 0x44: [("ri", 0)], 0x45: [("e", 0), ("a", 3)], 0x46: [("e", 0)],
        0x47: [("e", 0)], 0x48: [("ai", 0), ("e", 3)], 0x49: [("o", 0)], 0x4A: [("o", 0)], 0x4B: [("o", 0)],
        0x4C: [("au", 0), ("ou", 2)],
    ]
    static let vowels: [UInt32: [(String, Int)]] = [
        0x05: [("a", 0)], 0x06: [("a", 0), ("aa", 2)], 0x07: [("i", 0)], 0x08: [("i", 0), ("ee", 2)], 0x09: [("u", 0)],
        0x0A: [("u", 0), ("oo", 2)], 0x0B: [("ri", 0)], 0x0D: [("e", 0)], 0x0E: [("e", 0)], 0x0F: [("e", 0)],
        0x10: [("ai", 0), ("e", 3)], 0x11: [("o", 0)], 0x12: [("o", 0)], 0x13: [("o", 0)], 0x14: [("au", 0), ("ou", 2)],
    ]
    /// Candrabindu, anusvara (a nasal vowel, or n/m before a consonant), visarga.
    static let marks: [UInt32: [(String, Int)]] = [0x01: [("n", 0), ("", 3)], 0x02: [("n", 0), ("m", 4), ("", 5)], 0x03: [("h", 0), ("", 2)]]
    /// Each unaspirated consonant's aspirate (च → छ).
    static let aspirated: [UInt32: UInt32] = [0x15: 0x16, 0x17: 0x18, 0x1A: 0x1B, 0x1C: 0x1D, 0x1F: 0x20, 0x21: 0x22,
                                              0x24: 0x25, 0x26: 0x27, 0x2A: 0x2B, 0x2C: 0x2D]
    static let virama: UInt32 = 0x4D
    static let nuktaSign: UInt32 = 0x3C

    /// One syllable: its consonants (empty for a vowel on its own), its vowel's spellings (nil
    /// for the unwritten vowel), and a nasal or visarga after it.
    struct Syllable {
        var consonants: [UInt32] = []
        var vowel: [(String, Int)]?
        var hasVowel = true   // false: the last consonant had a virama
        var marks: [[(String, Int)]] = []
    }

    /// The word's syllables, or nil when it holds anything but this script's letters and signs.
    func syllables(_ word: String) -> [Syllable]? {
        var out: [Syllable] = []
        var pendingVirama = false
        for scalar in word.unicodeScalars {
            guard scalar.value >= base, scalar.value < base + 0x80 else { return nil }
            let o = scalar.value - base
            if o == 0x4E, base == IndicScript.bengaliBase {   // Bengali ৎ: t with no vowel after it
                out.append(Syllable(consonants: [o], hasVowel: false))
                pendingVirama = false
            } else if Self.consonants[o] != nil {
                let c = o
                if pendingVirama, !out.isEmpty {
                    out[out.count - 1].consonants.append(c); out[out.count - 1].hasVowel = true
                } else {
                    out.append(Syllable(consonants: [c]))
                }
                pendingVirama = false
            } else if o == Self.nuktaSign {
                guard var last = out.popLast(), let c = last.consonants.popLast(), let n = Self.nukta[c] else { return nil }
                last.consonants.append(n); out.append(last)
            } else if o == Self.virama {
                guard !out.isEmpty else { return nil }
                out[out.count - 1].hasVowel = false
                pendingVirama = true
            } else if let v = vowelSign(o) {
                guard !out.isEmpty, out[out.count - 1].vowel == nil, !out[out.count - 1].consonants.isEmpty else { return nil }
                out[out.count - 1].vowel = v
                pendingVirama = false
            } else if let v = vowel(o) {
                out.append(Syllable(vowel: v))
                pendingVirama = false
            } else if let m = mark(o) {
                guard !out.isEmpty else { return nil }
                out[out.count - 1].marks.append(m)
            } else {
                return nil
            }
        }
        return out.isEmpty ? nil : out
    }

    /// The likely Latin spellings of a word, the most usual first, each with what it adds to the
    /// word's cost: at most `limit`, and none more than `maxExtra` dearer than the first.
    func spellings(_ word: String, limit: Int = 4, maxExtra: Int = 12) -> [(String, Int)] {
        guard let sylls = syllables(word) else { return [] }
        // Which unwritten vowels are dropped: at the end of the word after one consonant, and
        // inside it between a vowel and a consonant with a vowel (kamara → kamra), never twice in a row.
        var dropped = Array(repeating: false, count: sylls.count)
        if dropsVowels {
            let n = sylls.count
            func unwritten(_ i: Int) -> Bool { sylls[i].vowel == nil && sylls[i].hasVowel && !sylls[i].consonants.isEmpty }
            if n > 1, unwritten(n - 1), sylls[n - 1].consonants.count == 1 { dropped[n - 1] = true }
            if n >= 3 {
                for i in stride(from: n - 2, through: 1, by: -1)
                where unwritten(i) && sylls[i].marks.isEmpty && !dropped[i + 1] && sylls[i + 1].hasVowel && !dropped[i - 1]
                    && sylls[i - 1].hasVowel && sylls[i].consonants.count == 1 && sylls[i + 1].consonants.count == 1 {
                    dropped[i] = true
                }
            }
        }
        var beam: [(String, Int)] = [("", 0)]
        func extend(_ options: [(String, Int)]) {
            var next: [String: Int] = [:]
            for (s, c) in beam { for (o, e) in options { let k = s + o; next[k] = min(next[k] ?? .max, c + e) } }
            beam = next.sorted { ($0.value, $0.key) < ($1.value, $1.key) }.prefix(12).map { ($0.key, $0.value) }
        }
        for (i, s) in sylls.enumerated() {
            var k = 0
            while k < s.consonants.count {
                let c = s.consonants[k]
                if k > 0, let tail = afterConsonant[c] {
                    // ্য, ্ব after a consonant: mostly the consonant doubled (dhonnobad).
                    let previous = letter(s.consonants[k - 1])?.first?.0 ?? ""
                    extend(tail.map { $0.0.isEmpty ? (previous, $0.1) : $0 })
                    k += 1
                    continue
                }
                let spelled = letter(c) ?? [("", 0)]
                if k + 1 < s.consonants.count, let next = letter(s.consonants[k + 1]),
                   c == s.consonants[k + 1] || Self.aspirated[c] == s.consonants[k + 1] {
                    // A doubled consonant (पक्का pakka) or one before its aspirate (अच्छा achchha): also
                    // written once (paka, achha) and, for च्छ, as cch (accha).
                    let options = c == 0x1A ? [("cch", 0), ("chh", 1), ("ch", 3), ("chchh", 4)]
                        : spelled.flatMap { a in next.map { b in (a.0 + b.0, a.1 + b.1) } } + next.map { ($0.0, $0.1 + 3) }
                    extend(options)
                    k += 2
                } else {
                    extend(spelled)
                    k += 1
                }
            }
            // e before a nasal is also written ei (में mein).
            if let v = s.vowel {
                var options = s.marks.isEmpty || v.first?.0 != "e" ? v : v + [("ei", 2)]
                // A vowel on its own after another vowel is also written with a y before it (लिए liye, गए gaye).
                if s.consonants.isEmpty, i > 0 { options += v.map { ("y" + $0.0, $0.1 + 1) } }
                extend(options)
            }
            else if s.hasVowel && !s.consonants.isEmpty {
                extend(dropped[i] ? [("", 0), (inherent[0].0, 6)] : inherent + [("", 6)])
            }
            for m in s.marks { extend(m) }
        }
        let best = beam.first?.1 ?? 0
        var seen = Set<String>()
        return beam.filter { !$0.0.isEmpty && $0.1 - best <= maxExtra && seen.insert($0.0).inserted }.prefix(limit).map { ($0.0, $0.1 - best) }
    }
}

/// How many words a language typed by sound keeps: fewer than the others, as its words take
/// three bytes a letter and come with several spellings.
let indicPackSize = 40_000

/// Aksharantar's pairs of a word and a Latin spelling people used (`{"native word": …, "english
/// word": …, "source": …}` per line), from the sources under CC0 (mined from IndicCorp and
/// Samanantar, Wikidata) and CC-BY (AK-Freq, collected by hand); not Dakshina's pairs, which come
/// from a dataset under CC-BY-SA, nor the other existing sources.
func readTransliterationPairs(_ url: URL) throws -> [String: [String]] {
    struct Pair: Decodable {
        let native: String, latin: String, source: String
        enum CodingKeys: String, CodingKey { case native = "native word", latin = "english word", source }
    }
    let allowed: Set<String> = ["IndicCorp", "Samanantar", "Wikidata", "AK-Freq"]
    var out: [String: [String]] = [:]
    let decoder = JSONDecoder()
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
        guard let p = try? decoder.decode(Pair.self, from: Data(line.utf8)), allowed.contains(p.source) else { continue }
        let latin = p.latin.lowercased()
        guard !latin.isEmpty, latin.allSatisfy({ $0 >= "a" && $0 <= "z" }) else { continue }
        out[p.native, default: []].append(latin)
    }
    return out
}

/// The number of single-letter edits from `a` to `b`.
func editDistance(_ a: String, _ b: String) -> Int {
    let a = Array(a), b = Array(b)
    var row = Array(0...b.count)
    for i in 1...max(a.count, 1) where !a.isEmpty {
        var prev = row[0]; row[0] = i
        for j in 1...max(b.count, 1) where !b.isEmpty {
            let cur = row[j]
            row[j] = min(row[j] + 1, row[j - 1] + 1, prev + (a[i - 1] == b[j - 1] ? 0 : 1))
            prev = cur
        }
    }
    return a.isEmpty ? b.count : row[b.count]
}

/// A language typed by sound: words and how often each is used from Common Voice's sentences,
/// then the other words of Aksharantar's pairs (the ones with more pairs first), each keyed by
/// its spellings from the script's table and the pairs' spellings close to them (a pair far from
/// every spelling the table makes, कैसे "how", is a translation, not a spelling).
func buildIndicPack(_ language: LanguagePacks.Language, script: IndicScript, texts: [String], pairs pairsFile: String,
                    sources: URL, out: URL) throws {
    let folder = sources.appendingPathComponent(language.rawValue)
    var counts: [String: Int] = [:]
    for name in texts {
        for line in try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8).split(separator: "\n") {
            for token in line.split(whereSeparator: { c in !c.unicodeScalars.allSatisfy { $0.value >= script.base && $0.value < script.base + 0x80 && !(0x64...0x6F).contains($0.value - script.base) } }) {
                counts[String(token), default: 0] += 1
            }
        }
    }
    let pairs = try readTransliterationPairs(folder.appendingPathComponent(pairsFile))
    var words = counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key)
    let known = Set(words)
    let fromSentences = words.count
    words += pairs.filter { !known.contains($0.key) && $0.value.count >= 2 }
        .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }.map(\.key)
    var table: [String: Int] = [:]   // "key<TAB>word" → cost
    var kept = 0
    for (i, word) in words.enumerated() where kept < indicPackSize {
        // Fewer spellings for the words only the pairs have: they are rarer.
        let made = script.spellings(word, limit: i < fromSentences ? 4 : 2)
        guard let first = made.first else { continue }
        kept += 1
        let cost = wordCost(rank: kept, key: first.0)
        var keys: [String: Int] = [:]
        for (k, extra) in made { keys[k] = extra }
        var used: [String: Int] = [:]
        for latin in pairs[word] ?? [] { used[latin, default: 0] += 1 }
        for (latin, _) in used.sorted(by: { $0.value > $1.value }).prefix(3)
        where keys[latin] == nil && made.contains(where: { editDistance($0.0, latin) <= max(2, latin.count / 3) }) {
            keys[latin] = 3
        }
        for (k, extra) in keys {
            let e = k + "\t" + word
            table[e] = min(table[e] ?? .max, cost + extra + (k.count <= 3 && first.0.count > 3 ? 10 : 0))
        }
    }
    log("\(language.rawValue): \(counts.count) words in the sentences, \(pairs.count) in the pairs, \(kept) kept, \(table.count) spellings")
    try writePack(table, name: language.fileName, to: out.appendingPathComponent(language.rawValue),
                  normalizeKey: { String($0) }, abbreviate: { _ in nil },
                  licenses: [("Mozilla Common Voice sentences: words and how often each is used (CC0 1.0)",
                              folder.appendingPathComponent("common-voice-LICENSE")),
                             ("AI4Bharat Aksharantar: Latin spellings of words (mined pairs CC0 1.0; pairs collected by hand CC BY 4.0, by AI4Bharat: Madhani et al., \"Aksharantar: Open Indic-language Transliteration datasets and models for the Next Billion Users\", 2023). Its dataset card:",
                              folder.appendingPathComponent("aksharantar-README.md"))])
}
