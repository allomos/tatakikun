import XCTest
@testable import TatakikunCore

/// A04-flask473: conjugated Japanese verbs and adjectives, read back to their dictionary form.
final class ConjugationTests: XCTestCase {
    let lexicon = Lexicon(entries: [
        LexiconEntry(key: Conjugation.key(.ichidan, "たべる"), word: "食べる", cost: 70),
        LexiconEntry(key: Conjugation.key(.godan, "かく"), word: "書く", cost: 70),
        LexiconEntry(key: Conjugation.key(.godan, "のむ"), word: "飲む", cost: 70),
        LexiconEntry(key: Conjugation.key(.godan, "かう"), word: "買う", cost: 70),
        LexiconEntry(key: Conjugation.key(.godan, "かえる"), word: "帰る", cost: 70),
        LexiconEntry(key: Conjugation.key(.godan, "はなす"), word: "話す", cost: 70),
        LexiconEntry(key: Conjugation.key(.godan, "およぐ"), word: "泳ぐ", cost: 70),
        LexiconEntry(key: Conjugation.key(.iku, "いく"), word: "行く", cost: 70),
        LexiconEntry(key: Conjugation.key(.honorific, "なさる"), word: "なさる", cost: 70),
        LexiconEntry(key: Conjugation.key(.kuru, "くる"), word: "来る", cost: 70),
        LexiconEntry(key: Conjugation.key(.suru, "する"), word: "する", cost: 70),
        LexiconEntry(key: Conjugation.key(.suru, "あいする"), word: "愛する", cost: 70),
        LexiconEntry(key: Conjugation.key(.adjective, "たかい"), word: "高い", cost: 70),
    ])

    func words(_ kana: String) -> [String] { Conjugation.words(for: kana, in: lexicon).map(\.word) }

    func testEachClass() {
        XCTAssertEqual(words("たべた"), ["食べた"])
        XCTAssertEqual(words("たべません"), ["食べません"])
        XCTAssertEqual(words("かいた"), ["書いた"])
        XCTAssertEqual(words("かかなかった"), ["書かなかった"])
        XCTAssertEqual(words("のんだ"), ["飲んだ"])
        XCTAssertEqual(words("かった"), ["買った"])
        XCTAssertEqual(words("かえりました"), ["帰りました"])
        XCTAssertEqual(words("はなして"), ["話して"])
        XCTAssertEqual(words("およいだ"), ["泳いだ"])
        XCTAssertEqual(words("いった"), ["行った"])
        XCTAssertEqual(words("いきます"), ["行きます"])
        XCTAssertEqual(words("なさいます"), ["なさいます"])
        XCTAssertEqual(words("きた"), ["来た"])
        XCTAssertEqual(words("こない"), ["来ない"])
        XCTAssertEqual(words("した"), ["した"])
        XCTAssertEqual(words("あいしている"), ["愛している"])
        XCTAssertEqual(words("たかかった"), ["高かった"])
        XCTAssertEqual(words("たかくない"), ["高くない"])
    }

    /// Only the right class: 帰る is godan, so かえた is no form of it (変えた would be).
    func testOnlyItsClass() {
        XCTAssertEqual(words("かえた"), [])
        XCTAssertEqual(words("たべった"), [])
        XCTAssertEqual(words("た"), [])
    }

    /// With the language packs: alone and in sentences, ahead of the kana.
    func testInEngine() throws {
        let e = try packEngine([.zh, .ja, .en])
        func first(_ s: String) -> String? { e.candidates(for: s).firstRow.first?.text }
        func row(_ s: String) -> [String] { e.candidates(for: s).firstRow.map(\.text) }
        XCTAssertEqual(first("tabeta"), "食べた")
        XCTAssertEqual(first("tabemasita"), "食べました")
        XCTAssertEqual(first("ikimasu"), "行きます")
        XCTAssertEqual(first("kaita"), "書いた")
        XCTAssertEqual(first("nonda"), "飲んだ")
        XCTAssertEqual(first("takakatta"), "高かった")
        XCTAssert(row("kita").contains("来た"), "\(row("kita"))")
        XCTAssert(row("kinoutabeta").contains("昨日食べた"), "\(row("kinoutabeta"))")
        XCTAssertEqual(first("nihongowobenkyousiteimasu"), "日本語を勉強しています")
    }
}
