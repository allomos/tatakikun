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
    /// False for candidates that only match the start of what was typed (shown when expanded).
    public var isExact: Bool = true

    public init(text: String, kind: CandidateKind, cost: Int, isExact: Bool = true) {
        self.text = text; self.kind = kind; self.cost = cost; self.isExact = isExact
    }
}

enum Cost {
    /// Added per word, so fewer longer words beat many short ones.
    static let perWord = 30
    /// A kana with no dictionary word, passed through as itself.
    static let unknownKana = 150
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
        guard let kana = Romaji.toHiragana(input), !kana.isEmpty else { return [] }
        var out = lexicon.exact(kana).prefix(limit).map { Candidate(text: $0.word, kind: Self.kind(of: $0.word), cost: $0.cost) }
        if let path = segment(Array(kana), lexicon: lexicon, unknownCost: Cost.unknownKana), path.words.count > 1 {
            let text = path.words.joined()
            out.append(Candidate(text: text, kind: Self.kind(of: text), cost: path.cost))
        }
        // The kana themselves are always offered.
        let plain = Cost.unknownKana + 15 * kana.count
        out.append(Candidate(text: kana, kind: .hiragana, cost: plain))
        out.append(Candidate(text: Kana.toKatakana(kana), kind: .katakana, cost: plain + 25))
        return out
    }
}
