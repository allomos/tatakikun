import XCTest
@testable import TatakikunCore

/// A03-wood850-02: French typed with plain letters (the fr pack from build/packs).
final class FrenchTests: XCTestCase {
    var engine: Engine!

    override func setUpWithError() throws {
        engine = try LanguagePackEngineTests().engine([.zh, .ja, .en, .es, .fr])
    }

    func french(_ input: String) -> [String] {
        engine.candidates(for: input).all.filter { $0.kind == .french && $0.isExact }.map(\.text)
    }

    func row(_ input: String) -> [String] { engine.candidates(for: input).firstRow.map(\.text) }

    func testAccentsFromPlainLetters() {
        XCTAssertEqual(french("ecole").first, "école")
        XCTAssertEqual(french("francais").first, "français")
        XCTAssertEqual(french("coeur").first, "cœur")
        XCTAssert(Set(french("ou")).isSuperset(of: ["où", "ou"]), "\(french("ou"))")
        XCTAssert(row("ou").contains("où"), "\(row("ou"))")
        XCTAssertEqual(french("cest").first, "c'est", "an elided word, typed without its apostrophe")
        XCTAssertEqual(french("aujourdhui").first, "aujourd'hui")
        XCTAssertEqual(french("français").first, "français", "typed with its accent")
    }

    /// Common words, typed without accents, are offered (a word another language has too comes once),
    /// and the most used French word for those letters is in the bar.
    func testCommonWords() {
        let words = [
            "de", "la", "le", "et", "les", "des", "en", "un", "du", "une", "que", "est", "pour", "qui", "dans",
            "par", "plus", "pas", "au", "sur", "ne", "se", "ce", "il", "sont", "avec", "son", "elle", "été",
            "aux", "ou", "où", "mais", "comme", "nous", "vous", "très", "être", "fait", "déjà", "après", "même",
            "français", "école", "cœur", "garçon", "deux", "année", "ville", "première", "entre", "aussi",
            "leur", "tout", "bien", "où", "là", "à", "ça", "très", "également", "était", "même", "hôpital",
            "forêt", "fenêtre", "théâtre", "élève", "frère", "père", "mère", "Noël", "maïs", "voilà",
            "aujourd'hui", "c'est", "l'école", "s'il", "qu'il", "n'est", "d'un", "j'ai",
        ]
        XCTAssertGreaterThanOrEqual(Set(words).count, 50)
        for word in words {
            let key = WordConverter.key(word)
            let all = engine.candidates(for: key).all.map(\.text)
            XCTAssert(all.contains(word), "\(key) → \(word): \(all)")
            if let best = french(key).first { XCTAssert(row(key).contains(best), "\(key) → \(best) in the bar: \(row(key))") }
        }
    }

    /// Short phrases, typed word by word: every word is in the bar.
    func testPhrases() {
        for phrase in ["le garçon est à l'école", "où est la gare", "c'est très bien", "merci beaucoup",
                       "à bientôt", "le cœur de la forêt"] {
            for word in phrase.split(separator: " ").map(String.init) {
                let key = WordConverter.key(word)
                XCTAssert(engine.candidates(for: key).all.prefix(12).map(\.text).contains(word), "\(phrase): \(key) → \(word): \(row(key))")
            }
        }
    }

    func testMixesWithTheOtherLanguages() {
        XCTAssertEqual(row("yinhang").first, "银行")
        XCTAssertEqual(row("watashi").first, "私")
        XCTAssertEqual(row("hello").first, "hello")
        XCTAssertEqual(row("woaini").first, "我爱你")
        XCTAssertEqual(row("cancion").first, "canción")
        XCTAssertEqual(row("francais").last, "francais", "the letters as typed stay a candidate")
        engine.turnedOff = [.fr]
        XCTAssert(french("francais").isEmpty, "turned off")
    }
}
