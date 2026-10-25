import XCTest
@testable import TatakikunCore

/// A03-wood850-05: Bengali typed by sound in Latin letters (the bn pack from build/packs).
final class BengaliTests: XCTestCase {
    var engine: Engine!

    override func setUpWithError() throws {
        engine = try packEngine(LanguagePacks.Language.allCases)
    }

    func bengali(_ input: String) -> [String] {
        engine.candidates(for: input).all.filter { $0.kind == .bengali && $0.isExact }.map(\.text)
    }

    func row(_ input: String) -> [String] { engine.candidates(for: input).firstRow.map(\.text) }

    func testWords() {
        XCTAssertEqual(bengali("ami").first, "আমি")
        XCTAssertEqual(bengali("tumi").first, "তুমি")
        XCTAssertEqual(bengali("kemon").first, "কেমন", "the unwritten vowel is o")
        XCTAssertEqual(bengali("bhalo").first, "ভালো")
        XCTAssertEqual(bengali("dhonnobad").first, "ধন্যবাদ", "য after a consonant doubles it")
        XCTAssertEqual(bengali("bangla").first, "বাংলা")
        XCTAssertEqual(bengali("hothat").first, "হঠাৎ")
    }

    /// Common words by their usual spellings: offered, and the most used Bengali word for those
    /// letters is in the bar.
    func testCommonWords() {
        let words: [(String, String)] = [
            ("ami", "আমি"), ("tumi", "তুমি"), ("apni", "আপনি"), ("se", "সে"), ("amra", "আমরা"), ("tara", "তারা"),
            ("amar", "আমার"), ("tomar", "তোমার"), ("kemon", "কেমন"), ("acho", "আছো"), ("ache", "আছে"),
            ("bhalo", "ভালো"), ("na", "না"), ("ki", "কি"), ("keno", "কেন"), ("kothay", "কোথায়"), ("ekhon", "এখন"),
            ("shob", "সব"), ("kaj", "কাজ"), ("din", "দিন"), ("rat", "রাত"), ("bari", "বাড়ি"), ("jol", "জল"),
            ("pani", "পানি"), ("bhat", "ভাত"), ("ma", "মা"), ("baba", "বাবা"), ("bondhu", "বন্ধু"), ("desh", "দেশ"),
            ("bangla", "বাংলা"), ("bhasha", "ভাষা"), ("dhonnobad", "ধন্যবাদ"), ("bhalobashi", "ভালোবাসি"),
            ("ek", "এক"), ("dui", "দুই"), ("tin", "তিন"), ("char", "চার"), ("pach", "পাঁচ"), ("boi", "বই"),
            ("skul", "স্কুল"), ("shohor", "শহর"), ("gram", "গ্রাম"), ("manush", "মানুষ"), ("jibon", "জীবন"),
            ("somoy", "সময়"), ("kotha", "কথা"), ("jodi", "যদি"), ("kintu", "কিন্তু"), ("ebong", "এবং"),
            ("theke", "থেকে"), ("kore", "করে"), ("hoy", "হয়"), ("jonno", "জন্য"), ("bishsho", "বিশ্ব"),
            ("utsob", "উৎসব"), ("hothat", "হঠাৎ"),
        ]
        XCTAssertGreaterThanOrEqual(words.count, 50)
        for (key, word) in words {
            let all = engine.candidates(for: key).all.map(\.text)
            XCTAssert(all.contains(word), "\(key) → \(word): \(all.prefix(20))")
            if let best = bengali(key).first { XCTAssert(row(key).contains(best), "\(key) → \(best) in the bar: \(row(key))") }
        }
    }

    /// Whole short phrases, word by word with Space: after the first Bengali word, Bengali leads.
    func testPhrases() {
        func typed(_ phrase: String) -> String {
            let c = Composer(engine: engine)
            var out = ""
            for word in phrase.split(separator: " ") {
                word.forEach { _ = c.handle(.letter($0)) }
                if c.list.firstRow.first?.kind != .bengali, let i = c.list.firstRow.firstIndex(where: { $0.kind == .bengali }) {
                    out += (c.choose(row: 0, column: i).commit ?? "") + " "   // the first Bengali word, picked from the bar
                } else {
                    out += c.handle(.space).commit ?? ""
                }
            }
            return out
        }
        XCTAssertEqual(typed("tumi kemon acho"), "তুমি কেমন আছো ")
        XCTAssertEqual(typed("ami bhalo achi"), "আমি ভালো আছি ")
        XCTAssertEqual(typed("ami tomake bhalobashi"), "আমি তোমাকে ভালোবাসি ")
    }

    func testMixesWithTheOtherLanguages() {
        XCTAssertEqual(row("yinhang").first, "银行")
        XCTAssertEqual(row("watashi").first, "私")
        XCTAssertEqual(row("hello").first, "hello")
        XCTAssertEqual(row("woaini").first, "我爱你")
        XCTAssertEqual(row("namaste").first, "नमस्ते")
        XCTAssertEqual(row("dhonnobad").last, "dhonnobad", "the letters as typed stay a candidate")
        engine.turnedOff = [.bn]
        XCTAssert(bengali("tumi").isEmpty, "turned off")
    }
}
