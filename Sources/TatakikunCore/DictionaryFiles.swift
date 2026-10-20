import Foundation

/// The dictionary files Tatakikun reads, and how they are made from dictgen's text output.
public enum DictionaryFiles {
    public static let chinese = "zh.ttkd"
    public static let japanese = "ja.ttkd"

    /// Pinyin keys are written with `'` between syllables; they are typed without it.
    static func pinyinKey(_ key: Substring) -> String { key.replacingOccurrences(of: "'", with: "") }

    /// zh.tsv (pinyin with ' between syllables) → zh.ttkd, with each word's initials abbreviation.
    public static func compileChinese(text: URL, to url: URL) throws {
        let t = try Lexicon.readText(text, normalizeKey: pinyinKey, abbreviate: Abbreviation.pinyin)
        try Lexicon.write(entries: t.entries, abbreviated: t.abbreviated, to: url)
    }

    /// ja.tsv (hiragana readings) → ja.ttkd, with each word's consonants abbreviation.
    public static func compileJapanese(text: URL, to url: URL) throws {
        let t = try Lexicon.readText(text, abbreviate: Abbreviation.kana)
        try Lexicon.write(entries: t.entries, abbreviated: t.abbreviated, to: url)
    }

    /// Opens a dictionary from `folder`: the `.ttkd` file, or else the text file next to it (development).
    static func open(_ name: String, in folder: URL, compile: (URL, URL) throws -> Void) throws -> Lexicon {
        let binary = folder.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: binary.path) { return try Lexicon(contentsOf: binary) }
        let text = binary.deletingPathExtension().appendingPathExtension("tsv")
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("tatakikun-\(UUID().uuidString)-\(name)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try compile(text, temporary)
        return try Lexicon(contentsOf: temporary)
    }
}
