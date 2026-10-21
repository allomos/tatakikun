import XCTest
@testable import TatakikunCore

final class MomentumTests: XCTestCase {
    var engine: Engine!

    override func setUpWithError() throws {
        engine = try EngineTests().engine()
        engine.forgetRecent()
    }

    override func tearDown() { engine.forgetRecent() }

    func first(_ input: String, at date: Date = Date()) -> String? { engine.candidates(for: input, at: date).firstRow.first?.text }

    func testWithoutMomentumChineseLeads() {
        XCTAssertEqual(first("hen"), "很")
    }

    func testAfterEnglishWordEnglishLeads() {
        engine.noteInserted(.english)
        XCTAssertEqual(first("hen"), "hen")
        XCTAssertEqual(first("he"), "he")
        XCTAssertEqual(first("man"), "man")
        XCTAssertEqual(first("a"), "a")
    }

    func testAfterChineseWordChineseLeads() {
        engine.noteInserted(.chinese)
        XCTAssertEqual(first("hen"), "很")
        XCTAssertEqual(first("he"), "和")
    }

    func testAfterJapaneseWordJapaneseLeads() {
        engine.noteInserted(.hiragana)
        let lead = engine.candidates(for: "ai").firstRow.first!
        XCTAssertEqual(Language(lead.kind), .japanese)
        XCTAssertEqual(first("nihao"), "你好", "spelled-out kana with no word behind them do not lead")
    }

    func testMomentumFades() {
        let then = Date()
        engine.noteInserted(.english, at: then)
        XCTAssertEqual(first("hen", at: then.addingTimeInterval(30)), "hen")
        XCTAssertEqual(first("hen", at: then.addingTimeInterval(61)), "很")
        engine.noteInserted(.english, at: then)
        engine.forgetRecent()
        XCTAssertEqual(first("hen", at: then), "很")
    }

    func testRawStaysInRowAndNoDuplicates() {
        engine.noteInserted(.english)
        for input in ["hen", "qwzx", "nihao", "ai"] {
            let row = engine.candidates(for: input).firstRow.map(\.text)
            XCTAssert(row.contains(input), "\(input): \(row)")
            XCTAssertEqual(row.count, Set(row).count)
        }
    }

    func testComposerRecordsInsertedLanguage() {
        let composer = Composer(engine: engine)
        "is".forEach { _ = composer.handle(.letter($0)) }
        XCTAssertEqual(composer.handle(.space).commit, "is ")
        "hen".forEach { _ = composer.handle(.letter($0)) }
        XCTAssertEqual(composer.list.firstRow.first?.text, "hen", "after an English word")
        _ = composer.handle(.escape)
        "nihao".forEach { _ = composer.handle(.letter($0)) }
        XCTAssertEqual(composer.handle(.space).commit, "你好")
        "hen".forEach { _ = composer.handle(.letter($0)) }
        XCTAssertEqual(composer.list.firstRow.first?.text, "很", "after a Chinese word")
        XCTAssertEqual(composer.handle(.enter).commit, "hen")
        XCTAssertEqual(engine.recent?.language, .english, "Return inserts the letters: English")
    }
}
