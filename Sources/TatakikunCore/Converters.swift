import Foundation

/// What kind of candidate this is; the candidate bar shows it as a small tag.
public enum CandidateKind: String, CaseIterable {
    case english, chinese, kanji, hiragana, katakana, raw

    public var tag: String {
        switch self {
        case .english: return "EN"
        case .chinese: return "中"
        case .kanji: return "日"
        case .hiragana: return "あ"
        case .katakana: return "ア"
        case .raw: return "abc"
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

    public init(text: String, kind: CandidateKind, cost: Int, isExact: Bool = true, consumed: Int? = nil) {
        self.text = text; self.kind = kind; self.cost = cost; self.isExact = isExact; self.consumed = consumed
    }
}

extension Candidate {
    /// The same candidate at another cost.
    func costing(_ cost: Int) -> Candidate {
        var c = Candidate(text: text, kind: kind, cost: cost, isExact: isExact, consumed: consumed)
        c.isGuess = isGuess
        return c
    }
}

enum Cost {
    /// Added per word, so fewer longer words beat many short ones.
    static let perWord = 30
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
    /// How many leading words of each length to offer.
    static let leadingPerLength = 3
    /// A word the user built by hand (CustomWords): near the top, after the most common words.
    static let customWord = 40
    /// How many whole-sentence candidates to offer.
    static let sentences = 3
    /// Added to a word or sentence read with two neighbouring letters swapped back (zhogn → 中).
    static let swapped = 40
}

/// Lowest-cost way to cover `units` with dictionary words (Viterbi).
/// With `unknownCost`, a unit no word covers may stand for itself at that cost.
func segment(_ units: [Character], lexicon: Lexicon, unknownCost: Int? = nil) -> (words: [String], cost: Int)? {
    segmentations(units, lexicon: lexicon, unknownCost: unknownCost, count: 1).first
}

/// The `count` lowest-cost ways to cover `units` with dictionary words, cheapest first, each a
/// different text (chongqizhiqian → 充气之前, 重启之前…): Viterbi keeping the best `count` paths
/// to every position, trying each span's `count` cheapest words.
func segmentations(_ units: [Character], lexicon: Lexicon, unknownCost: Int? = nil, count k: Int) -> [(words: [String], cost: Int)] {
    let n = units.count
    guard n > 0, k > 0 else { return [] }
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
                for e in words { offer((before.cost + e.cost + Cost.perWord, i, p, e.word), at: j) }
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
        if !out.contains(where: { $0.words.joined() == words.joined() }) { out.append((words, end.cost - Cost.perWord)) }
    }
    return out
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
        var out = lexicon.exact(key).prefix(limit).map { Candidate(text: $0.word, kind: .chinese, cost: $0.cost) }
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
            for e in lexicon.exact(String(letters[0..<j])).prefix(Cost.leadingPerLength) {
                out.append(Candidate(text: e.word, kind: .chinese, cost: e.cost + Cost.leadingWord, isExact: false, consumed: j))
            }
        }
        return out
    }
}

/// Romaji → hiragana, katakana, and Japanese words (kanji) by reading.
public struct JapaneseConverter {
    public let lexicon: Lexicon
    public init(lexicon: Lexicon) { self.lexicon = lexicon }

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
        guard let kana = Romaji.toHiragana(input), !kana.isEmpty else { return [] }
        var out = lexicon.exact(kana).prefix(limit).map { Candidate(text: $0.word, kind: Self.kind(of: $0.word), cost: $0.cost) }
        if let path = segment(Array(kana), lexicon: lexicon, unknownCost: Cost.unknownKana), path.words.count > 1 {
            let text = path.words.joined()
            var sentence = Candidate(text: text, kind: Self.kind(of: text), cost: path.cost)
            // Only kana, split into short words: no better than spelling the kana out.
            sentence.isGuess = sentence.kind != .kanji
            out.append(sentence)
        }
        // The kana themselves are always offered.
        let plain = Cost.unknownKana + 15 * kana.count
        var hiragana = Candidate(text: kana, kind: .hiragana, cost: plain)
        var katakana = Candidate(text: Kana.toKatakana(kana), kind: .katakana, cost: plain + 25)
        hiragana.isGuess = true
        katakana.isGuess = true
        out += [hiragana, katakana]
        return out
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
            for e in lexicon.exact(head).prefix(Cost.leadingPerLength) {
                out.append(Candidate(text: e.word, kind: Self.kind(of: e.word), cost: e.cost + Cost.leadingWord,
                                     isExact: false, consumed: j))
            }
        }
        return out
    }
}
