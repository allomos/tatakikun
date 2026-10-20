import Foundation

/// The candidates for one input: the first row (the candidate bar) and the rest (shown when expanded).
public struct CandidateList {
    public let input: String
    public let firstRow: [Candidate]
    public let more: [Candidate]
    public var all: [Candidate] { firstRow + more }
}

/// Turns typed letters into English, Chinese and Japanese candidates in one ranked list.
///
/// Layout rule for the first row:
/// - the best candidate of every kind that matched (EN, 中, 日, あ, ア) is always in it;
/// - the rest of the row is filled by cost, and the row is ordered by cost;
/// - the letters as typed are always in it: ranked like any English word when they are one,
///   otherwise in the row's last place.
public final class Engine {
    public let chinese: ChineseConverter
    public let japanese: JapaneseConverter
    public let english: EnglishConverter
    public var rowSize: Int
    /// At most this many candidates after the first row.
    public var maxMore = 200
    /// Candidates chosen before rank higher; nil to rank by the dictionaries alone.
    public var history: UserHistory?

    public init(chinese: Lexicon, japanese: Lexicon, english: EnglishLexicon, rowSize: Int = 9) {
        self.chinese = ChineseConverter(lexicon: chinese)
        self.japanese = JapaneseConverter(lexicon: japanese)
        self.english = EnglishConverter(lexicon: english)
        self.rowSize = rowSize
    }

    /// Loads `zh.ttkd` and `ja.ttkd` from a folder made by tatakikun-dictgen.
    public convenience init(dictionaryFolder: URL, english: EnglishLexicon = SystemEnglish(), rowSize: Int = 9) throws {
        let zh = try DictionaryFiles.open(DictionaryFiles.chinese, in: dictionaryFolder, compile: DictionaryFiles.compileChinese)
        let ja = try DictionaryFiles.open(DictionaryFiles.japanese, in: dictionaryFolder, compile: DictionaryFiles.compileJapanese)
        self.init(chinese: zh, japanese: ja, english: english, rowSize: rowSize)
    }

    public func candidates(for input: String) -> CandidateList {
        guard !input.isEmpty else { return CandidateList(input: input, firstRow: [], more: []) }
        let raw = Candidate(text: input, kind: .raw, cost: Int.max)
        var found = english.candidates(for: input)
        let letters = input.allSatisfy { $0.isASCII && $0.isLetter }
        if letters {
            found += chinese.candidates(for: input)
            found += japanese.candidates(for: input)
        }
        found = found.map { learned($0, input) }
        let ranked = Self.dedupe(found.sorted { $0.cost < $1.cost })

        var row: [Candidate] = []
        for kind in CandidateKind.allCases {
            if let best = ranked.first(where: { $0.kind == kind }) { row.append(best) }
        }
        let rawInRow = { row.contains { $0.text == input } }
        let room = rowSize - (rawInRow() || ranked.contains { $0.text == input } ? 0 : 1)
        for c in ranked where row.count < room && !row.contains(c) { row.append(c) }
        row.sort { $0.cost < $1.cost }
        if !rawInRow() {
            if row.count >= rowSize { row.removeLast() }
            row.append(ranked.first { $0.text == input } ?? raw)
        }
        var partial = english.partialCandidates(for: input)
        if letters {
            partial += chinese.partialCandidates(for: input)
            partial += japanese.partialCandidates(for: input)
        }
        let sortedPartial = Self.dedupe(partial.map { learned($0, input) }.sorted { $0.cost < $1.cost })
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
        return Candidate(text: c.text, kind: c.kind, cost: c.cost - boost, isExact: c.isExact, consumed: c.consumed)
    }

    /// Keeps the cheapest candidate of each text (input already sorted by cost).
    static func dedupe(_ sorted: [Candidate]) -> [Candidate] {
        var seen = Set<String>()
        return sorted.filter { seen.insert($0.text).inserted }
    }
}
