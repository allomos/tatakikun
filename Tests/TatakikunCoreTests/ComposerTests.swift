import XCTest
@testable import TatakikunCore

final class ComposerTests: XCTestCase {
    func composer() throws -> Composer { Composer(engine: try EngineTests().engine()) }

    func type(_ s: String, into c: Composer) { s.forEach { _ = c.handle(.letter($0)) } }

    func testSpaceCommitsFirstCandidate() throws {
        let c = try composer()
        type("nihao", into: c)
        XCTAssertEqual(c.handle(.space), ComposerUpdate(handled: true, commit: "你好"))
        XCTAssertFalse(c.isComposing)
    }

    func testEnterCommitsRawLetters() throws {
        let c = try composer()
        type("nihao", into: c)
        XCTAssertEqual(c.handle(.enter).commit, "nihao")
    }

    func testDigitSelectsFromRow() throws {
        let c = try composer()
        type("toukyou", into: c)
        let third = c.list.firstRow[2].text
        XCTAssertEqual(c.handle(.digit(3)).commit, third)
    }

    func testArrowMovesSelection() throws {
        let c = try composer()
        type("ai", into: c)
        _ = c.handle(.right)
        XCTAssertEqual(c.handle(.space).commit, try EngineTests().engine().candidates(for: "ai").firstRow[1].text)
    }

    func testBackspaceAndEscape() throws {
        let c = try composer()
        type("nihaoo", into: c)
        _ = c.handle(.backspace)
        XCTAssertEqual(c.input, "nihao")
        _ = c.handle(.escape)
        XCTAssertFalse(c.isComposing)
        XCTAssertEqual(c.handle(.backspace).handled, false, "backspace passes through when not composing")
    }

    func testPunctuationCommitsThenPassesThrough() throws {
        let c = try composer()
        type("hello", into: c)
        XCTAssertEqual(c.handle(.other(",")), ComposerUpdate(handled: false, commit: "hello"))
    }

    func testNonLettersPassThroughWhenIdle() throws {
        let c = try composer()
        XCTAssertFalse(c.handle(.space).handled)
        XCTAssertFalse(c.handle(.digit(1)).handled)
        XCTAssertFalse(c.handle(.enter).handled)
    }
}
