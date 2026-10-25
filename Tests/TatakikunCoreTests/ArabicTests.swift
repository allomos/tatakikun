import XCTest
@testable import TatakikunCore

/// A03-wood850-04: Arabic typed in Arabizi (the ar pack from build/packs).
final class ArabicTests: XCTestCase {
    var engine: Engine!

    override func setUpWithError() throws {
        engine = try packEngine(LanguagePacks.Language.allCases)
    }

    func arabic(_ input: String) -> [String] {
        engine.candidates(for: input).all.filter { $0.kind == .arabic && $0.isExact }.map(\.text)
    }

    func row(_ input: String) -> [String] { engine.candidates(for: input).firstRow.map(\.text) }

    /// Types `keys` (letters, digits, space) and returns what was inserted.
    func typed(_ keys: String, into c: Composer) -> String {
        var out = ""
        for k in keys {
            let key: Key = k == " " ? .space : k.isNumber ? .digit(k.wholeNumberValue!) : .letter(k)
            out += c.handle(key).commit ?? ""
        }
        return out
    }

    func testWords() {
        XCTAssertEqual(arabic("marhaba").first, "مرحبا")
        XCTAssertEqual(arabic("shukran").first, "شكرا")
        XCTAssert(arabic("7abibi").prefix(3).contains("حبيبي"), "\(arabic("7abibi"))")
        XCTAssertEqual(arabic("ya3ni").first, "يعني", "3 for ع")
        XCTAssertEqual(arabic("3arabi").first, "عربي")
        XCTAssertEqual(arabic("wallah").first, "والله")
        XCTAssertEqual(arabic("ahlan").first, "أهلا")
    }

    /// Digits for letters: a digit joins the word when an Arabic word goes on that way, even first
    /// (7abibi); otherwise digits are typed, or choose a candidate, as before.
    func testDigits() {
        let c = Composer(engine: engine)
        XCTAssertEqual(typed("7abibi", into: c), "")
        XCTAssertEqual(c.input, "7abibi")
        XCTAssert(c.list.firstRow.contains { $0.text == "حبيبي" }, "\(c.list.firstRow.map(\.text))")
        c.reset()
        XCTAssertEqual(typed("2026", into: c), "2026", "a number is typed as itself")
        XCTAssertFalse(c.isComposing)
        XCTAssertEqual(typed("ya3ni", into: c), "")
        XCTAssertEqual(c.input, "ya3ni")
        c.reset()
        XCTAssertEqual(typed("nihao", into: c), "")
        XCTAssertEqual(c.handle(.digit(1)).commit, "你好", "a digit no Arabic word takes chooses a candidate")
        engine.turnedOff = [.ar]
        XCTAssertEqual(typed("7", into: c), "", "with Arabic off, a digit is the application's")
        XCTAssertFalse(c.isComposing)
    }

    /// Common words by their usual Arabizi: offered, and the most used Arabic word for those letters
    /// is in the bar.
    func testCommonWords() {
        let words: [(String, String)] = [
            ("min", "من"), ("fi", "في"), ("la", "لا"), ("an", "أن"), ("ma", "ما"), ("3ala", "على"), ("ila", "إلى"),
            ("kan", "كان"), ("ya", "يا"), ("allah", "الله"), ("lam", "لم"), ("hatha", "هذا"), ("hal", "هل"),
            ("3an", "عن"), ("ana", "أنا"), ("huwa", "هو"), ("qal", "قال"), ("thalik", "ذلك"), ("itha", "إذا"),
            ("hathihi", "هذه"), ("qad", "قد"), ("kul", "كل"), ("anta", "أنت"), ("laqad", "لقد"), ("yawm", "يوم"),
            ("lays", "ليس"), ("allathi", "الذي"), ("marhaba", "مرحبا"), ("shukran", "شكرا"), ("salam", "سلام"),
            ("habibi", "حبيبي"), ("7abibi", "حبيبي"), ("ya3ni", "يعني"), ("wallah", "والله"), ("ahlan", "أهلا"),
            ("3arabi", "عربي"), ("kitab", "كتاب"), ("bayt", "بيت"), ("madrasa", "مدرسة"), ("sadiq", "صديق"),
            ("7ub", "حب"), ("kalb", "كلب"), ("ma2", "ماء"), ("khubz", "خبز"), ("layl", "ليل"), ("nahar", "نهار"),
            ("shams", "شمس"), ("qamar", "قمر"), ("bab", "باب"), ("walad", "ولد"), ("bint", "بنت"), ("umm", "أم"),
            ("ab", "أب"), ("akh", "أخ"), ("ukht", "أخت"), ("jamil", "جميل"), ("kabir", "كبير"), ("saghir", "صغير"),
        ]
        XCTAssertGreaterThanOrEqual(words.count, 50)
        for (key, word) in words {
            let all = engine.candidates(for: key).all.map(\.text)
            XCTAssert(all.contains(word), "\(key) → \(word): \(all.prefix(20))")
            if let best = arabic(key).first { XCTAssert(row(key).contains(best), "\(key) → \(best) in the bar: \(row(key))") }
        }
    }

    /// Whole short phrases, word by word with Space: after the first Arabic word, Arabic leads.
    func testPhrases() {
        func phrase(_ words: String) -> String {
            let c = Composer(engine: engine)
            var out = ""
            for word in words.split(separator: " ") {
                out += typed(String(word), into: c)
                if c.list.firstRow.first?.kind != .arabic, let i = c.list.firstRow.firstIndex(where: { $0.kind == .arabic }) {
                    out += (c.choose(row: 0, column: i).commit ?? "") + " "
                } else {
                    out += c.handle(.space).commit ?? ""
                }
            }
            return out
        }
        XCTAssertEqual(phrase("ana min masr"), "أنا من مصر ")
        XCTAssertEqual(phrase("shukran ya habibi"), "شكرا يا حبيبي ")
        XCTAssertEqual(phrase("kayf 7alak"), "كيف حالك ")
    }

    /// Arabic is offered without pushing the other languages aside.
    func testMixesWithTheOtherLanguages() {
        XCTAssertEqual(row("yinhang").first, "银行")
        XCTAssertEqual(row("watashi").first, "私")
        XCTAssertEqual(row("hello").first, "hello")
        XCTAssertEqual(row("woaini").first, "我爱你")
        XCTAssertEqual(row("nihao").first, "你好")
        XCTAssertEqual(row("namaste").first, "नमस्ते")
        XCTAssertEqual(row("marhaba").last, "marhaba", "the letters as typed stay a candidate")
        for input in ["ta", "ni", "wo", "a", "ai"] { XCTAssertLessThanOrEqual(row(input).count, engine.rowSize, input) }
        engine.turnedOff = [.ar]
        XCTAssert(arabic("marhaba").isEmpty, "turned off")
    }

    func testKeys() {
        let keys = Set(WordConverter.arabiziKeys("marhaba").map(\.key))
        XCTAssert(keys.contains("mrhbA"))
        XCTAssert(WordConverter.arabiziKeys("2026").allSatisfy { $0.key.allSatisfy(\.isNumber) })
        XCTAssert(WordConverter.arabiziKeys("aaa").isEmpty, "no consonant")
    }
}
