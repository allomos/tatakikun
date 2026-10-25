#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A language typed word by word from plain letters (Spanish): its pack keys every word by the
/// letters that type it, without accents (canción under cancion, niño under nino), so the
/// accents come from plain letters. Words typed with their accents are found too.
public struct WordConverter {
    public let language: LanguagePacks.Language
    public let lexicon: Lexicon
    public let kind: CandidateKind

    public init(language: LanguagePacks.Language, lexicon: Lexicon) {
        self.language = language
        self.lexicon = lexicon
        self.kind = CandidateKind.allCases.first { $0.pack == language } ?? .raw
    }

    public func candidates(for input: String) -> [Candidate] {
        lexicon.exact(Self.key(input)).map { Candidate(text: $0.word, kind: kind, cost: $0.cost) }
    }

    /// Words that start with what was typed (cancio → canción).
    public func partialCandidates(for input: String, limit: Int = 20) -> [Candidate] {
        let key = Self.key(input)
        guard key.count >= 2 else { return [] }
        return lexicon.prefixed(key, limit: limit).map {
            Candidate(text: $0.word, kind: kind, cost: $0.cost + Cost.completion, isExact: false)
        }
    }

    /// How a word is typed: lowercase, accents and marks dropped (ñ → n, ç → c, œ → oe), no
    /// apostrophes or hyphens. Empty when it holds anything else.
    public static func key(_ word: String) -> String {
        var out = ""
        for c in word.lowercased() {
            if c >= "a" && c <= "z" { out.append(c) }
            else if let plain = folded[c] { out += plain }
            else if c == "'" || c == "’" || c == "-" { continue }
            else { return "" }
        }
        return out
    }

    /// Latin letters with accents and marks, as typed with plain letters.
    static let folded: [Character: String] = {
        var table: [Character: String] = ["ñ": "n", "ç": "c", "œ": "oe", "æ": "ae", "ß": "ss", "ÿ": "y"]
        for (plain, marked) in [("a", "áàâäãå"), ("e", "éèêë"), ("i", "íìîï"), ("o", "óòôöõ"), ("u", "úùûü")] {
            for c in marked { table[c] = plain }
        }
        return table
    }()
}
