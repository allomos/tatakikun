import AppKit

/// Knows which letter strings are English words.
public protocol EnglishLexicon {
    func isWord(_ word: String) -> Bool
    /// Words that start with `prefix`, most likely first.
    func completions(for prefix: String) -> [String]
    /// Likely intended words for a misspelling.
    func corrections(for word: String) -> [String]
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

    /// No word frequencies are available, so longer words (less likely to be accidental) cost less.
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
        lexicon.isWord(input) ? [Candidate(text: input, kind: .english, cost: Self.cost(forLength: input.count))] : []
    }
}
