#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Finds the installed language packs. The installer puts each one in its own folder,
/// `<Packs>/<zh|ja|en>/<lang>.ttkd`, next to its LICENSE.txt; a language with no pack offers no candidates.
public enum LanguagePacks {
    public enum Language: String, CaseIterable {
        case zh, ja, en, es, fr
        public var fileName: String { "\(rawValue).ttkd" }
        /// The languages typed word by word from plain letters (see WordConverter).
        public static let wordLanguages: [Language] = [.es, .fr]
    }

    /// ~/Library/Application Support/Tatakikun/Packs (where the installer puts them)
    public static var userFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tatakikun/Packs")
    }

    /// /Library/Application Support/Tatakikun/Packs (an install for all users)
    public static var systemFolder: URL { URL(fileURLWithPath: "/Library/Application Support/Tatakikun/Packs") }

    /// Where to look, first match wins: TATAKIKUN_PACKS (folders separated by :, for development),
    /// then the user's folder, then the folder for all users.
    public static var defaultFolders: [URL] {
        let env = ProcessInfo.processInfo.environment["TATAKIKUN_PACKS"]?.split(separator: ":").map { URL(fileURLWithPath: String($0)) } ?? []
        return env + [userFolder, systemFolder]
    }

    /// The pack file for `language`: `<folder>/<lang>/<lang>.ttkd`, or `<folder>/<lang>.ttkd`.
    public static func find(_ language: Language, in folders: [URL]) -> URL? {
        for folder in folders {
            for url in [folder.appendingPathComponent(language.rawValue).appendingPathComponent(language.fileName),
                        folder.appendingPathComponent(language.fileName)]
            where FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// The languages that have a pack in `folders`.
    public static func installed(in folders: [URL] = defaultFolders) -> [Language] {
        Language.allCases.filter { find($0, in: folders) != nil }
    }
}

/// English from the English pack: SCOWL words with frequencies. Corrections of misspellings
/// still come from the system spell checker.
public final class PackEnglish: EnglishLexicon {
    let lexicon: Lexicon
    private let system = SystemEnglish()

    public init(lexicon: Lexicon) { self.lexicon = lexicon }

    public func isWord(_ word: String) -> Bool { !lexicon.exact(word.lowercased()).isEmpty }

    /// Words of three letters or fewer collide with pinyin and romaji most (hen 很, man 慢), so they
    /// cost a little more; typing English just before brings them forward again (momentum).
    static let shortWordCost = 10

    /// The word as the dictionary writes it when that adds something (don't, Tokyo), otherwise as typed
    /// (so Hello stays Hello).
    public func entries(for input: String) -> [(word: String, cost: Int)] {
        var seen = Set<String>()
        let extra = input.count <= 3 ? Self.shortWordCost : 0
        return lexicon.exact(input.lowercased()).compactMap { e in
            let word = e.word == e.word.lowercased() && !e.word.contains("'") ? input : e.word
            return seen.insert(word).inserted ? (word, e.cost + extra) : nil
        }
    }

    public func completions(for prefix: String) -> [String] { completionEntries(for: prefix).map(\.word) }

    /// Completions cost their frequency plus a little, so a common completion (comp → computer) ranks
    /// with other partial matches.
    public func completionEntries(for prefix: String) -> [(word: String, cost: Int)] {
        var seen = Set<String>()
        return lexicon.prefixed(prefix.lowercased(), limit: 40).compactMap { e in
            seen.insert(e.word).inserted ? (e.word, e.cost + 45) : nil
        }
    }

    public func corrections(for word: String) -> [String] { system.corrections(for: word).filter(isWord) }
}
