import Foundation

/// A word in a dictionary: `key` is how it is typed (pinyin letters, or a hiragana reading),
/// `cost` is how rare it is (lower means more common).
public struct LexiconEntry: Equatable {
    public let key: String
    public let word: String
    public let cost: Int
}

/// A read-only dictionary loaded from a `key<TAB>word<TAB>cost` file, with exact and prefix lookup.
public final class Lexicon {
    private var byKey: [String: [LexiconEntry]] = [:]
    /// Distinct keys in sorted order, for prefix search.
    private var sortedKeys: [String] = []
    /// Words by their abbreviation (see `Abbreviation`).
    private var byAbbreviation: [String: [LexiconEntry]] = [:]
    public private(set) var maxKeyLength = 0

    /// - Parameter abbreviated: each word's abbreviation, for `abbreviated(_:)`.
    public init(entries: [LexiconEntry], abbreviated: [(abbreviation: String, entry: LexiconEntry)] = []) {
        for e in entries { byKey[e.key, default: []].append(e) }
        for k in byKey.keys {
            byKey[k]!.sort { $0.cost < $1.cost }
            maxKeyLength = max(maxKeyLength, k.count)
        }
        sortedKeys = byKey.keys.sorted()
        for a in abbreviated { byAbbreviation[a.abbreviation, default: []].append(a.entry) }
        for k in byAbbreviation.keys { byAbbreviation[k]!.sort { $0.cost < $1.cost } }
    }

    /// - Parameter normalizeKey: turns the key as written in the file into the typed key
    ///   (for pinyin, drops the `'` between syllables).
    /// - Parameter abbreviate: the abbreviation of the key as written in the file, if it has one.
    public convenience init(contentsOf url: URL, normalizeKey: (Substring) -> String = { String($0) },
                            abbreviate: (Substring) -> String? = { _ in nil }) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        var entries: [LexiconEntry] = []
        var abbreviated: [(abbreviation: String, entry: LexiconEntry)] = []
        entries.reserveCapacity(160_000)
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count == 3, let cost = Int(parts[2]) else { continue }
            let entry = LexiconEntry(key: normalizeKey(parts[0]), word: String(parts[1]), cost: cost)
            entries.append(entry)
            if let a = abbreviate(parts[0]) { abbreviated.append((a, entry)) }
        }
        self.init(entries: entries, abbreviated: abbreviated)
    }

    public var count: Int { byKey.values.reduce(0) { $0 + $1.count } }

    /// Words typed exactly as `key`, most common first.
    public func exact(_ key: String) -> [LexiconEntry] { byKey[key] ?? [] }

    /// Words whose abbreviation is `abbreviation`, most common first.
    public func abbreviated(_ abbreviation: String) -> [LexiconEntry] { byAbbreviation[abbreviation] ?? [] }

    /// Words whose key starts with `prefix` (excluding exact matches), most common first.
    public func prefixed(_ prefix: String, limit: Int) -> [LexiconEntry] {
        guard !prefix.isEmpty else { return [] }
        var lo = 0, hi = sortedKeys.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if sortedKeys[mid] < prefix { lo = mid + 1 } else { hi = mid }
        }
        var found: [LexiconEntry] = []
        var i = lo
        // Look at a bounded number of keys so very short prefixes stay fast.
        while i < sortedKeys.count, sortedKeys[i].hasPrefix(prefix), i - lo < 4000 {
            if sortedKeys[i] != prefix { found.append(contentsOf: byKey[sortedKeys[i]]!) }
            i += 1
        }
        found.sort { $0.cost < $1.cost }
        return Array(found.prefix(limit))
    }
}
