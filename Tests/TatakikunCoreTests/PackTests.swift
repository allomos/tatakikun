import XCTest
@testable import TatakikunCore

/// Runs against the language packs in build/packs (made by `scripts/build-packs.sh`).
final class PackTests: XCTestCase {
    static let packs = EngineTests.dictFolder.deletingLastPathComponent().appendingPathComponent("packs")

    func pack(_ lang: String) throws -> Lexicon {
        let url = Self.packs.appendingPathComponent("\(lang)/\(lang).ttkd")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("no \(lang) pack in build/packs: run scripts/build-packs.sh first")
        }
        return try Lexicon(contentsOf: url)
    }

    func first(_ lex: Lexicon, _ key: String) -> String? { lex.exact(key).first?.word }

    func testChineseReadings() throws {
        let zh = try pack("zh")
        XCTAssertEqual(first(zh, "yinhang"), "银行")
        XCTAssertEqual(first(zh, "chongqing"), "重庆")
        XCTAssertEqual(first(zh, "zhangda"), "长大")
        XCTAssertEqual(first(zh, "xingli"), "行李")
        XCTAssertEqual(first(zh, "nihao"), "你好")
        XCTAssertEqual(first(zh, "zhongguo"), "中国")
        XCTAssert(zh.exact("hang").contains { $0.word == "行" }, "every reading of a character")
        XCTAssertEqual(zh.abbreviated("zg").first?.word, "中国")
    }

    /// A03-bluff274: a character's rare reading (活 guo, 遇 yong, 划 guo) comes after the common
    /// words typed the same way; common polyphones (行 hang, 重 chong, 长 chang) do not.
    func testRareReadingsComeAfterCommonWords() throws {
        let zh = try pack("zh")
        func rank(_ word: String, _ key: String) -> Int? { zh.exact(key).firstIndex { $0.word == word } }
        XCTAssertLessThan(rank("锅", "guo")!, rank("活", "guo")!)
        XCTAssertLessThan(rank("锅", "guo")!, rank("划", "guo")!)
        XCTAssertLessThan(rank("用", "yong")!, rank("遇", "yong")!)
        XCTAssertNotEqual(first(zh, "guole"), "活了")
        XCTAssertNotEqual(first(zh, "yongguo"), "遇过")
        XCTAssertLessThan(rank("行", "hang")!, 5, "common polyphones keep their place")
        XCTAssertLessThan(rank("重", "chong")!, 5)
        XCTAssertLessThan(rank("长", "chang")!, 5)
    }

    func testJapaneseReadings() throws {
        let ja = try pack("ja")
        XCTAssertEqual(first(ja, "わたし"), "私")
        XCTAssertEqual(first(ja, "にほん"), "日本")
        XCTAssertEqual(first(ja, "あした"), "明日")
        XCTAssertEqual(first(ja, "きょう"), "今日")
        XCTAssertEqual(first(ja, "とうきょう"), "東京")
        XCTAssertEqual(first(ja, "でんわ"), "電話")
        XCTAssertFalse(ja.exact("とうきょう").contains { $0.word == "TOKYO" }, "no Latin-letter words")
        XCTAssertGreaterThan(ja.count, 1_000_000)
    }

    func testEnglishFrequencies() throws {
        let en = try pack("en")
        for common in ["man", "women", "change", "make", "hello"] {
            XCTAssertLessThanOrEqual(en.exact(common).first?.cost ?? 999, 60, common)
        }
        XCTAssertGreaterThan(en.exact("hen").first?.cost ?? 0, en.exact("man").first?.cost ?? 0)
        XCTAssertEqual(first(en, "dont"), "don't")
        XCTAssertEqual(first(en, "tokyo"), "Tokyo")
        XCTAssert(en.exact("zzzz").isEmpty)
    }

    func testOffAtFirst() {
        XCTAssertEqual(LanguagePacks.offAtFirst(installed: LanguagePacks.Language.allCases), [.es, .fr, .hi, .bn, .ar])
        XCTAssertEqual(LanguagePacks.offAtFirst(installed: [.en, .ar]), [.ar])
        XCTAssertEqual(LanguagePacks.offAtFirst(installed: [.es, .ar]), [], "with none of zh, ja, en, what is installed stays on")
        XCTAssertEqual(LanguagePacks.offAtFirst(installed: []), [])
    }
}
