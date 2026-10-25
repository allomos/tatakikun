import Foundation
import TatakikunCore

// Arabic typed in Arabizi, the Latin letters and digits people chat in (marhaba مرحبا, 7abibi
// حبيبي, shukran شكرا). Arabic does not write its short vowels, and Arabizi writes them as it
// likes, so a word is keyed by its skeleton: its consonants as Arabizi spells them, and its long
// vowels as A (ا ى), U (و) and I (ي). The engine turns what was typed into the same skeletons
// (WordConverter.arabiziKeys), each vowel typed either a long vowel or a short one.

/// Each Arabic letter's Arabizi spellings, the usual one first, with what each adds to the cost.
let arabizi: [Character: [(String, Int)]] = [
    "ا": [("A", 0)], "أ": [("A", 0), ("2", 1), ("I", 1), ("U", 1)], "إ": [("I", 0), ("2", 1)], "آ": [("A", 0), ("2A", 1)],
    "ء": [("2", 0), ("", 1)], "ؤ": [("U", 0), ("2", 1)], "ئ": [("I", 0), ("2", 1)],
    "ب": [("b", 0)], "ت": [("t", 0)], "ث": [("th", 0), ("s", 1), ("t", 2)], "ج": [("j", 0), ("g", 1)],
    "ح": [("7", 0), ("h", 1)], "خ": [("kh", 0), ("5", 2), ("7", 3)], "د": [("d", 0)],
    "ذ": [("th", 0), ("dh", 1), ("z", 1), ("d", 2)], "ر": [("r", 0)], "ز": [("z", 0)], "س": [("s", 0)],
    "ش": [("sh", 0), ("ch", 1)], "ص": [("s", 0), ("9", 1)], "ض": [("d", 0), ("dh", 1), ("9", 2)],
    "ط": [("t", 0), ("6", 1)], "ظ": [("z", 0), ("dh", 1), ("6", 2)], "ع": [("3", 0), ("A", 1)],
    "غ": [("gh", 0), ("3", 2)], "ف": [("f", 0)], "ق": [("q", 0), ("2", 1), ("k", 1), ("g", 2), ("8", 3)],
    "ك": [("k", 0)], "ل": [("l", 0)], "م": [("m", 0)], "ن": [("n", 0)], "ه": [("h", 0)],
    "و": [("w", 0), ("U", 0)], "ي": [("y", 0), ("I", 0)], "ى": [("A", 0)], "ة": [("A", 0), ("", 1), ("h", 2)],
]

/// A word's Arabizi skeletons (see above), the most usual first, each with what it adds to its
/// cost: at most `limit`. A final ا is also -an (شكرا shukran) and a final ه is also left out (والله walla).
func arabiziSpellings(_ word: String, limit: Int = 6) -> [(String, Int)] {
    var beam: [(String, Int)] = [("", 0)]
    let letters = Array(word)
    for (i, c) in letters.enumerated() {
        guard var options = arabizi[c] else { return [] }
        // و and ي between consonants are mostly vowels (حبيبي 7abibi), elsewhere consonants (يوم yawm).
        if c == "و" || c == "ي", i > 0, arabizi[letters[i - 1]]?.first?.0.first?.isLowercase == true || arabizi[letters[i - 1]]?.first?.0.first?.isNumber == true {
            options = c == "و" ? [("U", 0), ("w", 1)] : [("I", 0), ("y", 1)]
        }
        if i == letters.count - 1, i > 0 {
            if c == "ا" { options.append(("An", 1)) }
            if c == "ه" { options.append(("", 2)) }
        }
        var next: [String: Int] = [:]
        for (s, cost) in beam { for (o, extra) in options { let k = s + o; next[k] = min(next[k] ?? .max, cost + extra) } }
        beam = next.sorted { ($0.value, $0.key) < ($1.value, $1.key) }.prefix(16).map { ($0.key, $0.value) }
    }
    return Array(beam.filter { $0.0.contains(where: \.isLowercase) || $0.0.contains(where: \.isNumber) }.prefix(limit))
}

/// What Arabic words cost on top of their frequency: a skeleton matches more than one way of
/// typing, so Arabic comes after the other languages' words typed the same way, until it leads
/// (momentum, after an Arabic word).
let arabicCost = 20

/// How many Arabic words the pack keeps (most used first): with several skeletons each, this keeps
/// the pack near 2 MB; Common Voice's Arabic text has few words seen more than once anyway.
let arabicPackSize = 20_000

func buildArabicPack(sources: URL, out: URL) throws {
    let folder = sources.appendingPathComponent("ar")
    var counts: [String: Int] = [:]
    for line in try String(contentsOf: folder.appendingPathComponent("sentence-collector.txt"), encoding: .utf8).split(separator: "\n") {
        // Harakat, shadda and tatweel are left out: words are typed and offered without them.
        let plain = String(line.unicodeScalars.filter { !(0x64B...0x652).contains($0.value) && $0.value != 0x640 && $0.value != 0x670 }.map(Character.init))
        for token in plain.split(whereSeparator: { arabizi[$0] == nil }) where token.count >= 1 {
            counts[String(token), default: 0] += 1
        }
    }
    let ranked = counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
    var table: [String: Int] = [:]
    var kept = 0
    for (word, _) in ranked where kept < arabicPackSize {
        let spelled = arabiziSpellings(word, limit: 4)
        guard let first = spelled.first else { continue }
        kept += 1
        let cost = wordCost(rank: kept, key: first.0) + arabicCost
        for (k, extra) in spelled {
            let e = k + "\t" + word
            table[e] = min(table[e] ?? .max, cost + extra)
        }
    }
    log("ar: \(counts.count) words, \(kept) kept, \(table.count) skeletons")
    try writePack(table, name: LanguagePacks.Language.ar.fileName, to: out.appendingPathComponent("ar"),
                  normalizeKey: { String($0) }, abbreviate: { _ in nil },
                  licenses: [("Mozilla Common Voice sentences: words and how often each is used (CC0 1.0)",
                              folder.appendingPathComponent("common-voice-LICENSE"))])
}
