import XCTest
@testable import TatakikunCore

final class AbbreviationTests: XCTestCase {
    func testKeys() {
        XCTAssertEqual(Abbreviation.pinyin("ni'hao"), "nh")
        XCTAssertEqual(Abbreviation.pinyin("zhong'guo"), "zg")
        XCTAssertNil(Abbreviation.pinyin("hao"))
        XCTAssertNil(Abbreviation.pinyin("wo'ai"))
        XCTAssertEqual(Abbreviation.kana("わたし"), "wts")
        XCTAssertEqual(Abbreviation.kana("とうきょう"), "tk")
        XCTAssertEqual(Abbreviation.kana("しんぶん"), "snbn")
        XCTAssertNil(Abbreviation.kana("あい"))
        XCTAssertEqual(Set(Abbreviation.pinyinKeys("zhg")), ["zg", "zhg"])
        XCTAssert(Abbreviation.kanaKeys("wtx").contains("wts"))
        XCTAssert(Abbreviation.kanaKeys("wtsh").contains("wts"))
        XCTAssertFalse(Abbreviation.applies(to: "nihao"))
        XCTAssertFalse(Abbreviation.applies(to: "n"))
        XCTAssert(Abbreviation.applies(to: "nh"))
    }

    func testCandidates() throws {
        let e = try EngineTests().engine()
        func row(_ s: String) -> [String] { e.candidates(for: s).firstRow.map(\.text) }
        XCTAssert(row("nh").contains("你好"), "\(row("nh"))")
        XCTAssertEqual(row("zhg").first, "中国")
        XCTAssertEqual(row("bj").first, "北京")
        for input in ["wtx", "wts", "wtsh"] {
            let r = row(input)
            XCTAssertEqual(r.first, "私", "\(input): \(r)")
            XCTAssert(r.contains("わたし"), "\(input): \(r)")
        }
        XCTAssertEqual(row("rgt").first, "ありがとう")
        XCTAssertEqual(row("nh").last, "nh")
    }
}
