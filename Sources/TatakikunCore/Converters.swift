#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What kind of candidate this is; the candidate bar shows it as a small tag.
public enum CandidateKind: String, CaseIterable {
    case english, chinese, kanji, hiragana, katakana, spanish, french, hindi, raw

    public var tag: String {
        switch self {
        case .english: return "EN"
        case .chinese: return "中"
        case .kanji: return "日"
        case .hiragana: return "あ"
        case .katakana: return "ア"
        case .spanish: return "ES"
        case .french: return "FR"
        case .hindi: return "हि"
        case .raw: return "abc"
        }
    }

    /// The language pack a word language's candidates come from (WordConverter); nil for the others.
    public var pack: LanguagePacks.Language? {
        switch self {
        case .spanish: return .es
        case .french: return .fr
        case .hindi: return .hi
        default: return nil
        }
    }
}

public struct Candidate: Equatable {
    public let text: String
    public let kind: CandidateKind
    /// Lower is better; comparable across languages.
    public let cost: Int
    /// False for candidates that do not match all of what was typed (shown when expanded).
    public var isExact: Bool = true
    /// How many typed letters this candidate stands for, when it covers only the start of the input;
    /// choosing it leaves the rest of the letters to go on typing. Nil means all of them.
    public var consumed: Int?
    /// True for kana spelled out from the letters with no dictionary word behind them (にはお for nihao).
    public var isGuess = false
    /// True for a word read with one letter moved to a neighbouring key (nihai → 你好).
    public var isSlip = false

    public init(text: String, kind: CandidateKind, cost: Int, isExact: Bool = true, consumed: Int? = nil) {
        self.text = text; self.kind = kind; self.cost = cost; self.isExact = isExact; self.consumed = consumed
    }
}

extension Candidate {
    /// The same candidate at another cost.
    func costing(_ cost: Int) -> Candidate {
        var c = Candidate(text: text, kind: kind, cost: cost, isExact: isExact, consumed: consumed)
        c.isGuess = isGuess
        c.isSlip = isSlip
        return c
    }
}

enum Cost {
    /// Added per word after the first, so fewer longer words beat many short ones; not for the
    /// particles of spoken sentences (你用过了吗: 过, 了, 吗), which come as single characters.
    static let perWord = 10
    static let particles: Set<String> = ["了", "过", "着", "的", "地", "得", "吗", "呢", "吧", "啊", "呀", "嘛", "哦", "啦"]
    static func perWord(_ word: String) -> Int { particles.contains(word) ? 0 : perWord }
    /// A kana with no dictionary word, passed through as itself.
    static let unknownKana = 150
    /// Added to a word that only completes what was typed (zhongg → 中国).
    static let completion = 40
    /// Added to a word that covers only the start of what was typed (nihaoma → 你好, then ma).
    static let leadingWord = 70
    /// Added to a word typed by its consonants alone (nh → 你好).
    static let abbreviation = 50
    /// Added on top for Japanese: dropping every vowel of a reading leaves more words alike.
    static let kanaAbbreviation = 20
    /// How many leading words of each length to offer among the others; every other single
    /// character for the start comes after them at `leadingCharacter` more, so any word can be put
    /// together one character at a time (houtokukai: 彭 for ほう, then 徳, then 懐).
    static let leadingPerLength = 3
    static let leadingCharacter = 60
    /// A word the user built by hand (CustomWords): near the top, after the most common words.
    static let customWord = 40
    /// What a Japanese family name and given name put together start from (see `fullNames`), and
    /// how many of them to offer.
    static let fullName = 90
    static let fullNames = 12
    /// How many whole-sentence candidates to offer.
    static let sentences = 3
    /// Added to a word or sentence read with two neighbouring letters swapped back (zhogn → 中).
    static let swapped = 40
    /// Added to a word or sentence read with one letter on a neighbouring key (nihai → 你好), and
    /// how many such candidates to offer.
    static let nearbyKey = 50
    static let nearbyKeyWords = 8
    /// Added to what a letter too many, too few or two letters swapped give (nihaoo, nhao, nihoa → 你好).
    static let otherSlip = 55
    /// Added to a slip in another language than the best reading of the letters as typed (nihai:
    /// 你好 before にない, after 你还).
    static let slipOtherLanguage = 20
    /// A sentence read after a slip is offered only when it costs this much or less per letter typed
    /// (我在学习 16, 今天七天很好 14; 啊日伽头 37).
    static let slipSentenceLetter = 25
    /// Sentences are read after a slip only for inputs up to this long (it takes too long after that).
    static let slipSentenceLetters = 16
    /// A letter left out is looked for only in inputs up to this long.
    static let leftOutLetters = 10
    /// At most this many of them in the first row, one when the letters as typed give words, so they
    /// never crowd out what was typed (ouki → 王暉).
    static let nearbyKeyWordsInRow = 2
}

/// Lowest-cost way to cover `units` with dictionary words (Viterbi).
/// With `unknownCost`, a unit no word covers may stand for itself at that cost.
func segment(_ units: [Character], lexicon: Lexicon, unknownCost: Int? = nil) -> (words: [String], cost: Int)? {
    segmentations(units, lexicon: lexicon, unknownCost: unknownCost, count: 1).first
}

/// The `count` lowest-cost ways to cover `units` with dictionary words, cheapest first, each a
/// different text (chongqizhiqian → 充气之前, 重启之前…): Viterbi keeping the best `count` paths
/// to every position, trying each span's `count` cheapest words.
func segmentations(_ units: [Character], lexicon: Lexicon, unknownCost: Int? = nil, count: Int) -> [(words: [String], cost: Int)] {
    let n = units.count
    guard n > 0, count > 0 else { return [] }
    // Twice as many paths as asked for: different splits of the same text (之前, 之+前) take a place each.
    let k = 2 * count
    // paths[j]: the cheapest ways found to cover units[0..<j]: cost, where the last word starts,
    // which path there it continues, and the word.
    typealias Step = (cost: Int, from: Int, path: Int, word: String)
    var paths = [[Step]](repeating: [], count: n + 1)
    paths[0] = [(0, 0, 0, "")]
    func offer(_ step: Step, at j: Int) {
        guard paths[j].count < k || step.cost < paths[j][k - 1].cost else { return }
        let at = paths[j].firstIndex { $0.cost > step.cost } ?? paths[j].count
        paths[j].insert(step, at: at)
        if paths[j].count > k { paths[j].removeLast() }
    }
    for i in 0..<n where !paths[i].isEmpty {
        for j in (i + 1)...min(n, i + lexicon.maxKeyLength) {
            let words = lexicon.exact(String(units[i..<j])).prefix(k)
            guard !words.isEmpty else { continue }
            for (p, before) in paths[i].enumerated() {
                for e in words { offer((before.cost + e.cost + (i == 0 ? 0 : Cost.perWord(e.word)), i, p, e.word), at: j) }
            }
        }
        if let u = unknownCost {
            for (p, before) in paths[i].enumerated() { offer((before.cost + u, i, p, String(units[i])), at: i + 1) }
        }
    }
    var out: [(words: [String], cost: Int)] = []
    for end in paths[n] {
        var words: [String] = []
        var (j, step) = (n, end)
        while j > 0 {
            words.append(step.word)
            (j, step) = (step.from, paths[step.from][step.path])
        }
        words.reverse()
        if !out.contains(where: { $0.words.joined() == words.joined() }) { out.append((words, end.cost)) }
    }
    return Array(out.prefix(count))
}

/// The most common words with any of these abbreviations.
func abbreviated(_ keys: [String], in lexicon: Lexicon, limit: Int, extraCost: Int = 0,
                 kind: (String) -> CandidateKind) -> [Candidate] {
    keys.flatMap { lexicon.abbreviated($0).prefix(limit) }
        .sorted { $0.cost < $1.cost }
        .prefix(limit)
        .map { Candidate(text: $0.word, kind: kind($0.word), cost: $0.cost + Cost.abbreviation + extraCost) }
}

/// Pinyin letters → simplified Chinese words and phrases.
public struct ChineseConverter {
    public let lexicon: Lexicon
    public init(lexicon: Lexicon) { self.lexicon = lexicon }

    public func candidates(for input: String, limit: Int = 40) -> [Candidate] {
        let key = input.lowercased()
        var out = readings(of: key, limit: limit)
        if Abbreviation.applies(to: key) {
            out += abbreviated(Abbreviation.pinyinKeys(key), in: lexicon, limit: limit) { _ in .chinese }
        }
        return out
    }

    /// The words typed as `key`, then whole sentences: the cheapest few, so a less common reading of
    /// the start still shows (chongqizhiqian: 充气之前, then 重启之前).
    func readings(of key: String, limit: Int) -> [Candidate] {
        // Every word typed exactly so, however rare (the expanded list has room for them).
        var out = lexicon.exact(key).map { Candidate(text: $0.word, kind: .chinese, cost: $0.cost) }
        for path in segmentations(Array(key), lexicon: lexicon, count: Cost.sentences) where path.words.count > 1 {
            let text = path.words.joined()
            if !out.contains(where: { $0.text == text }) { out.append(Candidate(text: text, kind: .chinese, cost: path.cost)) }
        }
        return out
    }

    /// What the letters would be with two neighbouring letters swapped back (zhogn → zhong → 中,
    /// zhognguo → 中国), a little dearer and shown as not typed exactly. The engine asks only when
    /// the letters are no word as typed (see `Engine.candidates`).
    public func swapCorrections(for input: String, limit: Int = 40) -> [Candidate] {
        let letters = Array(input.lowercased())
        var out: [Candidate] = []
        for i in letters.indices.dropLast() where letters[i] != letters[i + 1] {
            var fixed = letters
            fixed.swapAt(i, i + 1)
            for c in readings(of: String(fixed), limit: limit) where !out.contains(where: { $0.text == c.text }) {
                out.append(Candidate(text: c.text, kind: .chinese, cost: c.cost + Cost.swapped, isExact: false))
            }
        }
        return Array(out.sorted { $0.cost < $1.cost }.prefix(limit))
    }

    /// Words that complete the input (its letters are the start of their pinyin), and words
    /// that cover only the start of the input.
    public func partialCandidates(for input: String, limit: Int = 40) -> [Candidate] {
        let key = input.lowercased()
        var out = lexicon.prefixed(key, limit: limit).map {
            Candidate(text: $0.word, kind: .chinese, cost: $0.cost + Cost.completion, isExact: false)
        }
        let letters = Array(key)
        for j in stride(from: letters.count - 1, through: 1, by: -1) {
            for (i, e) in lexicon.exact(String(letters[0..<j])).enumerated() where i < Cost.leadingPerLength || e.word.count == 1 {
                out.append(Candidate(text: e.word, kind: .chinese, cost: e.cost + Cost.leadingWord + (i < Cost.leadingPerLength ? 0 : Cost.leadingCharacter),
                                     isExact: false, consumed: j))
            }
        }
        return out
    }
}

/// Romaji → hiragana, katakana, and Japanese words (kanji) by reading.
public struct JapaneseConverter {
    public let lexicon: Lexicon
    public init(lexicon: Lexicon) { self.lexicon = lexicon }

    /// Family and given names are kept in the dictionary under their reading with one of these in
    /// front (姓おう 王, 名き 暉): no typed reading starts with a kanji, so other lookups never see them.
    public static let familyNameMark = "姓"
    public static let givenNameMark = "名"

    static func kind(of word: String) -> CandidateKind {
        if word.unicodeScalars.allSatisfy(Kana.isHiragana) { return .hiragana }
        if word.unicodeScalars.allSatisfy(Kana.isKatakana) { return .katakana }
        return .kanji
    }

    public func candidates(for input: String, limit: Int = 40) -> [Candidate] {
        if Abbreviation.applies(to: input) {
            return abbreviated(Abbreviation.kanaKeys(input), in: lexicon, limit: limit,
                               extraCost: Cost.kanaAbbreviation, kind: Self.kind)
        }
        // Every reading of the letters (unei → うねい and うんえい), merged by cost: 運営 is there.
        // The other readings only add whole words: their sentences (kanojo → 官お所) are noise.
        let readings = Romaji.readings(input)
        guard let kana = readings.first, !kana.isEmpty else { return [] }
        var out: [Candidate] = []
        var seen: Set<String> = []
        for reading in readings {
            // Every word of the reading, however rare (ki → 暉, after the 40 most common).
            for e in lexicon.exact(reading) where seen.insert(e.word).inserted {
                out.append(Candidate(text: e.word, kind: Self.kind(of: e.word), cost: e.cost))
            }
        }
        if let path = segment(Array(kana), lexicon: lexicon, unknownCost: Cost.unknownKana), path.words.count > 1,
           seen.insert(path.words.joined()).inserted {
            let text = path.words.joined()
            var sentence = Candidate(text: text, kind: Self.kind(of: text), cost: path.cost)
            // Only kana, split into short words: no better than spelling the kana out.
            sentence.isGuess = sentence.kind != .kanji
            out.append(sentence)
        }
        for name in fullNames(kana) where seen.insert(name.text).inserted { out.append(name) }
        // The kana themselves are always offered.
        let plain = Cost.unknownKana + 15 * kana.count
        var hiragana = Candidate(text: kana, kind: .hiragana, cost: plain)
        var katakana = Candidate(text: Kana.toKatakana(kana), kind: .katakana, cost: plain + 25)
        hiragana.isGuess = true
        katakana.isGuess = true
        out += [hiragana, katakana]
        return out
    }

    /// A family name and a given name together (ouki → 王暉, 王輝), for names no dictionary has:
    /// the cheapest few of every split of the reading.
    func fullNames(_ kana: String) -> [Candidate] {
        let chars = Array(kana)
        guard chars.count >= 2 else { return [] }
        var out: [Candidate] = []
        for i in 1..<chars.count {
            let family = lexicon.exact(Self.familyNameMark + String(chars[..<i])).prefix(3)
            guard !family.isEmpty else { continue }
            let given = lexicon.exact(Self.givenNameMark + String(chars[i...])).prefix(6)
            for f in family {
                for g in given { out.append(Candidate(text: f.word + g.word, kind: .kanji, cost: Cost.fullName + (f.cost + g.cost) / 2)) }
            }
        }
        return Array(out.sorted { $0.cost < $1.cost }.prefix(Cost.fullNames))
    }

    /// Words whose reading starts with what was typed (including a half-typed last syllable,
    /// arigat → ありがとう), and words that cover only the start of the input.
    public func partialCandidates(for input: String, limit: Int = 40) -> [Candidate] {
        let lower = input.lowercased()
        let (kana, rest) = Romaji.convert(lower)
        var out: [Candidate] = []
        if kana.count >= 2, Romaji.isPartialSyllable(rest) {
            out += lexicon.prefixed(kana, limit: limit).map {
                Candidate(text: $0.word, kind: Self.kind(of: $0.word), cost: $0.cost + Cost.completion, isExact: false)
            }
        }
        let letters = Array(lower)
        for j in stride(from: letters.count - 1, through: 1, by: -1) {
            // Only cut where the letters before spell whole kana (not inside "kya" or a doubled consonant).
            guard let head = Romaji.toHiragana(String(letters[0..<j])), head.count >= 2, !head.hasSuffix("っ"),
                  !(letters[j - 1] == "n" && "aiueoy".contains(letters[j])) else { continue }
            for (i, e) in lexicon.exact(head).enumerated() where i < Cost.leadingPerLength || e.word.count == 1 {
                out.append(Candidate(text: e.word, kind: Self.kind(of: e.word),
                                     cost: e.cost + Cost.leadingWord + (i < Cost.leadingPerLength ? 0 : Cost.leadingCharacter),
                                     isExact: false, consumed: j))
            }
        }
        return out
    }
}
