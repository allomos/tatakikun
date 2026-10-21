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

    func testSpaceAfterEnglishAddsHalfWidthSpace() throws {
        let c = try composer()
        type("hello", into: c)
        XCTAssertEqual(c.selected?.kind, .english)
        XCTAssertEqual(c.handle(.space), ComposerUpdate(handled: true, commit: "hello "))
        type("world", into: c)
        XCTAssertEqual(c.handle(.space).commit, "world ")
    }

    func testSpaceAfterRawLettersAddsSpace() throws {
        let c = try composer()
        type("qxzv", into: c)
        if let raw = c.rows.first?.firstIndex(where: { $0.kind == .raw }) {
            (0..<raw).forEach { _ in _ = c.handle(.right) }
        }
        XCTAssertEqual(c.handle(.space).commit, "qxzv ")
    }

    func testSpaceAfterJapaneseAddsNoSpace() throws {
        let c = try composer()
        type("konnichiha", into: c)
        let column = try XCTUnwrap(c.rows[0].firstIndex { $0.kind == .hiragana })
        (0..<column).forEach { _ in _ = c.handle(.right) }
        let hiragana = c.rows[0][column].text
        XCTAssertEqual(c.handle(.space).commit, hiragana, "no space after Japanese")
        type("nihao", into: c)
        XCTAssertEqual(c.handle(.space).commit, "你好", "no space after Chinese")
    }

    func testOnlySpaceAddsTheSpace() throws {
        let c = try composer()
        type("hello", into: c)
        XCTAssertEqual(c.handle(.digit(1)).commit, "hello")
        type("hello", into: c)
        XCTAssertEqual(c.handle(.enter).commit, "hello")
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

    func testPunctuationAfterEnglishIsHalfWidth() throws {
        let c = try composer()
        type("hello", into: c)
        XCTAssertEqual(c.handle(.other(",")), ComposerUpdate(handled: true, commit: "hello,"))
        XCTAssertEqual(c.handle(.other(".")).handled, false, "idle after English: the application types it")
        XCTAssertEqual(c.handle(.space).handled, false)
    }

    func testPunctuationAfterChineseIsFullWidth() throws {
        let c = try composer()
        type("nihao", into: c)
        XCTAssertEqual(c.handle(.other(",")).commit, "你好，")
        XCTAssertEqual(c.handle(.other("?")).commit, "？", "idle: follows what was inserted last")
        XCTAssertEqual(c.handle(.space).commit, "\u{3000}")
        XCTAssertEqual(c.handle(.other("\"")).commit, "“")
        XCTAssertEqual(c.handle(.other("\"")).commit, "”")
    }

    func testPunctuationAfterJapaneseIsFullWidth() throws {
        let c = try composer()
        type("konnichiha", into: c)
        let column = try XCTUnwrap(c.rows[0].firstIndex { $0.kind == .hiragana })
        (0..<column).forEach { _ in _ = c.handle(.right) }
        let hiragana = c.rows[0][column].text
        XCTAssertEqual(c.handle(.other(".")).commit, hiragana + "。")
        XCTAssertEqual(c.handle(.other(",")).commit, "、")
        XCTAssertEqual(c.handle(.other("[")).commit, "「")
    }

    func testPunctuationFollowsTextBeforeCursor() throws {
        let c = try composer()
        var before: String? = "这是"
        c.textBeforeCursor = { before }
        XCTAssertEqual(c.handle(.other(",")).commit, "，")
        before = "ですね"
        XCTAssertEqual(c.handle(.other(",")).commit, "、")
        XCTAssertEqual(c.handle(.space).commit, "\u{3000}")
        before = "Hi"
        XCTAssertFalse(c.handle(.other(",")).handled)
        XCTAssertFalse(c.handle(.space).handled)
        before = nil
        XCTAssertFalse(c.handle(.other(",")).handled, "unknown: follows what was judged last")
    }

    func testScriptBeforeText() {
        XCTAssertEqual(Punctuation.script(before: "東京", fallback: .japanese), .japanese)
        XCTAssertEqual(Punctuation.script(before: "東京", fallback: .latin), .chinese)
        XCTAssertEqual(Punctuation.script(before: "トウキョウ", fallback: .chinese), .japanese)
        XCTAssertEqual(Punctuation.script(before: "「", fallback: .chinese), .japanese)
        XCTAssertEqual(Punctuation.script(before: "，", fallback: .japanese), .chinese)
        XCTAssertEqual(Punctuation.script(before: "abc 1", fallback: .chinese), .latin)
        XCTAssertEqual(Punctuation.script(before: "line\n", fallback: .chinese), .chinese)
        XCTAssertEqual(Punctuation.script(before: "", fallback: .latin), .latin)
    }

    func testNonLettersPassThroughWhenIdle() throws {
        let c = try composer()
        XCTAssertFalse(c.handle(.space).handled)
        XCTAssertFalse(c.handle(.digit(1)).handled)
        XCTAssertFalse(c.handle(.enter).handled)
    }
}

final class ExpandTests: XCTestCase {
    func composer(_ letters: String) throws -> Composer {
        let c = Composer(engine: try EngineTests().engine())
        letters.forEach { _ = c.handle(.letter($0)) }
        return c
    }

    func testDownExpandsAndMovesThroughRows() throws {
        let c = try composer("ai")
        XCTAssertFalse(c.isExpanded)
        XCTAssertEqual(c.visibleRows.count, 1)
        _ = c.handle(.down)
        XCTAssertTrue(c.isExpanded)
        XCTAssertGreaterThan(c.visibleRows.count, 6, "enough rows to need scrolling")
        _ = c.handle(.down)
        XCTAssertEqual(c.selectedRow, 1)
        let second = c.rows[1][2].text
        XCTAssertEqual(c.handle(.digit(3)).commit, second, "digits pick from the selected row")
    }

    func testUpAndEscapeCollapse() throws {
        let c = try composer("ai")
        _ = c.handle(.tab)
        _ = c.handle(.up)
        XCTAssertFalse(c.isExpanded)
        _ = c.handle(.down)
        _ = c.handle(.escape)
        XCTAssertFalse(c.isExpanded)
        XCTAssertTrue(c.isComposing, "Esc on an expanded bar only collapses")
        _ = c.handle(.escape)
        XCTAssertFalse(c.isComposing)
    }

    func testExpandedRowsIncludePartialMatches() throws {
        let zhongg = try composer("zhongg")
        XCTAssert(zhongg.rows.joined().contains { $0.text == "中国" && !$0.isExact })
        let compu = try composer("compu")
        XCTAssert(compu.rows.joined().contains { $0.text == "computer" })
        let nihaoma = try composer("nihaoma")
        XCTAssert(nihaoma.rows.joined().contains { $0.text == "你好" && $0.consumed == 5 })
    }

    func testChoosingALeadingWordKeepsTheRest() throws {
        let c = try composer("nihaoma")
        let (r, col) = c.rows.enumerated().lazy.compactMap { r, row in
            row.firstIndex { $0.text == "你好" && $0.consumed == 5 }.map { (r, $0) }
        }.first!
        XCTAssertEqual(c.choose(row: r, column: col).commit, "你好")
        XCTAssertEqual(c.input, "ma")
    }

    func testRawStillInFirstRowWithPartials() throws {
        for input in ["zhongg", "compu", "arigat", "helo"] {
            let c = try composer(input)
            XCTAssert(c.rows[0].contains { $0.text == input }, input)
        }
    }
}
