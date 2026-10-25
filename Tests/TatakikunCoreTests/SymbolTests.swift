import XCTest
@testable import TatakikunCore

/// A02-town861: a symbol's name gives its symbols (maru → ○ ◎ ●).
final class SymbolTests: XCTestCase {
    func testNamesInEachLanguage() {
        XCTAssertEqual(Symbols.symbols(for: "maru", in: .ja).first, "○")
        XCTAssertEqual(Symbols.symbols(for: "batu", in: .ja), Symbols.symbols(for: "batsu", in: .ja))
        XCTAssertTrue(Symbols.symbols(for: "batsu", in: .ja).contains("✕"))
        XCTAssertEqual(Symbols.symbols(for: "ha-to", in: .ja).first, "♡", "ー typed as -")
        XCTAssertEqual(Symbols.symbols(for: "sikaku", in: .ja).first, "□", "any romaji spelling")
        XCTAssertEqual(Symbols.symbols(for: "dui", in: .zh).first, "✓")
        XCTAssertEqual(Symbols.symbols(for: "circle", in: .en).first, "○")
        XCTAssertEqual(Symbols.symbols(for: "círculo", in: .es), Symbols.symbols(for: "circulo", in: .es))
        XCTAssertEqual(Symbols.symbols(for: "etoile", in: .fr).first, "☆")
        XCTAssertEqual(Symbols.symbols(for: "da2ira", in: .ar).first, "○")
        XCTAssertEqual(Symbols.symbols(for: "maru", in: .en), [], "a name counts only in its own language")
        XCTAssertEqual(Symbols.symbols(for: "nihao", in: .zh), [])
    }

    func testSymbolsAmongTheCandidates() throws {
        let engine = try EngineTests.engine()
        let maru = engine.candidates(for: "maru")
        XCTAssertEqual(maru.firstRow.count, engine.rowSize)
        XCTAssertEqual(maru.firstRow.firstIndex { $0.text == "○" }, 3, "after the best words")
        XCTAssertEqual(maru.firstRow.first?.text, "丸")
        XCTAssertEqual(maru.more.prefix(3).map(\.text), ["◯", "●", "◎"], "the others first when expanded")
        XCTAssertEqual(engine.candidates(for: "dui").firstRow.first?.text, "对", "the word still first")
        XCTAssertTrue(engine.candidates(for: "dui").firstRow.contains { $0.text == "✓" })
        XCTAssertFalse(engine.candidates(for: "nihao").firstRow.contains { $0.text.unicodeScalars.first!.properties.isEmojiPresentation || $0.text == "○" })
        engine.turnedOff = [.ja]
        defer { engine.turnedOff = [] }
        XCTAssertFalse(engine.candidates(for: "maru").firstRow.contains { $0.text == "○" }, "not from a language turned off")
    }
}
