import XCTest
@testable import TatakikunCore

final class LearningTests: XCTestCase {
    func testChosenCandidateMovesToFront() throws {
        let engine = try EngineTests.engine()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("tatakikun-history-\(UUID()).tsv")
        defer { engine.history = nil; try? FileManager.default.removeItem(at: file) }
        engine.history = UserHistory(url: file)
        let composer = Composer(engine: engine)
        "ai".forEach { _ = composer.handle(.letter($0)) }
        XCTAssertEqual(composer.list.firstRow.first?.text, "爱")
        let third = composer.list.firstRow[2].text
        XCTAssertEqual(composer.handle(.digit(3)).commit, third)
        XCTAssertEqual(engine.candidates(for: "ai").firstRow.first?.text, third, "chosen once: now first")

        // Kept on disk: a new history read from the same file remembers it.
        engine.history = UserHistory(url: file)
        XCTAssertEqual(engine.history?.count(input: "ai", text: third), 1)
        XCTAssertEqual(engine.candidates(for: "ai").firstRow.first?.text, third)
        engine.history?.clear()
        XCTAssertEqual(engine.candidates(for: "ai").firstRow.first?.text, "爱")
    }

    func testPolyphones() throws {
        let engine = try EngineTests.engine()
        XCTAssertEqual(engine.candidates(for: "yinhang").firstRow.first?.text, "银行")
        XCTAssertEqual(engine.candidates(for: "changcheng").firstRow.first?.text, "长城")
        XCTAssertEqual(engine.candidates(for: "zhangda").firstRow.first?.text, "长大")
        XCTAssertEqual(engine.candidates(for: "yinyue").firstRow.first?.text, "音乐")
    }
}
