import XCTest
@testable import TatakikunCore

final class KanaTests: XCTestCase {
    func testKatakana() { XCTAssertEqual(Kana.toKatakana("ありがとう"), "アリガトウ"); XCTAssertEqual(Kana.toHiragana("コンピューター"), "こんぴゅーたー") }
}
