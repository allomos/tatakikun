import XCTest
@testable import TatakikunCore

/// A02-11: a 2–4 character Chinese or Japanese result picked by hand is remembered as one word.
final class CustomWordTests: XCTestCase {
    var file: URL!
    var engine: Engine!

    override func setUp() {
        file = FileManager.default.temporaryDirectory.appendingPathComponent("tatakikun-custom-\(UUID()).tsv")
        let zh = Lexicon(entries: [
            LexiconEntry(key: "zhong", word: "中", cost: 50), LexiconEntry(key: "zhong", word: "种", cost: 55),
            LexiconEntry(key: "wen", word: "文", cost: 50), LexiconEntry(key: "wen", word: "闻", cost: 60),
            LexiconEntry(key: "zhongguo", word: "中国", cost: 45), LexiconEntry(key: "renmin", word: "人民", cost: 50),
            LexiconEntry(key: "a", word: "啊", cost: 50),
        ])
        let ja = Lexicon(entries: [
            LexiconEntry(key: "わたし", word: "私", cost: 50), LexiconEntry(key: "ねこ", word: "猫", cost: 50),
        ])
        engine = Engine(chinese: zh, japanese: ja, english: nil)
        engine.customWords = CustomWords(url: file)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: file) }

    /// Types `letters`, then picks each of `picks` (by text) from the bar or the rows below it.
    @discardableResult
    func type(_ letters: String, picking picks: [String]) -> String {
        let composer = Composer(engine: engine)
        letters.forEach { _ = composer.handle(.letter($0)) }
        var inserted = ""
        for text in picks {
            guard let row = composer.rows.firstIndex(where: { $0.contains { $0.text == text } }) else {
                XCTFail("\(text) not offered for \(composer.input): \(composer.rows)"); return inserted
            }
            inserted += composer.choose(row: row, column: composer.rows[row].firstIndex { $0.text == text }!).commit ?? ""
        }
        XCTAssertFalse(composer.isComposing)
        return inserted
    }

    func first(_ input: String) -> String? { engine.candidates(for: input).firstRow.first?.text }

    func testChineseTwoCharactersFromTwoPicks() {
        XCTAssertEqual(first("zhongwen"), "中文")
        XCTAssertEqual(type("zhongwen", picking: ["种", "闻"]), "种闻")
        XCTAssertEqual(first("zhongwen"), "种闻", "offered as one candidate, first")
        XCTAssertEqual(engine.candidates(for: "zhongwen").firstRow.first?.kind, .chinese)
    }

    func testChineseFourCharacters() {
        type("zhongguorenmin", picking: ["中国", "人民"])
        XCTAssertEqual(engine.customWords?.words(for: "zhongguorenmin").map(\.word), ["中国人民"])
    }

    func testOneOrFiveCharactersAreNotRemembered() {
        type("zhong", picking: ["种"])
        XCTAssertTrue(engine.customWords!.words(for: "zhong").isEmpty, "one character")
        type("zhongguorenmina", picking: ["中国", "人民", "啊"])
        XCTAssertTrue(engine.customWords!.words(for: "zhongguorenmina").isEmpty, "five characters")
    }

    func testFirstCandidateWithoutHandPickRecordsNothing() {
        XCTAssertEqual(type("zhongwen", picking: ["中文"]), "中文")
        XCTAssertTrue(engine.customWords!.words(for: "zhongwen").isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testJapaneseFromTwoPicks() {
        XCTAssertEqual(type("watashineko", picking: ["私", "猫"]), "私猫")
        XCTAssertEqual(engine.customWords?.words(for: "watashineko").map(\.word), ["私猫"])
        XCTAssertEqual(engine.candidates(for: "watashineko").firstRow.first.map { [$0.text, $0.kind.rawValue] }, ["私猫", "kanji"])
    }

    func testKeptOnDisk() {
        type("zhongwen", picking: ["种", "闻"])
        type("watashineko", picking: ["私", "猫"])
        engine.customWords = CustomWords(url: file)
        XCTAssertEqual(engine.customWords?.words(for: "zhongwen").map(\.word), ["种闻"])
        XCTAssertEqual(engine.customWords?.words(for: "watashineko").first?.kind, .kanji)
        engine.customWords?.clear()
        XCTAssertEqual(first("zhongwen"), "中文")
    }
}
