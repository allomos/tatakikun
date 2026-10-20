import XCTest
@testable import TatakikunCore

/// Runs against the dictionaries in build/dict (made by `scripts/build.sh` or tatakikun-dictgen).
final class EngineTests: XCTestCase {
    static let dictFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("build/dict")
    static var shared: Engine?

    func engine() throws -> Engine {
        // Each test starts without the last inserted word's language from another test.
        if let e = Self.shared { e.forgetRecent(); return e }
        guard FileManager.default.fileExists(atPath: Self.dictFolder.appendingPathComponent("zh.tsv").path) else {
            throw XCTSkip("no dictionaries in build/dict: run scripts/build.sh first")
        }
        let e = try Engine(dictionaryFolder: Self.dictFolder)
        Self.shared = e
        return e
    }

    func row(_ input: String) throws -> [String] { try engine().candidates(for: input).firstRow.map(\.text) }

    func testPinyin() throws {
        XCTAssertEqual(try row("nihao").first, "你好")
        XCTAssertEqual(try row("zhongguo").first, "中国")
        XCTAssertEqual(try row("woaini").first, "我爱你")
    }

    func testRomaji() throws {
        XCTAssertEqual(Romaji.toHiragana("arigatou"), "ありがとう")
        XCTAssertEqual(Romaji.toHiragana("konnichiha"), "こんにちは")
        XCTAssertEqual(Romaji.toHiragana("kitte"), "きって")
        XCTAssertEqual(Romaji.toHiragana("shinbun"), "しんぶん")
        XCTAssertEqual(Romaji.toHiragana("kanji"), "かんじ")
        XCTAssertEqual(Romaji.toHiragana("matcha"), "まっちゃ")
        XCTAssertNil(Romaji.toHiragana("hello"))
        XCTAssertNil(Romaji.toHiragana("arigatk"))
        let arigatou = try row("arigatou")
        XCTAssert(arigatou.contains("ありがとう") && arigatou.contains("アリガトウ"), "\(arigatou)")
        let tokyo = try row("toukyou")
        XCTAssertEqual(tokyo.first, "東京")
        XCTAssert(tokyo.contains("とうきょう") && tokyo.contains("トウキョウ"), "\(tokyo)")
        XCTAssertEqual(try row("watashihagakuseidesu").first, "私は学生です")
    }

    func testEnglish() throws {
        XCTAssertEqual(try row("hello"), ["hello"])
        XCTAssertEqual(try row("computer").first, "computer")
    }

    func testAllLanguagesAppearTogether() throws {
        let list = try engine().candidates(for: "ai").firstRow
        let kinds = Set(list.map(\.kind))
        XCTAssert(kinds.isSuperset(of: [.chinese, .kanji, .hiragana, .katakana]), "\(list)")
        XCTAssert(list.map(\.text).contains("爱") && list.map(\.text).contains("愛"))
    }

    func testRawAlwaysInFirstRow() throws {
        for input in ["qwzx", "nihao", "ai", "hen", "wo", "Hello", "kanji", "x"] {
            let list = try engine().candidates(for: input)
            XCTAssert(list.firstRow.contains { $0.text == input }, "\(input): \(list.firstRow)")
            XCTAssertLessThanOrEqual(list.firstRow.count, 9)
        }
        XCTAssertEqual(try row("qwzx"), ["qwzx"])
    }

    func testNoDuplicates() throws {
        let all = try engine().candidates(for: "sushi").all.map(\.text)
        XCTAssertEqual(all.count, Set(all).count)
    }
}
