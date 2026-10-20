import XCTest
@testable import TatakikunCore

/// The engine with only some language packs installed (packs from build/packs).
final class LanguagePackEngineTests: XCTestCase {
    /// A folder holding links to just these packs.
    func engine(_ langs: [LanguagePacks.Language]) throws -> Engine {
        let source = PackTests.packs
        for l in LanguagePacks.Language.allCases where LanguagePacks.find(l, in: [source]) == nil {
            throw XCTSkip("no \(l.rawValue) pack in build/packs: run scripts/build-packs.sh first")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tatakikun-packs-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        for l in langs {
            try FileManager.default.createDirectory(at: folder.appendingPathComponent(l.rawValue), withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("\(l.rawValue)/\(l.fileName)"),
                                                       withDestinationURL: LanguagePacks.find(l, in: [source])!)
        }
        let e = try Engine(packFolders: [folder])
        XCTAssertEqual(Set(e.languages), Set(langs))
        return e
    }

    func kinds(_ e: Engine, _ input: String) -> Set<CandidateKind> {
        let list = e.candidates(for: input)
        return Set(list.all.filter { $0.kind != .raw && $0.text != input || $0.kind == .english }.map(\.kind))
    }

    func testAllPacks() throws {
        let e = try engine([.zh, .ja, .en])
        XCTAssertEqual(e.candidates(for: "yinhang").firstRow.first?.text, "银行")
        XCTAssertEqual(e.candidates(for: "watashi").firstRow.first?.text, "私")
        XCTAssertEqual(e.candidates(for: "hello").firstRow.first?.text, "hello")
        XCTAssertEqual(e.candidates(for: "chongqing").firstRow.first?.text, "重庆", "a proper noun the spell checker knows is not an English word here")
        let ai = Set(e.candidates(for: "ai").firstRow.map(\.kind))
        XCTAssert(ai.isSuperset(of: [.chinese, .kanji, .hiragana, .katakana]), "\(ai)")
    }

    func testOnlyChinese() throws {
        let e = try engine([.zh])
        XCTAssertEqual(kinds(e, "ai"), [.chinese])
        XCTAssertEqual(e.candidates(for: "nihao").firstRow.first?.text, "你好")
        XCTAssert(e.candidates(for: "hello").firstRow.contains { $0.text == "hello" }, "the letters as typed are always offered")
    }

    func testOnlyJapanese() throws {
        let e = try engine([.ja])
        XCTAssertEqual(kinds(e, "ai").subtracting([.kanji, .hiragana, .katakana]), [])
        XCTAssertEqual(e.candidates(for: "toukyou").firstRow.first?.text, "東京")
    }

    func testOnlyEnglish() throws {
        let e = try engine([.en])
        XCTAssertEqual(kinds(e, "ai").subtracting([.english]), [])
        XCTAssertEqual(e.candidates(for: "dont").firstRow.first?.text, "don't")
        XCTAssert(e.candidates(for: "compu").all.contains { $0.text == "computer" })
    }

    func testNoPacks() throws {
        let e = try engine([])
        XCTAssertEqual(e.candidates(for: "nihao").firstRow.map(\.text), ["nihao"])
    }

    func testEnglishFrequencyBeatsShortWordPenalty() throws {
        let e = try engine([.zh, .ja, .en])
        let man = e.candidates(for: "man").firstRow.map(\.text)
        XCTAssertLessThan(man.firstIndex(of: "man")!, 3, "\(man)")
        let women = e.candidates(for: "women").firstRow.map(\.text)
        XCTAssertLessThan(women.firstIndex(of: "women")!, 2, "\(women)")
    }
}
