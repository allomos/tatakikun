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
}

/// Lowest-cost way to cover `units` with dictionary words (Viterbi).
/// With `unknownCost`, a unit no word covers may stand for itself at that cost.
func segment(_ units: [Character], lexicon: Lexicon, unknownCost: Int? = nil) -> (words: [String], cost: Int)? {
    let n = units.count
    guard n > 0 else { return nil }
    var best = [Int](repeating: Int.max, count: n + 1)
    var back = [(from: Int, word: String)?](repeating: nil, count: n + 1)
    best[0] = 0
    for i in 0..<n where best[i] != Int.max {
        for j in (i + 1)...min(n, i + lexicon.maxKeyLength) {
            if let e = lexicon.exact(String(units[i..<j])).first {
                let c = best[i] + e.cost + Cost.perWord
                if c < best[j] { best[j] = c; back[j] = (i, e.word) }
            }
        }
        if let u = unknownCost, best[i] + u < best[i + 1] {
            best[i + 1] = best[i] + u; back[i + 1] = (i, String(units[i]))
        }
    }
    guard best[n] != Int.max else { return nil }
    var words: [String] = []
    var j = n
    while j > 0, let b = back[j] { words.append(b.word); j = b.from }
    return (words.reversed(), best[n] - Cost.perWord)
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
        var out = lexicon.exact(key).prefix(limit).map { Candidate(text: $0.word, kind: .chinese, cost: $0.cost) }
        if let path = segment(Array(key), lexicon: lexicon), path.words.count > 1 {
            out.append(Candidate(text: path.words.joined(), kind: .chinese, cost: path.cost))
        }
        if Abbreviation.applies(to: key) {
            out += abbreviated(Abbreviation.pinyinKeys(key), in: lexicon, limit: limit) { _ in .chinese }
        }
        return out
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
