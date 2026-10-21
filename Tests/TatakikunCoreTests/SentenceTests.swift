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
        XCTAssertEqual(paths.map(\.cost), [94 + 76 + 30, 114 + 76 + 30, 94 + 120 + 30])
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

    func testNothingCoversTheLetters() {
        XCTAssertTrue(segmentations(Array("xq"), lexicon: lexicon, count: 3).isEmpty)
    }
}
