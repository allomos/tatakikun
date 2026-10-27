import Foundation
import TatakikunCore

// Language packs: one folder per language with its dictionary and the licenses of the data in it.
//   zh/zh.ttkd  words of the base Chinese dictionary (ICU frequencies), keyed by the readings of
//               pinyin-data (every character) and phrase-pinyin-data (whole words), plus words
//               only phrase-pinyin-data has (ranked by jieba's word frequencies when it has them),
//               and jieba's person names
//   ja/ja.ttkd  the base Japanese dictionary merged with the Mozc OSS dictionary, and its family
//               and given names under marked keys (姓おう 王, 名き 暉)
//   en/en.ttkd  SCOWL words, cheaper the more common their SCOWL level
//   es/es.ttkd, fr/fr.ttkd  the words of Common Voice's sentences, keyed without accents,
//               cheaper the more often they are used

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

/// jieba's person names (`李香琴 3 nr`) of 2–4 characters, with how often each was seen.
func readPersonNames(_ url: URL) throws -> [String: Int] {
    var out: [String: Int] = [:]
    for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
        let p = line.split(separator: " ")
        guard p.count == 3, p[2] == "nr", let n = Int(p[1]), n > 0, (2...4).contains(p[0].count), isAll(String(p[0]), Kana.isHan) else { continue }
        out[String(p[0])] = max(out[String(p[0])] ?? 0, n)
    }
    return out
}

/// What a person name adds to its jieba cost: most are seen only a few times, so they come after
/// the words and phrases typed the same way (lixiang 理想 before 李翔).
let personNameCost = 10

/// A word the base dictionary lacks, by its jieba frequency, on the base dictionary's scale: fitted on
/// the 68 000 words both have (cost ≈ 144 − 7.1 ln n), and never cheaper than 60 or dearer than 169,
/// so it stays ahead of the words with no frequency at all (重启 68 → 114, after 充气 94).
func cost(forFrequency n: Int) -> Int { min(169, max(60, Int((144 - 7.12 * log(Double(n))).rounded()))) }

/// Single characters by how often jieba sees each used as a word on its own, which says more about
/// typing it alone, and about it inside a spoken sentence, than its frequency inside other words
/// (过 is used alone 97 817 times, 国 29 996: 国 is mostly in 中国, 国家). The base dictionary's
/// costs for these characters are kept as a set and handed out again in jieba's order, so the
/// scale stays the same: the character jieba sees most gets the lowest cost (过 67 → 56, 国 63 → 62).
/// A character never becomes more than `maxCharacterCostRise` dearer: jieba undercounts a few of the
/// most common ones (的 31 would become 47 and fall behind で for de).
func singleCharacterCosts(base: [String: Int], frequencies: [String: Int]) -> [String: Int] {
    let both = base.keys.filter { $0.count == 1 && frequencies[$0] != nil }
    let costs = both.map { base[$0]! }.sorted()
    let byFrequency = both.sorted { (frequencies[$0]!, $1) > (frequencies[$1]!, $0) }
    return Dictionary(uniqueKeysWithValues: zip(byFrequency, costs).map { c, cost in (c, min(cost, base[c]! + maxCharacterCostRise)) })
}

let maxCharacterCostRise = 5

/// What a character's rare reading adds to a word's cost (活 guo: 74 + 60, after 锅 88 and 过了).
let rareReadingCost = 60

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
    /// Readings from the characters, each with what it adds to the word's cost: a character's first
    /// reading in pinyin-data and the others the polyphone table lists (行 hang, 重 chong) are common
    /// and cost little more; any other reading (活 guo, 遇 yong, 划 guo) is rare and costs
    /// `rareReadingCost`, so it never comes before the common words typed the same way.
    func characterReadings(_ word: String) -> [(sylls: [String], extra: Int)]? {
        var combos: [(sylls: [String], extra: Int)] = [([], 0)]
        for c in word {
            guard let rs = chars[c] else { return nil }
            let common = Set([rs[0]] + (polyphones[c] ?? []))
            combos = combos.flatMap { combo in
                rs.enumerated().map { i, r in
                    let extra = i == 0 ? 0 : common.contains(r) ? (word.count == 1 ? 8 : 5) : rareReadingCost
                    return (combo.sylls + [r], combo.extra + extra)
                }
            }
            combos.sort { $0.extra < $1.extra }
            if combos.count > 8 { combos = Array(combos.prefix(8)) }
        }
        return combos
    }

    let characterCosts = singleCharacterCosts(base: costs, frequencies: frequencies)
    for (word, base) in costs {
        let cost = min(characterCosts[word] ?? base, spokenChinese[word] ?? .max)
        if let sylls = phrases[word] {
            add(sylls, word, cost)
        } else if let readings = characterReadings(word) {
            // A single character has all its readings; a longer word not in phrase-pinyin-data
            // has the combinations, the most likely one first.
            for r in readings { add(r.sylls, word, cost + r.extra) }
        }
    }
    // Words only phrase-pinyin-data has: by jieba's frequency when it has them (重启), otherwise
    // after every word with a frequency.
    let simplified = { (w: String) in w.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? w }
    for (word, sylls) in phrases where costs[word] == nil && simplified(word) == word {
        add(sylls, word, frequencies[word].map(cost(forFrequency:)) ?? 170 + 10 * max(0, word.count - 2))
    }
    // Person names only jieba has (李香琴), read by their characters.
    let names = try readPersonNames(zh.appendingPathComponent("jieba-dict.txt"))
    var nameCount = 0
    for (word, n) in names where costs[word] == nil && phrases[word] == nil && simplified(word) == word {
        guard let readings = characterReadings(word) else { continue }
        for r in readings { add(r.sylls, word, cost(forFrequency: n) + personNameCost + r.extra) }
        nameCount += 1
    }
    log("zh: \(nameCount) person names from jieba")
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
/// A kanji's reading only the single kanji table has: after the dictionaries' words for it.
let singleKanjiCost = 140

/// Mozc's part-of-speech ids (its id.def at the pinned commit) of verbs and adjectives in their
/// dictionary form, by how they conjugate (see `Conjugation`). Left out: the 非自立 ones (いく after
/// て, kept as plain words), 問う-like verbs, いい (良い conjugates for it) and classical forms.
let conjugationClasses: [Substring: Conjugation.Class] = {
    var c: [Substring: Conjugation.Class] = [:]
    for id in [680, 681, 682, 683, 684, 685, 686, 713, 719] { c[Substring(String(id))] = .ichidan }  // 一段
    for id in [723, 763, 764, 765, 766, 813, 814, 815, 816, 837] { c[Substring(String(id))] = .godan }  // 五段
    for id in [731, 739] { c[Substring(String(id))] = .iku }  // 五段・カ行促音便
    c["791"] = .honorific  // 五段・ラ行特殊
    for id in [590, 591, 609, 610] { c[Substring(String(id))] = .kuru }  // カ変
    for id in [621, 633] { c[Substring(String(id))] = .suru }  // サ変
    for id in [2425, 2426, 2427, 2428, 2429, 2467] { c[Substring(String(id))] = .adjective }  // 形容詞
    return c
}()

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
    var nameParts: [String: Int] = [:]  // "姓おう<TAB>王" or "名き<TAB>暉" → cost
    var conjugating: [String: (key: String, raw: Int)] = [:]  // "かく<TAB>書く" → "活五かく", raw cost
    for i in 0...9 {
        let url = ja.appendingPathComponent("dictionary0\(i).txt")
        for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
            // reading <TAB> left id <TAB> right id <TAB> cost <TAB> word
            let p = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard p.count >= 5, let c = Int(p[3]), !p[0].isEmpty, !p[4].isEmpty, p[4].count <= 16,
                  p[0].unicodeScalars.allSatisfy(Kana.isHiragana),
                  !p[4].unicodeScalars.contains(where: { $0.isASCII && CharacterSet.letters.contains($0) }) else { continue }
            let k = String(p[0]) + "\t" + String(p[4])
            // Family names (Mozc's id 1923) and given names (1922) of one to three kanji, for whole
            // names no dictionary has (王暉): the engine puts one of each together.
            if let mark = p[1] == "1923" ? JapaneseConverter.familyNameMark : p[1] == "1922" ? JapaneseConverter.givenNameMark : nil,
               c > 0, (1...3).contains(p[4].count), isAll(String(p[4]), Kana.isHan) {
                let n = mark + k
                nameParts[n] = min(nameParts[n] ?? .max, c / 40)
            }
            if let type = conjugationClasses[p[1]], !(conjugating[k].map { $0.raw <= c } ?? false) {
                conjugating[k] = (Conjugation.key(type, String(p[0])), c)
            }
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
    // Every reading of every kanji (Mozc's single kanji table: かい 介 亥 会 … 懐): after the words
    // the dictionaries have, in the table's order, so any kanji can be typed by its reading.
    var singleKanji = 0
    for line in try String(contentsOf: ja.appendingPathComponent("single_kanji.tsv"), encoding: .utf8).split(separator: "\n") {
        let p = line.split(separator: "\t")
        guard p.count == 2, p[0].unicodeScalars.allSatisfy(Kana.isHiragana) else { continue }
        for (i, c) in p[1].enumerated() where isAll(String(c), Kana.isHan) {
            let k = String(p[0]) + "\t" + String(c)
            if table[k] == nil { table[k] = singleKanjiCost + min(i, 100) / 4; singleKanji += 1 }
        }
    }
    log("ja: \(baseCount) base entries, \(mozcRaw.count) Mozc pairs, \(table.count) together, \(singleKanji) from the single kanji table, \(nameParts.count) name parts")
    table.merge(nameParts) { a, _ in a }
    // Verbs and adjectives once more under their class, at the cost of the plain word.
    for (k, v) in conjugating {
        table[v.key + "\t" + k.split(separator: "\t")[1]] = table[k] ?? 70 + v.raw / 40
    }
    log("ja: \(conjugating.count) verbs and adjectives that conjugate")
    let isNamePart = { (k: Substring) in
        k.hasPrefix(JapaneseConverter.familyNameMark) || k.hasPrefix(JapaneseConverter.givenNameMark) || k.hasPrefix(Conjugation.mark)
    }
    try writePack(table, name: DictionaryFiles.japanese, to: out.appendingPathComponent("ja"),
                  normalizeKey: { String($0) }, abbreviate: { isNamePart($0) ? nil : Abbreviation.kana($0) },
                  licenses: [("Mozc OSS dictionary (its README, with the IPAdic and Okinawa dictionary licenses)", ja.appendingPathComponent("README.txt")),
                             ("Mozc single kanji table (BSD 3-Clause)", ja.appendingPathComponent("mozc-LICENSE")),
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

// MARK: Languages typed word by word

/// How many words a word language's pack keeps, the most used first.
let wordPackSize = 50_000

/// A word seen fewer times than this is left out (typos, one-off names).
let wordPackMinCount = 3

/// The cost of the word used `rank`th most often (1 = most), on the English pack's scale: the most
/// common words cost about as much as SCOWL's most common (40), the 50 000th about 100. Words of
/// three letters or fewer cost 10 more, as in English: they collide with pinyin and romaji most.
func wordCost(rank: Int, key: String) -> Int {
    Int((40 + 5.5 * log(Double(rank))).rounded()) + (key.count <= 3 ? 10 : 0)
}

/// Counts the words of a language's sentences (Common Voice, one sentence per line) and keys each
/// by the letters that type it (WordConverter.key). A word is spelled as it is mostly written: a
/// name keeps its capital (Madrid), other words are lowercase even at the start of a sentence.
/// A word with an elided start (l'école, c'est) counts as itself and as the word after the
/// apostrophe (école), so both can be typed (lecole, ecole).
/// - Parameter letters: the lowercase letters the language writes; words with others are left out.
/// - Parameter singleLetters: the one-letter words the language has.
func buildWordPack(_ language: LanguagePacks.Language, texts: [String], letters: String, singleLetters: Set<String>,
                   sources: URL, out: URL) throws {
    let folder = sources.appendingPathComponent(language.rawValue)
    let alphabet = Set(letters)
    var counts: [String: Int] = [:]          // spelling → times seen (not first in its sentence)
    var firstCounts: [String: Int] = [:]     // lowercase spelling → times seen first in a sentence
    for name in texts {
        for line in try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8).split(separator: "\n") {
            var first = true
            for token in line.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "’" && $0 != "-" }) {
                let whole = String(token).replacingOccurrences(of: "’", with: "'").trimmingCharacters(in: CharacterSet(charactersIn: "'-"))
                defer { first = false }
                var words = [whole]
                if let tail = whole.split(separator: "'").last, tail.count >= 2, tail.count < whole.count - 1 { words.append(String(tail)) }
                for word in words {
                    let lower = word.lowercased()
                    guard !word.isEmpty, word.count <= 24, lower.allSatisfy({ alphabet.contains($0) || "'-".contains($0) }),
                          word.count == 1 ? singleLetters.contains(lower) : word != word.uppercased() else { continue }
                    if first { firstCounts[lower, default: 0] += 1 } else { counts[word, default: 0] += 1 }
                }
            }
        }
    }
    // One spelling per word: lowercase unless the capitalized one is seen more (Madrid, not madrid).
    var spelled: [String: Int] = [:]
    for (word, n) in counts where word == word.lowercased() { spelled[word] = n + (firstCounts[word] ?? 0) }
    for (word, n) in counts where word != word.lowercased() {
        let lower = word.lowercased()
        if n > (spelled[lower] ?? 0) { spelled[lower] = nil; spelled[word] = n + (firstCounts[lower] ?? 0) }
    }
    let ranked = spelled.filter { $0.value >= wordPackMinCount }.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(wordPackSize)
    var table: [String: Int] = [:]   // "key<TAB>word" → cost
    for (i, (word, _)) in ranked.enumerated() {
        let key = WordConverter.key(word)
        guard !key.isEmpty else { continue }
        table[key + "\t" + word] = wordCost(rank: i + 1, key: key)
    }
    log("\(language.rawValue): \(spelled.count) words, \(table.count) kept")
    try writePack(table, name: language.fileName, to: out.appendingPathComponent(language.rawValue),
                  normalizeKey: { String($0) }, abbreviate: { _ in nil },
                  licenses: [("Mozilla Common Voice sentences: words and how often each is used (CC0 1.0)",
                              folder.appendingPathComponent("common-voice-LICENSE"))])
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
