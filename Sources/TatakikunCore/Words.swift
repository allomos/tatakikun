#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A language typed word by word from plain letters (Spanish, French; Hindi and Bengali by sound): its pack
/// keys every word by the letters that type it, without accents (canción under cancion, niño
/// under nino, नमस्ते under namaste), so the accents come from plain letters. Words typed with
/// their accents are found too.
///
/// Arabic, typed in Arabizi (marhaba, 7abibi), is keyed by its skeleton instead (see `arabiziKeys`).
public struct WordConverter {
    public let language: LanguagePacks.Language
    public let lexicon: Lexicon
    public let kind: CandidateKind

    public init(language: LanguagePacks.Language, lexicon: Lexicon) {
        self.language = language
        self.lexicon = lexicon
        self.kind = CandidateKind.allCases.first { $0.pack == language } ?? .raw
    }

    /// The keys to look the input up under, each with what a word found under it costs more.
    func keys(_ input: String) -> [(key: String, penalty: Int)] {
        if language == .ar { return Self.arabiziKeys(input) }
        let key = Self.key(input)
        return key.isEmpty ? [] : [(key, 0)]
    }

    /// What each point of an Arabizi key's penalty adds to the cost.
    static let penaltyCost = 3
    /// From this penalty on, an Arabic word is a loose match: it gets no place of its own in the
    /// bar, only one among the cheapest (as a slip of the fingers does).
    static let loosePenalty = 6

    func candidate(_ e: LexiconEntry, penalty: Int, isExact: Bool = true, extra: Int = 0) -> Candidate {
        var c = Candidate(text: e.word, kind: kind, cost: e.cost + penalty * Self.penaltyCost + extra, isExact: isExact)
        c.isSlip = penalty >= Self.loosePenalty
        return c
    }

    public func candidates(for input: String) -> [Candidate] {
        keys(input).flatMap { k in lexicon.exact(k.key).map { candidate($0, penalty: k.penalty) } }
    }

    /// Words that start with what was typed (cancio → canción).
    public func partialCandidates(for input: String, limit: Int = 20) -> [Candidate] {
        guard input.count >= 2 else { return [] }
        let found = keys(input).filter { $0.key.count >= 2 && $0.penalty < Self.loosePenalty }.flatMap { k in
            lexicon.prefixed(k.key, limit: limit).map { candidate($0, penalty: k.penalty, isExact: false, extra: Cost.completion) }
        }
        return Array(found.sorted { $0.cost < $1.cost }.prefix(limit))
    }

    /// Whether some word is typed starting with `input` (or as it).
    func hasWord(startingWith input: String) -> Bool {
        keys(input).contains { !lexicon.exact($0.key).isEmpty || !lexicon.prefixed($0.key, limit: 1).isEmpty }
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

    /// The long vowels in an Arabic word's skeleton: ا (a), و (o, u), ي (i, e).
    public static let longVowels: [Character: String] = ["a": "A", "o": "U", "u": "U", "i": "I", "e": "I"]

    /// The Arabizi input as skeletons, the way the Arabic pack keys its words: consonants and
    /// digits as typed, each run of vowels either a long vowel (A, U, I, by its letters) or a short
    /// one Arabic does not write (dropped): marhaba → mArhAbA, mrhAbA, mrhbA …, of which مرحبا is
    /// mrhbA. Each with a penalty: 1 for each vowel dropped (3 at the end: a word typed ending in a
    /// vowel mostly ends in a written one, ana أنا), 6 more when a doubled consonant is taken once
    /// (walah for wallah). Empty without a consonant.
    public static func arabiziKeys(_ input: String) -> [(key: String, penalty: Int)] {
        var parts: [(consonants: String, vowels: String)] = []
        var leading = ""
        for c in input.lowercased() where c != "'" && c != "’" {
            if longVowels[c] != nil {
                if parts.isEmpty { leading.append(c) } else { parts[parts.count - 1].vowels.append(c) }
            } else if (c >= "a" && c <= "z") || c.isNumber {
                if let last = parts.last, last.vowels.isEmpty { parts[parts.count - 1].consonants.append(c) }
                else { parts.append((String(c), "")) }
            } else {
                return []
            }
        }
        guard !parts.isEmpty else { return [] }
        /// A vowel run's options: dropped, or each long vowel its letters spell.
        func options(_ run: String, last: Bool = false) -> [(String, Int)] {
            run.isEmpty ? [("", 0)] : [("", last ? 3 : 1)] + Set(run.compactMap { longVowels[$0] }).sorted().map { ($0, 0) }
        }
        var keys: [(String, Int)] = options(leading)
        for (i, p) in parts.enumerated() {
            keys = keys.map { ($0.0 + p.consonants, $0.1) }
            let o = options(p.vowels, last: i == parts.count - 1)
            keys = keys.flatMap { k in o.map { (k.0 + $0.0, k.1 + $0.1) } }
            if keys.count > 512 { return [] }
        }
        var out: [String: Int] = [:]
        for (key, penalty) in keys {
            out[key] = min(out[key] ?? .max, penalty)
            var single = ""
            for c in key where c != single.last || !c.isLowercase { single.append(c) }
            if single != key { out[single] = min(out[single] ?? .max, penalty + 6) }
        }
        return out.map { ($0.key, $0.value) }.sorted { $0.key < $1.key }
    }
}
