import XCTest
@testable import TatakikunCore

/// Whole-sentence candidates: the cheapest few ways to cover the letters, not only the cheapest one.
final class SentenceTests: XCTestCase {
    let lexicon = Lexicon(entries: [
        LexiconEntry(key: "chongqi", word: "充气", cost: 94),
        LexiconEntry(key: "chongqi", word: "重启", cost: 114),
        LexiconEntry(key: "zhiqian", word: "之前", cost: 76),
        LexiconEntry(key: "zhiqian", word: "直前", cost: 120),
        LexiconEntry(key: "zhi", word: "之", cost: 54),
        LexiconEntry(key: "qian", word: "前", cost: 55),
    ])

    func testCheapestSegmentationsInOrder() {
        let paths = segmentations(Array("chongqizhiqian"), lexicon: lexicon, count: 3)
        XCTAssertEqual(paths.map { $0.words.joined() }, ["充气之前", "重启之前", "充气直前"])
        XCTAssertEqual(paths.map(\.cost), [94 + 76 + Cost.perWord, 114 + 76 + Cost.perWord, 94 + 120 + Cost.perWord])
        XCTAssertEqual(segment(Array("chongqizhiqian"), lexicon: lexicon)?.words, ["充气", "之前"])
    }

    func testSameTextOnlyOnce() {
        // 之前 and 之+前 make the same text: it is offered once, at its lower cost.
        let paths = segmentations(Array("zhiqian"), lexicon: lexicon, count: 3)
        XCTAssertEqual(paths.map { $0.words.joined() }, ["之前", "直前"])
    }

    func testConverterOffersTheSentences() {
        let texts = ChineseConverter(lexicon: lexicon).candidates(for: "chongqizhiqian").map(\.text)
        XCTAssertEqual(texts, ["充气之前", "重启之前", "充气直前"])
    }

    /// A02-wire178: particles (过, 了, 吗) add no per-word cost, so a spoken sentence made of single
    /// characters beats a rarer word that happens to cover the same letters.
    func testParticlesInSpokenSentences() {
        let lex = Lexicon(entries: [
            LexiconEntry(key: "ni", word: "你", cost: 51), LexiconEntry(key: "yong", word: "用", cost: 57),
            LexiconEntry(key: "niyong", word: "拟用", cost: 125), LexiconEntry(key: "guo", word: "过", cost: 56),
            LexiconEntry(key: "le", word: "了", cost: 31), LexiconEntry(key: "ma", word: "吗", cost: 64),
            LexiconEntry(key: "lema", word: "勒马", cost: 122),
        ])
        let first = segmentations(Array("niyongguolema"), lexicon: lex, count: 3).first!
        XCTAssertEqual(first.words, ["你", "用", "过", "了", "吗"])
        XCTAssertEqual(first.cost, 51 + 57 + 56 + 31 + 64 + Cost.perWord, "only 用 adds the per-word cost")
    }

    func testNothingCoversTheLetters() {
        XCTAssertTrue(segmentations(Array("xq"), lexicon: lexicon, count: 3).isEmpty)
    }
}
