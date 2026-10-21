import XCTest
@testable import TatakikunCore

/// Pinyin typed with two neighbouring letters swapped (zhogn) still offers the intended words.
final class SwapCorrectionTests: XCTestCase {
    let converter = ChineseConverter(lexicon: Lexicon(entries: [
        LexiconEntry(key: "zhong", word: "中", cost: 50),
        LexiconEntry(key: "zhong", word: "重", cost: 69),
        LexiconEntry(key: "guo", word: "国", cost: 52),
        LexiconEntry(key: "zhongguo", word: "中国", cost: 60),
        LexiconEntry(key: "an", word: "安", cost: 70),
        LexiconEntry(key: "na", word: "那", cost: 55),
    ]))

    func testSwappedLettersAlone() {
        let out = converter.swapCorrections(for: "zhogn")
        XCTAssertEqual(out.map(\.text), ["中", "重"])
        XCTAssertEqual(out.map(\.cost), [50 + Cost.swapped, 69 + Cost.swapped])
        XCTAssertTrue(out.allSatisfy { !$0.isExact }, "corrections are shown as not typed exactly")
    }

    func testSwappedLettersInsideLongerInput() {
        XCTAssertEqual(converter.swapCorrections(for: "zhognguo").first?.text, "中国")
        XCTAssertEqual(converter.swapCorrections(for: "zhonggou").first?.text, "中国")
    }

    func testValidPinyinIsUnchanged() {
        // The converter itself never corrects: zhong and an keep just their own words.
        XCTAssertEqual(converter.candidates(for: "an").map(\.text), ["安"])
        XCTAssertEqual(converter.candidates(for: "zhong").map(\.text), ["中", "重"])
        XCTAssertTrue(converter.candidates(for: "zhong").allSatisfy(\.isExact))
        XCTAssertTrue(converter.candidates(for: "zhogn").isEmpty)
    }

    func testNoSwapMakesPinyin() {
        XCTAssertTrue(converter.swapCorrections(for: "xqzv").isEmpty)
    }

    /// The engine corrects only letters that are no word as typed, of three letters or more.
    func testEngineCorrectsOnlyWhatIsNoWord() {
        let engine = Engine(chinese: converter.lexicon, japanese: nil, english: WordList(["is", "zhong"]))
        XCTAssertEqual(engine.candidates(for: "zhogn").firstRow.first?.text, "中")
        XCTAssert(engine.candidates(for: "zhogn").firstRow.contains { $0.text == "zhogn" }, "the letters as typed stay")
        XCTAssertFalse(engine.candidates(for: "is").all.contains { $0.text == "那" || $0.kind == .chinese })
        XCTAssertFalse(engine.candidates(for: "na").all.contains { $0.text == "安" }, "two letters: no swap")
    }
}

/// English that knows just these words.
private struct WordList: EnglishLexicon {
    let words: Set<String>
    init(_ words: [String]) { self.words = Set(words) }
    func isWord(_ word: String) -> Bool { words.contains(word.lowercased()) }
    func completions(for prefix: String) -> [String] { [] }
    func corrections(for word: String) -> [String] { [] }
}
