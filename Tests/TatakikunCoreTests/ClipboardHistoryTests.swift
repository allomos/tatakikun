import XCTest
@testable import TatakikunCore

final class ClipboardHistoryTests: XCTestCase {
    func testNewestFirstWithoutDuplicates() {
        let h = ClipboardHistory(url: nil)
        h.add("one"); h.add("two"); h.add("three")
        XCTAssertEqual(h.items, ["three", "two", "one"])
        h.add("one")
        XCTAssertEqual(h.items, ["one", "three", "two"], "copying again moves it to the top")
        h.add("  \n"); h.add("")
        XCTAssertEqual(h.items.count, 3, "blank text is left out")
        h.add(String(repeating: "x", count: ClipboardHistory.longest + 1))
        XCTAssertEqual(h.items.count, 3, "very long text is left out")
    }

    func testOldestDropOff() {
        let h = ClipboardHistory(url: nil)
        for i in 0..<(ClipboardHistory.limit + 5) { h.add("item \(i)") }
        XCTAssertEqual(h.items.count, ClipboardHistory.limit)
        XCTAssertEqual(h.items.first, "item \(ClipboardHistory.limit + 4)")
        XCTAssertEqual(h.items.last, "item 5")
    }

    func testRemoveAndClear() {
        let h = ClipboardHistory(url: nil)
        h.add("a"); h.add("b"); h.add("c")
        h.remove(at: 1)
        XCTAssertEqual(h.items, ["c", "a"])
        h.remove(at: 9)
        XCTAssertEqual(h.items, ["c", "a"])
        h.clear()
        XCTAssertEqual(h.items, [])
        XCTAssertNil(h.chip())
    }

    func testChip() {
        let h = ClipboardHistory(url: nil)
        let t = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertNil(h.chip(at: t))
        h.add("hello", at: t)
        XCTAssertEqual(h.chip(at: t.addingTimeInterval(5)), "hello")
        XCTAssertNil(h.chip(at: t.addingTimeInterval(ClipboardHistory.chipTime + 1)), "the chip goes away after a while")
        h.dismissChip()
        XCTAssertNil(h.chip(at: t))
        XCTAssertEqual(h.items, ["hello"], "pasting from the chip keeps the copy in the list")
        h.add("world", at: t)
        h.remove(at: 0)
        XCTAssertNil(h.chip(at: t), "a deleted copy is not offered")
    }

    func testKeptAcrossRestarts() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipboard-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let t = Date()
        ClipboardHistory(url: url).add("first", at: t)
        let h = ClipboardHistory(url: url)
        h.add("second", at: t)
        let again = ClipboardHistory(url: url)
        XCTAssertEqual(again.items, ["second", "first"])
        XCTAssertEqual(again.chip(at: t), "second")
    }
}
