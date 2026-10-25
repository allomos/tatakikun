import XCTest
@testable import TatakikunCore

/// A03-wood850-01: Spanish typed with plain letters (the es pack from build/packs).
final class SpanishTests: XCTestCase {
    var engine: Engine!

    override func setUpWithError() throws {
        engine = try packEngine([.zh, .ja, .en, .es])
    }

    func spanish(_ input: String) -> [String] {
        engine.candidates(for: input).all.filter { $0.kind == .spanish && $0.isExact }.map(\.text)
    }

    func row(_ input: String) -> [String] { engine.candidates(for: input).firstRow.map(\.text) }

    func testAccentsFromPlainLetters() {
        XCTAssertEqual(spanish("cancion").first, "canción")
        XCTAssertEqual(spanish("nino").first, "niño")
        XCTAssert(Set(spanish("esta")).isSuperset(of: ["está", "esta"]), "\(spanish("esta"))")
        XCTAssertEqual(spanish("canción").first, "canción", "typed with its accent")
        XCTAssert(row("cancion").contains("canción"))
        XCTAssert(row("nino").contains("niño"), "\(row("nino"))")
    }

    /// Common words, typed without accents, are offered (a word English has too, con, comes once,
    /// tagged EN), and the most used Spanish word for those letters is in the bar (si: si, then sí).
    func testCommonWords() {
        let words = [
            "de", "que", "el", "la", "en", "y", "los", "se", "del", "las", "un", "por", "con", "una", "su",
            "para", "es", "al", "lo", "como", "más", "pero", "sus", "le", "ya", "o", "fue", "este", "ha",
            "sí", "porque", "esta", "son", "entre", "cuando", "muy", "sin", "sobre", "también", "me", "hasta",
            "hay", "donde", "quien", "desde", "todo", "nos", "durante", "todos", "uno", "les", "ni", "contra",
            "otros", "ese", "eso", "ante", "ellos", "esto", "mí", "antes", "algunos", "qué", "unos", "yo",
            "otro", "otras", "otra", "él", "tanto", "esa", "estos", "mucho", "quienes", "nada", "muchos",
            "año", "niño", "mañana", "corazón", "canción", "español", "música", "país", "ciudad", "después",
            "gracias", "historia", "trabajo", "agua", "familia", "número", "último", "política", "según",
        ]
        XCTAssertGreaterThanOrEqual(words.count, 50)
        for word in words {
            let key = WordConverter.key(word)
            let all = engine.candidates(for: key).all.map(\.text)
            XCTAssert(all.contains(word), "\(key) → \(word): \(all)")
            if let best = spanish(key).first { XCTAssert(row(key).contains(best), "\(key) → \(best) in the bar: \(row(key))") }
        }
    }

    /// Short phrases, typed word by word: every word is in the bar.
    func testPhrases() {
        for phrase in ["el niño está en la escuela", "muchas gracias por la canción", "hasta mañana",
                       "la música de mi país", "el corazón de la ciudad"] {
            for word in phrase.split(separator: " ").map(String.init) {
                let key = WordConverter.key(word)
                XCTAssert(row(key).contains(word), "\(phrase): \(key) → \(word): \(row(key))")
            }
        }
    }

    /// Spanish joins the other languages without pushing their first candidates aside.
    func testMixesWithTheOtherLanguages() {
        XCTAssertEqual(row("yinhang").first, "银行")
        XCTAssertEqual(row("watashi").first, "私")
        XCTAssertEqual(row("hello").first, "hello")
        XCTAssertEqual(row("woaini").first, "我爱你")
        XCTAssertEqual(row("arigatou").first, "ありがとう")
        XCTAssertEqual(row("cancion").last, "cancion", "the letters as typed stay a candidate")
        engine.turnedOff = [.es]
        XCTAssert(spanish("cancion").isEmpty, "turned off")
    }

    func testKeys() {
        XCTAssertEqual(WordConverter.key("Canción"), "cancion")
        XCTAssertEqual(WordConverter.key("pingüino"), "pinguino")
        XCTAssertEqual(WordConverter.key("cœur"), "coeur")
        XCTAssertEqual(WordConverter.key("aujourd'hui"), "aujourdhui")
        XCTAssertEqual(WordConverter.key("中文"), "")
    }
}
