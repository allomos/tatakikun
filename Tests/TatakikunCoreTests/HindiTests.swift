import XCTest
@testable import TatakikunCore

/// A03-wood850-03: Hindi typed by sound in Latin letters (the hi pack from build/packs).
final class HindiTests: XCTestCase {
    var engine: Engine!

    override func setUpWithError() throws {
        engine = try LanguagePackEngineTests().engine(LanguagePacks.Language.allCases)
    }

    func hindi(_ input: String) -> [String] {
        engine.candidates(for: input).all.filter { $0.kind == .hindi && $0.isExact }.map(\.text)
    }

    func row(_ input: String) -> [String] { engine.candidates(for: input).firstRow.map(\.text) }

    func testWords() {
        XCTAssertEqual(hindi("namaste").first, "नमस्ते")
        XCTAssertEqual(hindi("dhanyavad").first, "धन्यवाद")
        XCTAssertEqual(hindi("kya").first, "क्या")
        XCTAssertEqual(hindi("kyaa").first, "क्या", "the loose spellings people type")
        XCTAssertEqual(hindi("hai").first, "है")
        XCTAssertEqual(hindi("accha").first, "अच्छा")
        XCTAssertEqual(hindi("achha").first, "अच्छा")
        XCTAssertEqual(hindi("mein").first, "में")
    }

    /// Common words by their usual spellings: offered, and the most used Hindi word for those
    /// letters is in the bar.
    func testCommonWords() {
        let words: [(String, String)] = [
            ("ke", "के"), ("mein", "में"), ("ki", "की"), ("ka", "का"), ("se", "से"), ("ne", "ने"), ("ko", "को"),
            ("par", "पर"), ("hai", "है"), ("nahi", "नहीं"), ("hain", "हैं"), ("aur", "और"), ("liye", "लिए"),
            ("kiya", "किया"), ("bhi", "भी"), ("ek", "एक"), ("bharat", "भारत"), ("kya", "क्या"), ("ye", "ये"),
            ("ho", "हो"), ("kar", "कर"), ("sarkar", "सरकार"), ("saath", "साथ"), ("to", "तो"), ("ab", "अब"),
            ("baad", "बाद"), ("main", "मैं"), ("aap", "आप"), ("kaise", "कैसे"), ("tum", "तुम"), ("ham", "हम"),
            ("vah", "वह"), ("yah", "यह"), ("kahan", "कहाँ"), ("kab", "कब"), ("kyon", "क्यों"), ("acha", "अच्छा"),
            ("pani", "पानी"), ("ghar", "घर"), ("dost", "दोस्त"), ("din", "दिन"), ("raat", "रात"), ("log", "लोग"),
            ("desh", "देश"), ("samay", "समय"), ("kaam", "काम"), ("bahut", "बहुत"), ("sab", "सब"), ("kuch", "कुछ"),
            ("abhi", "अभी"), ("namaste", "नमस्ते"), ("dhanyavad", "धन्यवाद"), ("hindi", "हिंदी"), ("bhasha", "भाषा"),
            ("pyaar", "प्यार"), ("dil", "दिल"), ("duniya", "दुनिया"), ("zindagi", "ज़िन्दगी"), ("gaye", "गए"),
        ]
        XCTAssertGreaterThanOrEqual(words.count, 50)
        for (key, word) in words {
            let all = engine.candidates(for: key).all.map(\.text)
            XCTAssert(all.contains(word), "\(key) → \(word): \(all.prefix(20))")
            if let best = hindi(key).first { XCTAssert(row(key).contains(best), "\(key) → \(best) in the bar: \(row(key))") }
        }
    }

    /// Whole short phrases, word by word with Space: after the first Hindi word, Hindi leads.
    func testPhrases() {
        func typed(_ phrase: String) -> String {
            let c = Composer(engine: engine)
            var out = ""
            for word in phrase.split(separator: " ") {
                word.forEach { _ = c.handle(.letter($0)) }
                if c.list.firstRow.first?.kind != .hindi, let i = c.list.firstRow.firstIndex(where: { $0.kind == .hindi }) {
                    out += (c.choose(row: 0, column: i).commit ?? "") + " "   // the first Hindi word, picked from the bar
                } else {
                    out += c.handle(.space).commit ?? ""
                }
            }
            return out
        }
        XCTAssertEqual(typed("aap kaise hain"), "आप कैसे हैं ")
        XCTAssertEqual(typed("main theek hoon"), "मैं ठीक हूँ ")
        XCTAssertEqual(typed("kya haal hai"), "क्या हाल है ")
    }

    func testMixesWithTheOtherLanguages() {
        XCTAssertEqual(row("yinhang").first, "银行")
        XCTAssertEqual(row("watashi").first, "私")
        XCTAssertEqual(row("hello").first, "hello")
        XCTAssertEqual(row("woaini").first, "我爱你")
        XCTAssertEqual(row("cancion").first, "canción")
        XCTAssertEqual(row("namaste").last, "namaste", "the letters as typed stay a candidate")
        engine.turnedOff = [.hi]
        XCTAssert(hindi("namaste").isEmpty, "turned off")
    }

    /// An unwritten vowel inside a word is dropped as Hindi speakers do (कमरा kamra, not kamara).
    func testDroppedVowels() {
        XCTAssert(hindi("kamra").contains("कमरा"), "\(hindi("kamra"))")
        XCTAssert(hindi("samajh").contains("समझ"), "\(hindi("samajh"))")
    }
}
