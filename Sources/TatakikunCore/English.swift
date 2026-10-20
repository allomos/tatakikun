import AppKit

/// Knows which letter strings are English words.
public protocol EnglishLexicon {
    func isWord(_ word: String) -> Bool
    /// Words that start with `prefix`, most likely first.
    func completions(for prefix: String) -> [String]
    /// Likely intended words for a misspelling.
    func corrections(for word: String) -> [String]
    /// The words typed as `input` and their costs (lower is more common).
    func entries(for input: String) -> [(word: String, cost: Int)]
    /// Completions with their costs.
    func completionEntries(for prefix: String) -> [(word: String, cost: Int)]
}

extension EnglishLexicon {
    /// Without word frequencies, longer words (less likely to be accidental) cost less.
    public func entries(for input: String) -> [(word: String, cost: Int)] {
        isWord(input) ? [(input, EnglishConverter.cost(forLength: input.count))] : []
    }

    /// Without word frequencies, completions cost by their place in the list.
    public func completionEntries(for prefix: String) -> [(word: String, cost: Int)] {
        completions(for: prefix).enumerated().map { ($0.element, 100 + 3 * $0.offset) }
    }
}

/// English through the system spell checker (the same one TextEdit uses).
public final class SystemEnglish: EnglishLexicon {
    private let checker = NSSpellChecker.shared
    private let language = "en"

    public init() {}

    public func isWord(_ word: String) -> Bool {
        guard !word.isEmpty else { return false }
        if word.count == 1 { return ["a", "i"].contains(word.lowercased()) }
        let range = checker.checkSpelling(of: word, startingAt: 0, language: language, wrap: false,
                                          inSpellDocumentWithTag: 0, wordCount: nil)
        return range.location == NSNotFound
    }

    public func completions(for prefix: String) -> [String] {
        checker.completions(forPartialWordRange: NSRange(location: 0, length: (prefix as NSString).length),
                            in: prefix, language: language, inSpellDocumentWithTag: 0) ?? []
    }

    public func corrections(for word: String) -> [String] {
        checker.guesses(forWordRange: NSRange(location: 0, length: (word as NSString).length),
                        in: word, language: language, inSpellDocumentWithTag: 0) ?? []
    }
}

public struct EnglishConverter {
    public let lexicon: EnglishLexicon
    public init(lexicon: EnglishLexicon) { self.lexicon = lexicon }

    /// For English without frequencies (the system spell checker): longer words cost less.
    static func cost(forLength n: Int) -> Int {
        switch n {
        case 5...: return 55
        case 4: return 70
        case 3: return 90
        case 2: return 110
        default: return 140
        }
    }

    public func candidates(for input: String) -> [Candidate] {
        lexicon.entries(for: input).map { Candidate(text: $0.word, kind: .english, cost: $0.cost) }
    }

    /// Completions of the input (compu → computer) and, for a misspelling, corrections.
    public func partialCandidates(for input: String, limit: Int = 20) -> [Candidate] {
        var out = lexicon.completionEntries(for: input).filter { $0.word != input }.prefix(limit).map {
            Candidate(text: $0.word, kind: .english, cost: $0.cost, isExact: false)
        }
        if input.count >= 3, !lexicon.isWord(input) {
            out += lexicon.corrections(for: input).prefix(5).enumerated().map {
                Candidate(text: $0.element, kind: .english, cost: 120 + 3 * $0.offset, isExact: false)
            }
        }
        return out
    }
}
