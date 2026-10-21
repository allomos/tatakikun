import Foundation
import TatakikunCore

// Language packs: one folder per language with its dictionary and the licenses of the data in it.
//   zh/zh.ttkd  words of the base Chinese dictionary (ICU frequencies), keyed by the readings of
//               pinyin-data (every character) and phrase-pinyin-data (whole words), plus words
//               only phrase-pinyin-data has (ranked by jieba's word frequencies when it has them)
//   ja/ja.ttkd  the base Japanese dictionary merged with the Mozc OSS dictionary
//   en/en.ttkd  SCOWL words, cheaper the more common their SCOWL level

/// Words above this cost are left out of the abbreviation index, so typing consonants alone
/// (nh, wtx) offers common words rather than every rare one.
let abbreviationCostLimit = 160

// MARK: Chinese

/// Toneless pinyin with ü written as v (zhōng → zhong, lǜ → lv), or nil when it is not plain letters.
func toneless(_ syllable: Substring) -> String? {
    var s = String(syllable).lowercased().replacingOccurrences(of: "[üǖǘǚǜ]", with: "v", options: .regularExpression)
    s = s.applyingTransform(.stripDiacritics, reverse: false) ?? s
    return !s.isEmpty && s.allSatisfy({ $0 >= "a" && $0 <= "z" }) ? s : nil
}

/// pinyin-data's pinyin.txt: `U+4E2D: zhōng,zhòng  # 中` → 中: [zhong] (most common reading first).
func readCharacterReadings(_ url: URL) throws -> [Character: [String]] {
    var out: [Character: [String]] = [:]
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") where line.hasPrefix("U+") {
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let code = UInt32(parts[0].dropFirst(2), radix: 16), let scalar = Unicode.Scalar(code) else { continue }
        let readings = parts[1].split(separator: "#")[0].split(separator: ",")
            .compactMap { toneless(Substring($0.trimmingCharacters(in: .whitespaces))) }
        var unique: [String] = []
        for r in readings where !unique.contains(r) { unique.append(r) }
        if !unique.isEmpty { out[Character(scalar)] = unique }
    }
    return out
}

/// phrase-pinyin-data's large_pinyin.txt: `银行: yín háng` → 银行: [yin, hang].
func readPhraseReadings(_ url: URL) throws -> [String: [String]] {
    var out: [String: [String]] = [:]
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") where !line.hasPrefix("#") {
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { continue }
        let word = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let sylls = parts[1].split(separator: "#")[0].split(separator: " ").compactMap(toneless)
        guard word.count <= maxWordLength, isAll(word, Kana.isHan), sylls.count == word.count, out[word] == nil else { continue }
        out[word] = sylls
    }
    return out
}

/// Each word's lowest cost in a `key<TAB>word<TAB>cost` file.
func readWordCosts(_ url: URL) throws -> [String: Int] {
    var out: [String: Int] = [:]
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
        let p = line.split(separator: "\t")
        guard p.count == 3, let c = Int(p[2]) else { continue }
        let w = String(p[1])
        out[w] = min(out[w] ?? c, c)
    }
    return out
}

/// jieba's dict.txt: `重启 68 v` → 重启: 68 (how often the word was seen).
func readWordFrequencies(_ url: URL) throws -> [String: Int] {
    var out: [String: Int] = [:]
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
        let p = line.split(separator: " ")
        guard p.count >= 2, let n = Int(p[1]), n > 0 else { continue }
        out[String(p[0])] = max(out[String(p[0])] ?? 0, n)
    }
    return out
}

/// A word the base dictionary lacks, by its jieba frequency, on the base dictionary's scale: fitted on
/// the 68 000 words both have (cost ≈ 144 − 7.1 ln n), and never cheaper than 60 or dearer than 169,
/// so it stays ahead of the words with no frequency at all (重启 68 → 114, after 充气 94).
func cost(forFrequency n: Int) -> Int { min(169, max(60, Int((144 - 7.12 * log(Double(n))).rounded()))) }

func buildChinesePack(base: URL, sources: URL, out: URL) throws {
    let zh = sources.appendingPathComponent("zh")
    let chars = try readCharacterReadings(zh.appendingPathComponent("pinyin.txt"))
    let phrases = try readPhraseReadings(zh.appendingPathComponent("large_pinyin.txt"))
    let costs = try readWordCosts(base.appendingPathComponent("zh.tsv"))
    let frequencies = try readWordFrequencies(zh.appendingPathComponent("jieba-dict.txt"))
    log("zh: \(chars.count) characters, \(phrases.count) phrases, \(costs.count) words with frequencies, \(frequencies.count) in jieba")

    var table: [String: Int] = [:]   // "syll'syll<TAB>word" → cost
    func add(_ sylls: [String], _ word: String, _ cost: Int) {
        let k = sylls.joined(separator: "'") + "\t" + word
        table[k] = min(table[k] ?? cost, cost)
    }
    /// Readings from the characters: the most common reading of each first, then other combinations.
    func characterReadings(_ word: String) -> [[String]]? {
        var combos: [[String]] = [[]]
        for c in word {
            guard let rs = chars[c] else { return nil }
            combos = combos.flatMap { combo in rs.map { combo + [$0] } }
            if combos.count > 8 { combos = Array(combos.prefix(8)) }
        }
        return combos
    }

    for (word, cost) in costs {
        if let sylls = phrases[word] {
            add(sylls, word, cost)
        } else if let readings = characterReadings(word) {
            // A single character has all its readings; a longer word not in phrase-pinyin-data
            // has the combinations, the most likely one first.
            for (i, r) in readings.enumerated() { add(r, word, cost + (i == 0 ? 0 : (word.count == 1 ? 8 : 5))) }
        }
    }
    // Words only phrase-pinyin-data has: by jieba's frequency when it has them (重启), otherwise
    // after every word with a frequency.
    let simplified = { (w: String) in w.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? w }
    for (word, sylls) in phrases where costs[word] == nil && simplified(word) == word {
        add(sylls, word, frequencies[word].map(cost(forFrequency:)) ?? 170 + 10 * max(0, word.count - 2))
    }
    try writePack(table, name: DictionaryFiles.chinese, to: out.appendingPathComponent("zh"),
                  normalizeKey: DictionaryFiles.pinyinKey, abbreviate: Abbreviation.pinyin,
                  licenses: [("pinyin-data (MIT)", zh.appendingPathComponent("pinyin-data-LICENSE")),
                             ("phrase-pinyin-data (MIT)", zh.appendingPathComponent("phrase-pinyin-data-LICENSE")),
                             ("jieba: word frequencies (MIT)", zh.appendingPathComponent("jieba-LICENSE")),
                             ("ICU data: word frequencies (Unicode License V3)", sources.appendingPathComponent("icu-LICENSE"))])
}

// MARK: Japanese

/// Mozc's raw costs (0–18000, lower is more common) compare well only within one part of speech:
/// grammatical entries cost 0 (合い, へん) and 相 comes out "more common" than 愛. So the base
/// dictionary's frequencies stay in charge, and Mozc fills the gaps:
/// - a pair the base dictionary has keeps its cost;
/// - another common reading (raw cost ≤ 4000) of a word the base dictionary has costs that word's
///   cost + 5 (私 わたくし 56 → 私 わたし 61);
/// - a word only Mozc has costs 70 + raw/40, after known words of similar commonness;
/// - raw cost 0 entries are ignored unless that is all there is (then 120), surfaces with Latin
///   letters (TOKYO) are left out, and all-hiragana surfaces cost 10 more (the kana are offered anyway).
func buildJapanesePack(base: URL, sources: URL, out: URL) throws {
    let ja = sources.appendingPathComponent("ja")
    var table: [String: Int] = [:]   // "reading<TAB>word" → cost
    var wordCost: [String: Int] = [:]
    for line in try String(contentsOf: base.appendingPathComponent("ja.tsv"), encoding: .utf8).split(separator: "\n") {
        let p = line.split(separator: "\t")
        guard p.count == 3, let c = Int(p[2]) else { continue }
        table[String(p[0]) + "\t" + String(p[1])] = c
        wordCost[String(p[1])] = min(wordCost[String(p[1])] ?? c, c)
    }
    let baseCount = table.count
    var mozcRaw: [String: Int] = [:]   // lowest non-zero raw cost per pair; 0 when only zeros
    for i in 0...9 {
        let url = ja.appendingPathComponent("dictionary0\(i).txt")
        for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
            // reading <TAB> left id <TAB> right id <TAB> cost <TAB> word
            let p = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard p.count >= 5, let c = Int(p[3]), !p[0].isEmpty, !p[4].isEmpty, p[4].count <= 16,
                  p[0].unicodeScalars.allSatisfy(Kana.isHiragana),
                  !p[4].unicodeScalars.contains(where: { $0.isASCII && CharacterSet.letters.contains($0) }) else { continue }
            let k = String(p[0]) + "\t" + String(p[4])
            if let old = mozcRaw[k] { mozcRaw[k] = old == 0 ? c : (c == 0 ? old : min(old, c)) } else { mozcRaw[k] = c }
        }
    }
    for (k, raw) in mozcRaw where table[k] == nil {
        let word = String(k.split(separator: "\t")[1])
        var cost: Int
        if let known = wordCost[word], raw > 0, raw <= 4000 { cost = known + 5 }
        else { cost = raw == 0 ? 120 : 70 + raw / 40 }
        if word.unicodeScalars.allSatisfy(Kana.isHiragana) { cost += 10 }
        table[k] = cost
    }
    log("ja: \(baseCount) base entries, \(mozcRaw.count) Mozc pairs, \(table.count) together")
    try writePack(table, name: DictionaryFiles.japanese, to: out.appendingPathComponent("ja"),
                  normalizeKey: { String($0) }, abbreviate: Abbreviation.kana,
                  licenses: [("Mozc OSS dictionary (its README, with the IPAdic and Okinawa dictionary licenses)", ja.appendingPathComponent("README.txt")),
                             ("ICU data: word list and frequencies (Unicode License V3)", sources.appendingPathComponent("icu-LICENSE"))])
}

// MARK: English

/// SCOWL size levels (10 = most common) → cost. Levels 80 and 95 (rare and obscure words) are left out.
let scowlCosts: [Int: Int] = [10: 40, 20: 50, 35: 60, 40: 65, 50: 75, 55: 85, 60: 95, 70: 110]

func buildEnglishPack(sources: URL, out: URL) throws {
    let final = sources.appendingPathComponent("en/scowl/final")
    // Lowercase words, American spellings, contractions; capitalized words and names cost a little more.
    let lists: [(prefix: String, extra: Int)] = [
        ("english-words", 0), ("american-words", 0), ("english-contractions", 0),
        ("english-upper", 10), ("american-upper", 10), ("english-proper-names", 20), ("american-proper-names", 20),
    ]
    var table: [String: Int] = [:]   // "key<TAB>word" → cost
    for (prefix, extra) in lists {
        for (level, cost) in scowlCosts {
            let url = final.appendingPathComponent("\(prefix).\(level)")
            guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .isoLatin1) else { continue }
            for w in text.split(separator: "\n") {
                // Typed as letters only: don't is typed dont, Tokyo is typed tokyo.
                guard w.allSatisfy({ ($0.isASCII && $0.isLetter) || $0 == "'" }), !w.hasSuffix("'s") else { continue }
                let key = w.lowercased().filter { $0 != "'" }
                guard !key.isEmpty else { continue }
                let k = key + "\t" + w
                table[k] = min(table[k] ?? Int.max, cost + extra)
            }
        }
    }
    log("en: \(table.count) words")
    try writePack(table, name: "en.ttkd", to: out.appendingPathComponent("en"),
                  normalizeKey: { String($0) }, abbreviate: { _ in nil },
                  licenses: [("SCOWL (Spell Checker Oriented Word Lists)", sources.appendingPathComponent("en/scowl/Copyright"))])
}

// MARK: Writing a pack

func writePack(_ table: [String: Int], name: String, to folder: URL,
               normalizeKey: (Substring) -> String, abbreviate: (Substring) -> String?,
               licenses: [(String, URL)]) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var entries: [LexiconEntry] = []
    var abbreviated: [(abbreviation: String, entry: LexiconEntry)] = []
    entries.reserveCapacity(table.count)
    for (k, cost) in table {
        let p = k.split(separator: "\t", maxSplits: 1)
        guard p.count == 2 else { continue }
        let e = LexiconEntry(key: normalizeKey(p[0]), word: String(p[1]), cost: cost)
        entries.append(e)
        if cost <= abbreviationCostLimit, let a = abbreviate(p[0]) { abbreviated.append((a, e)) }
    }
    try Lexicon.write(entries: entries, abbreviated: abbreviated, to: folder.appendingPathComponent(name))
    var text = "Tatakikun language pack: \(folder.lastPathComponent)\n\nThis dictionary is built from the data below, under these terms.\n"
    for (title, url) in licenses {
        text += "\n" + String(repeating: "=", count: 72) + "\n" + title + "\n" + String(repeating: "=", count: 72) + "\n\n"
        text += (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1)) ?? ""
    }
    try text.write(to: folder.appendingPathComponent("LICENSE.txt"), atomically: true, encoding: .utf8)
    log("\(folder.lastPathComponent)/\(name): \(entries.count) entries, \(abbreviated.count) abbreviations")
}
