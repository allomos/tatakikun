import XCTest
@testable import TatakikunCore

final class LexiconTests: XCTestCase {
    let entries = [
        LexiconEntry(key: "zhongguo", word: "中国", cost: 51), LexiconEntry(key: "zhongguo", word: "忠国", cost: 120),
        LexiconEntry(key: "zhong", word: "中", cost: 40), LexiconEntry(key: "zhongguoren", word: "中国人", cost: 70),
        LexiconEntry(key: "ai", word: "爱", cost: 64), LexiconEntry(key: "あい", word: "愛", cost: 67),
    ]

    func check(_ lex: Lexicon) {
        XCTAssertEqual(lex.count, 6)
        XCTAssertEqual(lex.exact("zhongguo").map(\.word), ["中国", "忠国"])
        XCTAssertEqual(lex.exact("zhongguo").first?.cost, 51)
        XCTAssertEqual(lex.exact("あい").map(\.word), ["愛"])
        XCTAssertEqual(lex.exact("zhon"), [])
        XCTAssertEqual(lex.exact("zzz"), [])
        XCTAssertEqual(lex.prefixed("zhong", limit: 10).map(\.word), ["中国", "中国人", "忠国"])
        XCTAssertEqual(lex.prefixed("zz", limit: 10), [])
        XCTAssertEqual(lex.abbreviated("zg").map(\.word), ["中国", "忠国"])
        XCTAssertEqual(lex.maxKeyLength, 11)
    }

    func testInMemory() {
        let abbr = entries.filter { $0.key == "zhongguo" }.map { (abbreviation: "zg", entry: $0) }
        check(Lexicon(entries: entries, abbreviated: abbr))
    }

    func testFileRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tatakikun-test-\(UUID()).ttkd")
        defer { try? FileManager.default.removeItem(at: url) }
        let abbr = entries.filter { $0.key == "zhongguo" }.map { (abbreviation: "zg", entry: $0) }
        try Lexicon.write(entries: entries, abbreviated: abbr, to: url)
        check(try Lexicon(contentsOf: url))
    }

    func testRejectsOtherFiles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tatakikun-test-\(UUID()).ttkd")
        defer { try? FileManager.default.removeItem(at: url) }
        try "not a dictionary at all, just text".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Lexicon(contentsOf: url))
    }

    func testOpensInstantly() throws {
        let folder = EngineTests.dictFolder
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent(DictionaryFiles.japanese).path) else {
            throw XCTSkip("no ja.ttkd in build/dict: run scripts/build.sh first")
        }
        let start = Date()
        let ja = try Lexicon(contentsOf: folder.appendingPathComponent(DictionaryFiles.japanese))
        let zh = try Lexicon(contentsOf: folder.appendingPathComponent(DictionaryFiles.chinese))
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.2)
        XCTAssertGreaterThan(ja.count + zh.count, 100_000)
    }
}
