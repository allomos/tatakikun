#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The candidates for one input: the first row (the candidate bar) and the rest (shown when expanded).
public struct CandidateList {
    public let input: String
    public let firstRow: [Candidate]
    public let more: [Candidate]
    public var all: [Candidate] { firstRow + more }
}

/// The language of a candidate, for ranking by what was typed just before.
public enum Language {
    case english, chinese, japanese, spanish, french, hindi

    public init(_ kind: CandidateKind) {
        switch kind {
        case .english, .raw: self = .english
        case .chinese: self = .chinese
        case .kanji, .hiragana, .katakana: self = .japanese
        case .spanish: self = .spanish
        case .french: self = .french
        case .hindi: self = .hindi
        }
    }
}

/// Turns typed letters into English, Chinese and Japanese candidates in one ranked list.
///
/// Layout rule for the first row:
/// - the best candidate of every kind that matched (EN, 中, 日, あ, ア) is always in it; for consonants
///   alone (nh, wtx), the best of each language;
/// - the rest of the row is filled by cost, and the row is ordered by cost;
/// - the letters as typed are always in it: ranked like any English word when they are one,
///   otherwise in the row's last place.
/// Right after a word in one language was inserted, the best candidate in that language comes first
/// and its other candidates rank a little higher (typing "is a hen" puts hen before 很).
public final class Engine {
    /// Nil for a language whose pack is not installed: it offers no candidates.
    public let chinese: ChineseConverter?
    public let japanese: JapaneseConverter?
    public let english: EnglishConverter?
    /// The languages typed word by word (Spanish, French, Hindi), one for each installed pack.
    public let words: [WordConverter]
    public var rowSize: Int
    /// At most this many candidates after the first row.
    public var maxMore = 400
    /// Candidates chosen before rank higher; nil to rank by the dictionaries alone.
    public var history: UserHistory?
    /// Words the user built by hand, offered as one candidate; nil for none.
    public var customWords: CustomWords?
    /// Also offer what the letters would give after one slip of the fingers (see `slipCandidates`):
    /// small phone keys are easy to miss, and so is a key on a computer keyboard.
    public var nearbyKeyCorrections = true
    /// The language of the last inserted word and when it was inserted (see `noteInserted`).
    public private(set) var recent: (language: Language, at: Date)?
    /// How long the last word's language keeps leading.
    public var momentumDuration: TimeInterval = 60
    /// How much cheaper the other candidates in that language become.
    static let momentumBoost = 40

    public init(chinese: Lexicon?, japanese: Lexicon?, english: EnglishLexicon?,
                words: [LanguagePacks.Language: Lexicon] = [:], rowSize: Int = 9) {
        self.chinese = chinese.map(ChineseConverter.init)
        self.japanese = japanese.map(JapaneseConverter.init)
        self.english = english.map(EnglishConverter.init)
        self.words = LanguagePacks.Language.wordLanguages.compactMap { l in words[l].map { WordConverter(language: l, lexicon: $0) } }
        self.rowSize = rowSize
    }

    /// Loads the installed language packs; a language without one offers no candidates.
    public convenience init(packFolders: [URL] = LanguagePacks.defaultFolders, rowSize: Int = 9) throws {
        func open(_ l: LanguagePacks.Language) throws -> Lexicon? {
            try LanguagePacks.find(l, in: packFolders).map { try Lexicon(contentsOf: $0) }
        }
        var words: [LanguagePacks.Language: Lexicon] = [:]
        for l in LanguagePacks.Language.wordLanguages { words[l] = try open(l) }
        self.init(chinese: try open(.zh), japanese: try open(.ja), english: try open(.en).map(PackEnglish.init),
                  words: words, rowSize: rowSize)
    }

    /// The languages this engine offers (installed), whether turned on or not.
    public var languages: [LanguagePacks.Language] {
        [chinese.map { _ in .zh }, japanese.map { _ in .ja }, english.map { _ in .en }].compactMap { $0 } + words.map(\.language)
    }

    /// Installed languages the user turned off in the settings: they give no candidates until
    /// turned on again (the letters as typed are still offered).
    public var turnedOff: Set<LanguagePacks.Language> = []

    func isOn(_ kind: CandidateKind) -> Bool {
        if let pack = kind.pack { return !turnedOff.contains(pack) }
        return switch Language(kind) {
        case _ where kind == .raw: true
        case .english: !turnedOff.contains(.en)
        case .chinese: !turnedOff.contains(.zh)
        case .japanese: !turnedOff.contains(.ja)
        case .spanish, .french, .hindi: true
        }
    }

    /// Loads the base `zh.ttkd` and `ja.ttkd` from a folder made by tatakikun-dictgen, with English
    /// from the system spell checker (development and tests, without the language packs).
    public convenience init(dictionaryFolder: URL, english: EnglishLexicon = SystemEnglish(), rowSize: Int = 9) throws {
        let zh = try DictionaryFiles.open(DictionaryFiles.chinese, in: dictionaryFolder, compile: DictionaryFiles.compileChinese)
        let ja = try DictionaryFiles.open(DictionaryFiles.japanese, in: dictionaryFolder, compile: DictionaryFiles.compileJapanese)
        self.init(chinese: zh, japanese: ja, english: english, rowSize: rowSize)
    }

    /// Records the language of a word just inserted, so the next input leans toward it.
    public func noteInserted(_ kind: CandidateKind, at date: Date = Date()) { recent = (Language(kind), date) }

    /// Forgets the last word's language (switched to another app, or the input was cancelled for good).
    public func forgetRecent() { recent = nil }

    public func candidates(for input: String, at date: Date = Date()) -> CandidateList {
        let lead = recent.flatMap { date.timeIntervalSince($0.at) <= momentumDuration ? $0.language : nil }
        guard !input.isEmpty else { return CandidateList(input: input, firstRow: [], more: []) }
        let raw = Candidate(text: input, kind: .raw, cost: Int.max)
        let english = turnedOff.contains(.en) ? nil : self.english
        let chinese = turnedOff.contains(.zh) ? nil : self.chinese
        let japanese = turnedOff.contains(.ja) ? nil : self.japanese
        let words = self.words.filter { !turnedOff.contains($0.language) }
        var found = english?.candidates(for: input) ?? []
        // Word languages also take letters typed with their accents (canción).
        if input.allSatisfy(\.isLetter) { found += words.flatMap { $0.candidates(for: input) } }
        let letters = input.allSatisfy { $0.isASCII && $0.isLetter }
        // Romaji may also hold "-" for the long vowel mark ー (sute-tasu → ステータス): Japanese only.
        let romaji = letters || Romaji.hasLongVowelMarks(input)
        if letters {
            let zh = chinese?.candidates(for: input) ?? []
            found += zh
            // No Chinese and no English word as typed: perhaps two letters typed in the wrong order
            // (zhogn → 中). Not for two letters (is, ia), where nearly any swap is some syllable.
            if let chinese, zh.isEmpty, found.isEmpty, input.count >= 3, !Abbreviation.applies(to: input) {
                found += chinese.swapCorrections(for: input)
            }
        }
        if romaji { found += japanese?.candidates(for: input) ?? [] }
        var typedGivesWords = false
        if nearbyKeyCorrections, letters, input.count >= 3, !Abbreviation.applies(to: input) {
            // A slip is likely only when the word meant is more common than what the letters give.
            let best = found.filter { $0.kind != .english && !$0.isGuess }.min { $0.cost < $1.cost }
            let typed = best?.cost ?? .max
            found += slipCandidates(for: input, typedCost: typed, language: best.map { Language($0.kind) })
            typedGivesWords = best != nil
        }
        if letters {
            found += (customWords?.words(for: input) ?? []).map { Candidate(text: $0.word, kind: $0.kind, cost: Cost.customWord) }
        }
        found = found.filter { isOn($0.kind) }.map { leaning(learned($0, input), lead) }
        var ranked = Self.dedupe(found.sorted { $0.cost < $1.cost })
        if let lead, let i = ranked.firstIndex(where: { Language($0.kind) == lead && !$0.isGuess }) {
            ranked.insert(ranked.remove(at: i), at: 0)
        }

        var row: [Candidate] = []
        if Abbreviation.applies(to: input) {
            // Consonants alone (nh, wtx): one place per language, so a few Japanese guesses do not
            // crowd the Chinese words out of the bar.
            for language in [Language.english, .chinese, .japanese] {
                if let best = ranked.first(where: { $0.kind != .raw && Language($0.kind) == language }) { row.append(best) }
            }
        } else {
            for kind in CandidateKind.allCases {
                // A slip does not stand for its kind: it takes a place only as one of the cheapest.
                if let best = ranked.first(where: { $0.kind == kind && !$0.isSlip }) { row.append(best) }
            }
        }
        let rawInRow = { row.contains { $0.text == input } }
        let room = rowSize - (rawInRow() || ranked.contains { $0.text == input } ? 0 : 1)
        for c in ranked where row.count < room && !row.contains(c) {
            if c.isSlip, row.filter(\.isSlip).count >= (typedGivesWords ? 1 : Cost.nearbyKeyWordsInRow) { continue }
            row.append(c)
        }
        row.sort { $0.cost < $1.cost }
        if let first = ranked.first, let i = row.firstIndex(of: first) { row.insert(row.remove(at: i), at: 0) }
        if !rawInRow() {
            if row.count >= rowSize { row.removeLast() }
            row.append(ranked.first { $0.text == input } ?? raw)
        }
        var partial = english?.partialCandidates(for: input) ?? []
        if input.allSatisfy(\.isLetter) { partial += words.flatMap { $0.partialCandidates(for: input) } }
        if letters {
            partial += chinese?.partialCandidates(for: input) ?? []
        }
        if romaji { partial += japanese?.partialCandidates(for: input) ?? [] }
        let sortedPartial = Self.dedupe(partial.map { leaning(learned($0, input), lead) }.sorted { $0.cost < $1.cost })
        if ranked.isEmpty {
            // Nothing matches all the letters yet (zhongg, arigat): show the best completions in the bar.
            row = Array(sortedPartial.filter { $0.text != input }.prefix(rowSize - 1)) + [raw]
        }
        let rest = Self.dedupe((ranked + sortedPartial).sorted { $0.cost < $1.cost })
            .filter { c in !row.contains { $0.text == c.text } }
        return CandidateList(input: input, firstRow: row, more: Array(rest.prefix(maxMore)))
    }

    private func learned(_ c: Candidate, _ input: String) -> Candidate {
        guard let boost = history?.boost(input: input, text: c.text), boost > 0 else { return c }
        return c.costing(c.cost - boost)
    }

    private func leaning(_ c: Candidate, _ lead: Language?) -> Candidate {
        guard let lead, Language(c.kind) == lead, c.kind != .raw, !c.isGuess else { return c }
        return c.costing(c.cost - Self.momentumBoost)
    }

    /// Keeps the cheapest candidate of each text (input already sorted by cost).
    static func dedupe(_ sorted: [Candidate]) -> [Candidate] {
        var seen = Set<String>()
        return sorted.filter { seen.insert($0.text).inserted }
    }
}
