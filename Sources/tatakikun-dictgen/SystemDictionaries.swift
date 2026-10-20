import Foundation
import TatakikunCore

// The base dictionaries, built only from data that ships with macOS:
//   zh.tsv  pinyin syllables joined by ' <TAB> simplified Chinese word <TAB> cost
//   ja.tsv  hiragana reading <TAB> Japanese word <TAB> cost
// compiled into zh.ttkd and ja.ttkd. The language packs (Packs.swift) start from these.

let maxWordLength = 8

func isAll(_ w: String, _ pred: (Unicode.Scalar) -> Bool) -> Bool { w.unicodeScalars.allSatisfy(pred) }

func simplified(_ w: String) -> String {
    w.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? w
}

/// One toneless syllable per character (ü written as v), or nil when the transform cannot read it.
func pinyinSyllables(_ w: String) -> [String]? {
    guard var latin = w.applyingTransform(.mandarinToLatin, reverse: false) else { return nil }
    latin = latin.replacingOccurrences(of: "[üǖǘǚǜ]", with: "v", options: .regularExpression)
    latin = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
    let sylls = latin.lowercased().split(separator: " ").map(String.init)
    guard sylls.count == w.count, sylls.allSatisfy({ $0.allSatisfy { $0 >= "a" && $0 <= "z" } }) else { return nil }
    return sylls
}

/// Hiragana reading of a Japanese word, or nil when the system does not know it as one word.
func japaneseReading(_ w: String) -> String? {
    if isAll(w, Kana.isHiragana) { return w }
    if isAll(w, Kana.isKatakana) { return Kana.toHiragana(w) }
    guard w.unicodeScalars.contains(where: Kana.isHan),
          isAll(w, { Kana.isHan($0) || Kana.isHiragana($0) || Kana.isKatakana($0) }) else { return nil }
    let cf = w as CFString
    let tok = CFStringTokenizerCreate(nil, cf, CFRange(location: 0, length: CFStringGetLength(cf)),
                                      kCFStringTokenizerUnitWord, Locale(identifier: "ja") as CFLocale)
    var transcriptions: [String] = []
    while CFStringTokenizerAdvanceToNextToken(tok) != [] {
        let r = CFStringTokenizerGetCurrentTokenRange(tok)
        guard r.location == 0, r.length == CFStringGetLength(cf) else { return nil }
        if let t = CFStringTokenizerCopyCurrentTokenAttribute(tok, kCFStringTokenizerAttributeLatinTranscription) as? String {
            transcriptions.append(t)
        }
    }
    guard transcriptions.count == 1, !transcriptions[0].isEmpty,
          let kana = transcriptions[0].applyingTransform(.latinToHiragana, reverse: false),
          isAll(kana, Kana.isHiragana) else { return nil }
    return kana
}


func buildSystemDictionaries(outDir: URL, icuPath: String) throws {
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let words = try ICUDictionary.readCJDict(path: icuPath)
    log("cjdict: \(words.count) words from \(icuPath)")
    var zh: [String: Int] = [:]
    var ja: [String: Int] = [:]
    func keep(_ table: inout [String: Int], _ key: String, _ cost: Int) {
        if let old = table[key], old <= cost { return }
        table[key] = cost
    }

    for (word, cost) in words where word.count <= maxWordLength {
        if isAll(word, Kana.isHan), simplified(word) == word, let sylls = pinyinSyllables(word) {
            // Other readings of polyphonic characters cost a little more than the transform's own.
            for (i, reading) in pinyinReadings(word, default: sylls).enumerated() {
                keep(&zh, reading.joined(separator: "'") + "\t" + word, cost + (i == 0 ? 0 : 5))
            }
        }
        if let reading = japaneseReading(word) {
            keep(&ja, reading + "\t" + word, cost)
        }
    }

    // Common readings the system tokenizer does not give (it returns one reading per word).
    let extraJapanese: [(String, String, Int)] = [
        ("わたし", "私", 50), ("にほん", "日本", 55), ("にほんご", "日本語", 60), ("あした", "明日", 62),
        ("ひと", "人", 55), ("なに", "何", 55), ("いま", "今", 55), ("ほん", "本", 60),
    ]
    for (reading, word, cost) in extraJapanese { keep(&ja, reading + "\t" + word, cost) }

    func write(_ table: [String: Int], _ name: String) throws {
        let lines = table.map { "\($0.key)\t\($0.value)" }.sorted()
        try (lines.joined(separator: "\n") + "\n").write(to: outDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        log("\(name): \(lines.count) entries")
    }
    try write(zh, "zh.tsv")
    try write(ja, "ja.tsv")
    try DictionaryFiles.compileChinese(text: outDir.appendingPathComponent("zh.tsv"), to: outDir.appendingPathComponent(DictionaryFiles.chinese))
    try DictionaryFiles.compileJapanese(text: outDir.appendingPathComponent("ja.tsv"), to: outDir.appendingPathComponent(DictionaryFiles.japanese))
    log("compiled \(DictionaryFiles.chinese) and \(DictionaryFiles.japanese)")
}

func log(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }
