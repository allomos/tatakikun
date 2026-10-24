import XCTest
@testable import TatakikunCore

/// The engine with only some language packs installed (packs from build/packs).
final class LanguagePackEngineTests: XCTestCase {
    /// A folder holding links to just these packs.
    func engine(_ langs: [LanguagePacks.Language]) throws -> Engine {
        let source = PackTests.packs
        for l in LanguagePacks.Language.allCases where LanguagePacks.find(l, in: [source]) == nil {
            throw XCTSkip("no \(l.rawValue) pack in build/packs: run scripts/build-packs.sh first")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tatakikun-packs-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        for l in langs {
            try FileManager.default.createDirectory(at: folder.appendingPathComponent(l.rawValue), withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("\(l.rawValue)/\(l.fileName)"),
                                                       withDestinationURL: LanguagePacks.find(l, in: [source])!)
        }
        let e = try Engine(packFolders: [folder])
        XCTAssertEqual(Set(e.languages), Set(langs))
        return e
    }

    func kinds(_ e: Engine, _ input: String) -> Set<CandidateKind> {
        let list = e.candidates(for: input)
        return Set(list.all.filter { $0.kind != .raw && $0.text != input || $0.kind == .english }.map(\.kind))
    }

    func testAllPacks() throws {
        let e = try engine([.zh, .ja, .en])
        XCTAssertEqual(e.candidates(for: "yinhang").firstRow.first?.text, "银行")
        XCTAssertEqual(e.candidates(for: "watashi").firstRow.first?.text, "私")
        XCTAssertEqual(e.candidates(for: "hello").firstRow.first?.text, "hello")
        XCTAssertEqual(e.candidates(for: "chongqing").firstRow.first?.text, "重庆", "a proper noun the spell checker knows is not an English word here")
        let ai = Set(e.candidates(for: "ai").firstRow.map(\.kind))
        XCTAssert(ai.isSuperset(of: [.chinese, .kanji, .hiragana, .katakana]), "\(ai)")
    }

    /// A02-09: 重启 (chóng qǐ) is a word the base dictionary lacks; jieba's frequency ranks it, and
    /// the bar offers more than the one cheapest sentence, so 重启之前 is there to choose.
    func testLessCommonReadingInWholeSentence() throws {
        let e = try engine([.zh, .ja, .en])
        let bar = e.candidates(for: "chongqizhiqian").firstRow.map(\.text)
        XCTAssertEqual(bar.first, "充气之前")
        XCTAssert(bar.contains("重启之前"), "\(bar)")
        XCTAssertEqual(e.candidates(for: "chongqi").firstRow.prefix(2).map(\.text), ["充气", "重启"])
    }

    /// A03-boy892: whole person names no dictionary word has, typed in one go: jieba's person
    /// names in Chinese, a family and a given name from Mozc in Japanese; common words stay first.
    func testFullNames() throws {
        let e = try engine([.zh, .ja, .en])
        func row(_ s: String) -> [String] { e.candidates(for: s).firstRow.map(\.text) }
        XCTAssert(row("lixiangqin").contains("李香琴"), "\(row("lixiangqin"))")
        XCTAssertEqual(row("lixiang").first, "理想")
        XCTAssert(row("ouki").contains("王暉"), "\(row("ouki"))")
        XCTAssert(row("yamadatarou").contains("山田太郎"), "\(row("yamadatarou"))")
        XCTAssertEqual(row("watashi").first, "私")
        XCTAssertEqual(row("arigatou").first, "ありがとう")
    }

    /// A02-llama937: a letter on a neighbouring key still finds the word meant (on every keyboard),
    /// shown as not typed exactly; what was typed right stays first.
    func testNearbyKeySlips() throws {
        let e = try engine([.zh, .ja, .en])
        func row(_ s: String) -> [Candidate] { e.candidates(for: s).firstRow }
        XCTAssert(e.nearbyKeyCorrections, "on by default")
        XCTAssert(row("nihai").contains { $0.text == "你好" && !$0.isExact }, "\(row("nihai").map(\.text))")
        XCTAssertEqual(row("xiexir").first?.text, "谢谢")
        XCTAssertEqual(row("shrnme").first?.text, "什么")
        XCTAssertEqual(row("arigatpu").first?.text, "ありがとう")
        XCTAssertEqual(row("nihao").first?.text, "你好")
        XCTAssertFalse(row("nihao").contains { $0.text == "怒号" }, "a rarer word is no likely slip")
        XCTAssertEqual(row("watashi").first?.text, "私")
        XCTAssertEqual(row("hello").first?.text, "hello")
    }

    /// A02-solar247: one slip of any kind, in words and in sentences; typed right stays clean.
    func testMoreKindsOfSlips() throws {
        let e = try engine([.zh, .ja, .en])
        func first(_ s: String) -> String? { e.candidates(for: s).firstRow.first?.text }
        XCTAssertEqual(first("nihap"), "你好", "a key above or below")
        XCTAssertEqual(first("xiexe"), "谢谢", "a letter left out")
        XCTAssert(e.candidates(for: "nihaoo").firstRow.contains { $0.text == "你好" }, "a letter too many")
        XCTAssertEqual(first("nihoa"), "你好", "two letters swapped")
        XCTAssertEqual(first("wozaijua"), "我在家", "inside a sentence")
        XCTAssertEqual(first("wozaixuexo"), "我在学习")
        XCTAssertEqual(first("arigtou"), "ありがとう")
        XCTAssertFalse(e.candidates(for: "arigatpu").firstRow.contains { $0.text == "啊日伽头" }, "no string of rare characters")
        XCTAssertEqual(first("wozaijia"), "我在家")
        XCTAssertEqual(first("zhongguo"), "中国")
        XCTAssertFalse(e.candidates(for: "zhongguo").firstRow.contains { $0.isSlip })
    }

    /// A02-curve968: every word of a reading can be reached, not only the 40 most common.
    func testRareWordsOfAReadingAreInTheList() throws {
        let e = try engine([.zh, .ja, .en])
        XCTAssert(e.candidates(for: "ki").all.contains { $0.text == "暉" })
        XCTAssertEqual(e.candidates(for: "ki").firstRow.first?.text, "き")
    }

    /// A03-world979: any word can be put together one character at a time: every kanji by its reading
    /// (Mozc's single kanji table), and every single character for the start of a long input.
    func testOneCharacterAtATime() throws {
        let e = try engine([.zh, .ja, .en])
        XCTAssert(e.candidates(for: "kai").all.contains { $0.text == "懐" })
        XCTAssert(e.candidates(for: "houtokukai").all.contains { $0.text == "彭" && $0.consumed == 3 })
        XCTAssert(e.candidates(for: "tokukai").all.contains { $0.text == "徳" && $0.consumed == 4 })
        XCTAssertEqual(e.candidates(for: "kai").firstRow.first?.text, "会")
    }

    /// A02-easel451: consonants alone with the packs, as with the base dictionaries (A02-06). Both word
    /// frequency lists put 女孩 and 您好 before 你好, so 你好 is capped as an everyday spoken word.
    func testAbbreviations() throws {
        let e = try engine([.zh, .ja, .en])
        func row(_ s: String) -> [String] { e.candidates(for: s).firstRow.map(\.text) }
        XCTAssertEqual(row("nh").first, "你好", "\(row("nh"))")
        XCTAssertEqual(row("nihao").first, "你好")
        XCTAssertEqual(row("ninhao").first, "您好")
        XCTAssertEqual(row("nvhai").first, "女孩")
        XCTAssertEqual(row("zhg").first, "中国")
        XCTAssertEqual(row("bj").first, "北京")
        for input in ["wtx", "wts", "wtsh"] {
            let r = row(input)
            XCTAssertEqual(r.first, "私", "\(input): \(r)")
            XCTAssert(r.contains("わたし"), "\(input): \(r)")
        }
        XCTAssertEqual(row("rgt").first, "ありがとう")
    }

    /// A04-tuna688: a language turned off in the settings gives no candidates, the letters as typed
    /// stay, and turning it on again brings its candidates back at once.
    func testTurnedOffLanguages() throws {
        let e = try engine([.zh, .ja, .en])
        func all(_ s: String) -> [Candidate] { e.candidates(for: s).all }
        XCTAssert(all("watashi").contains { $0.text == "私" })
        e.turnedOff = [.ja]
        let off = all("watashi")
        XCTAssertFalse(off.contains { [.kanji, .hiragana, .katakana].contains($0.kind) }, "\(off.map(\.text))")
        XCTAssert(off.contains { $0.text == "watashi" })
        XCTAssertFalse(all("wts").contains { $0.text == "私" })
        e.turnedOff = [.zh, .en]
        let ai = Set(all("ai").map(\.kind))
        XCTAssertFalse(ai.contains(.chinese) || ai.contains(.english), "\(ai)")
        XCTAssert(ai.contains(.hiragana))
        XCTAssertEqual(e.candidates(for: "hello").firstRow.last?.text, "hello")
        e.turnedOff = []
        XCTAssertEqual(e.candidates(for: "watashi").firstRow.first?.text, "私")
        XCTAssertEqual(e.candidates(for: "yinhang").firstRow.first?.text, "银行")
    }

    /// A02-radish568: an n before a vowel can be ん, so words with ん before a vowel come up from
    /// one input (unei → 運営), and the な-row reading is still offered (うねい).
    func testNBeforeVowelAsMoraicN() throws {
        let e = try engine([.zh, .ja, .en])
        for (input, word) in [("unei", "運営"), ("unnei", "運営"), ("renai", "恋愛"), ("genin", "原因"), ("kinen", "禁煙")] {
            let all = e.candidates(for: input).all.map(\.text)
            XCTAssert(all.contains(word), "\(input): \(all)")
        }
        let unei = e.candidates(for: "unei").all.map(\.text)
        XCTAssert(unei.contains("うねい"), "\(unei)")
        XCTAssertEqual(e.candidates(for: "konnichiha").firstRow.first?.text, "こんにちは")
        XCTAssertEqual(e.candidates(for: "nihon").firstRow.first?.text, "日本")
    }

    /// A02-10: neighbouring letters typed in the wrong order still give the intended words; valid
    /// pinyin keeps its own candidates first, and the letters as typed stay in the bar.
    func testSwappedLetters() throws {
        let e = try engine([.zh, .ja, .en])
        let zhogn = e.candidates(for: "zhogn").firstRow
        XCTAssertEqual(zhogn.first?.text, "中")
        XCTAssertFalse(zhogn.first!.isExact)
        XCTAssert(zhogn.contains { $0.text == "zhogn" })
        XCTAssertEqual(e.candidates(for: "zhognguo").firstRow.first?.text, "中国")
        XCTAssertEqual(e.candidates(for: "zhong").firstRow.first.map { [$0.text, "\($0.isExact)"] }, ["中", "true"])
    }

    /// A02-wire178 / A03-bluff274: spoken sentences of single characters come out whole, and no rare
    /// reading (活 guo, 遇 yong) or rare word (勒马) takes the first row.
    func testSpokenSentences() throws {
        let e = try engine([.zh, .ja, .en])
        func bar(_ input: String) -> [String] { e.candidates(for: input).firstRow.map(\.text) }
        XCTAssertEqual(bar("niyongguolema").first, "你用过了吗")
        XCTAssertFalse(bar("niyongguolema").contains { $0.contains("活了") || $0.contains("遇过") || $0.contains("勒马") }, "\(bar("niyongguolema"))")
        XCTAssertEqual(bar("nichifanlema").first, "你吃饭了吗")
        XCTAssertEqual(bar("nizaiganshenme").first, "你在干什么")
        XCTAssertEqual(bar("tamenqunale").first, "他们去那了")
        XCTAssertEqual(bar("zhegehenhaochi").first, "这个很好吃")
        XCTAssertEqual(bar("guole").first, "过了")
        for (input, word) in [("de", "的"), ("le", "了"), ("guo", "过"), ("hao", "好"), ("qu", "去"), ("ai", "爱"),
                              ("woaini", "我爱你"), ("nihao", "你好"), ("zhongguo", "中国"), ("yinhang", "银行")] {
            XCTAssertEqual(e.candidates(for: input).firstRow.first { $0.kind == .chinese }?.text, word, input)
        }
    }

    func testOnlyChinese() throws {
        let e = try engine([.zh])
        XCTAssertEqual(kinds(e, "ai"), [.chinese])
        XCTAssertEqual(e.candidates(for: "nihao").firstRow.first?.text, "你好")
        XCTAssert(e.candidates(for: "hello").firstRow.contains { $0.text == "hello" }, "the letters as typed are always offered")
    }

    func testOnlyJapanese() throws {
        let e = try engine([.ja])
        XCTAssertEqual(kinds(e, "ai").subtracting([.kanji, .hiragana, .katakana]), [])
        XCTAssertEqual(e.candidates(for: "toukyou").firstRow.first?.text, "東京")
    }

    func testOnlyEnglish() throws {
        let e = try engine([.en])
        XCTAssertEqual(kinds(e, "ai").subtracting([.english]), [])
        XCTAssertEqual(e.candidates(for: "dont").firstRow.first?.text, "don't")
        XCTAssert(e.candidates(for: "compu").all.contains { $0.text == "computer" })
    }

    func testNoPacks() throws {
        let e = try engine([])
        XCTAssertEqual(e.candidates(for: "nihao").firstRow.map(\.text), ["nihao"])
    }

    func testEnglishFrequencyBeatsShortWordPenalty() throws {
        let e = try engine([.zh, .ja, .en])
        let man = e.candidates(for: "man").firstRow.map(\.text)
        XCTAssertLessThan(man.firstIndex(of: "man")!, 3, "\(man)")
        let women = e.candidates(for: "women").firstRow.map(\.text)
        XCTAssertLessThan(women.firstIndex(of: "women")!, 2, "\(women)")
    }

    func testAbbreviationsWithFullPacks() throws {
        let e = try engine([.zh, .ja, .en])
        XCTAssert(e.candidates(for: "nh").firstRow.contains { $0.text == "你好" }, "\(e.candidates(for: "nh").firstRow.map(\.text))")
        XCTAssert(e.candidates(for: "zg").firstRow.contains { $0.text == "中国" })
        let wtx = e.candidates(for: "wtx").firstRow.map(\.text)
        XCTAssert(wtx.contains("私") && wtx.contains("わたし"), "\(wtx)")
        XCTAssert(e.candidates(for: "nh").firstRow.contains { $0.text == "nh" })
    }
}
