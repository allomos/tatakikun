import Foundation

/// A word in a dictionary: `key` is how it is typed (pinyin letters, or a hiragana reading),
/// `cost` is how rare it is (lower means more common).
public struct LexiconEntry: Equatable {
    public let key: String
    public let word: String
    public let cost: Int

    public init(key: String, word: String, cost: Int) {
        self.key = key; self.word = word; self.cost = cost
    }
}

/// A read-only dictionary with exact, prefix and abbreviation lookup, kept in a `.ttkd` file
/// that is memory-mapped: opening it reads nothing, and lookups binary-search the file.
///
/// File layout (all integers UInt32, little-endian):
///   "TTKD", version 1, maxKeyLength, keyCount, keyTable, abbrCount, abbrTable
///   keyTable:  keyCount offsets of `key<TAB>word<TAB>cost\n` records, sorted by key bytes, then cost
///   abbrTable: abbrCount offsets of `abbreviation<TAB>word<TAB>cost\n` records, sorted the same way
public final class Lexicon {
    private let data: NSData
    private let base: UnsafePointer<UInt8>
    private let keys: Section
    private let abbreviations: Section
    /// The longest key, in characters.
    public let maxKeyLength: Int

    private struct Section { let count: Int; let table: Int }

    static let magic: [UInt8] = Array("TTKD".utf8)
    static let version = 1

    public enum Failure: Error { case notADictionary(URL) }

    /// Opens a `.ttkd` file.
    public convenience init(contentsOf url: URL) throws {
        let data = try NSData(contentsOf: url, options: .alwaysMapped)
        guard data.length >= 28, Array(UnsafeRawBufferPointer(start: data.bytes, count: 4)) == Self.magic else {
            throw Failure.notADictionary(url)
        }
        self.init(data: data)
    }

    /// Builds a dictionary in memory (tests, and dictionaries made on the fly).
    /// - Parameter abbreviated: each word's abbreviation, for `abbreviated(_:)`.
    public convenience init(entries: [LexiconEntry], abbreviated: [(abbreviation: String, entry: LexiconEntry)] = []) {
        self.init(data: Self.encode(entries: entries, abbreviated: abbreviated) as NSData)
    }

    private init(data: NSData) {
        self.data = data
        base = data.bytes.assumingMemoryBound(to: UInt8.self)
        func u32(_ o: Int) -> Int { Int(UInt32(littleEndian: UnsafeRawPointer(data.bytes + o).loadUnaligned(as: UInt32.self))) }
        maxKeyLength = u32(8)
        keys = Section(count: u32(12), table: u32(16))
        abbreviations = Section(count: u32(20), table: u32(24))
    }

    public var count: Int { keys.count }

    /// Words typed exactly as `key`, most common first.
    public func exact(_ key: String) -> [LexiconEntry] { equal(Array(key.utf8), in: keys) }

    /// Words whose abbreviation is `abbreviation`, most common first.
    public func abbreviated(_ abbreviation: String) -> [LexiconEntry] { equal(Array(abbreviation.utf8), in: abbreviations) }

    /// Words whose key starts with `prefix` (excluding exact matches), most common first.
    public func prefixed(_ prefix: String, limit: Int) -> [LexiconEntry] {
        guard !prefix.isEmpty else { return [] }
        let p = Array(prefix.utf8)
        var found: [LexiconEntry] = []
        let start = lowerBound(p, in: keys)
        var i = start
        // Look at a bounded number of records so very short prefixes stay fast.
        while i < keys.count, i - start < 8000 {
            let r = record(i, in: keys)
            guard hasPrefix(r, p) else { break }
            if compareKey(r, p) != 0 { found.append(entry(r)) }
            i += 1
        }
        // Most common first; of equally common words, the shorter (closer to what was typed).
        found.sort { $0.cost != $1.cost ? $0.cost < $1.cost : ($0.key.count, $0.word) < ($1.key.count, $1.word) }
        return Array(found.prefix(limit))
    }

    // MARK: Reading records

    private func equal(_ k: [UInt8], in s: Section) -> [LexiconEntry] {
        var out: [LexiconEntry] = []
        var i = lowerBound(k, in: s)
        while i < s.count, compareKey(record(i, in: s), k) == 0 {
            out.append(entry(record(i, in: s)))
            i += 1
        }
        return out
    }

    private func u32(_ o: Int) -> Int { Int(UInt32(littleEndian: UnsafeRawPointer(base + o).loadUnaligned(as: UInt32.self))) }

    private func record(_ i: Int, in s: Section) -> UnsafePointer<UInt8> { base + u32(s.table + 4 * i) }

    /// Length of the record's key (the bytes before the first tab).
    private func keyLength(_ r: UnsafePointer<UInt8>) -> Int {
        var n = 0
        while r[n] != 9 { n += 1 }
        return n
    }

    private func compareKey(_ r: UnsafePointer<UInt8>, _ k: [UInt8]) -> Int {
        let n = keyLength(r)
        let c = k.withUnsafeBufferPointer { memcmp(r, $0.baseAddress!, min(n, k.count)) }
        return c != 0 ? Int(c) : n - k.count
    }

    private func hasPrefix(_ r: UnsafePointer<UInt8>, _ p: [UInt8]) -> Bool {
        keyLength(r) >= p.count && p.withUnsafeBufferPointer { memcmp(r, $0.baseAddress!, p.count) } == 0
    }

    private func lowerBound(_ k: [UInt8], in s: Section) -> Int {
        var lo = 0, hi = s.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if compareKey(record(mid, in: s), k) < 0 { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    private func entry(_ r: UnsafePointer<UInt8>) -> LexiconEntry {
        let k = keyLength(r)
        var w = k + 1
        while r[w] != 9 { w += 1 }
        var cost = 0
        var c = w + 1
        while r[c] != 10 { cost = cost * 10 + Int(r[c] - 48); c += 1 }
        return LexiconEntry(key: String(decoding: UnsafeBufferPointer(start: r, count: k), as: UTF8.self),
                            word: String(decoding: UnsafeBufferPointer(start: r + k + 1, count: w - k - 1), as: UTF8.self),
                            cost: cost)
    }

    // MARK: Writing

    /// Writes a `.ttkd` file.
    public static func write(entries: [LexiconEntry], abbreviated: [(abbreviation: String, entry: LexiconEntry)] = [],
                             to url: URL) throws {
        try encode(entries: entries, abbreviated: abbreviated).write(to: url, options: .atomic)
    }

    static func encode(entries: [LexiconEntry], abbreviated: [(abbreviation: String, entry: LexiconEntry)]) -> Data {
        func clean(_ s: String) -> [UInt8] {
            Array(s.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ").utf8)
        }
        struct Row { let key: [UInt8]; let word: [UInt8]; let cost: Int }
        func records(_ list: [(key: String, word: String, cost: Int)]) -> [[UInt8]] {
            var rows: [Row] = list.map { Row(key: clean($0.key), word: clean($0.word), cost: max(0, $0.cost)) }
            rows.removeAll { $0.key.isEmpty }
            rows.sort { a, b in a.key != b.key ? a.key.lexicographicallyPrecedes(b.key) : a.cost < b.cost }
            return rows.map { row -> [UInt8] in
                var r = row.key
                r.append(9); r += row.word
                r.append(9); r += Array(String(row.cost).utf8)
                r.append(10)
                return r
            }
        }
        let keyRecords = records(entries.map { ($0.key, $0.word, $0.cost) })
        let abbrRecords = records(abbreviated.map { ($0.abbreviation, $0.entry.word, $0.entry.cost) })
        let keyTable = 28
        let abbrTable = keyTable + 4 * keyRecords.count
        var offset = abbrTable + 4 * abbrRecords.count
        var out = Data()
        out.reserveCapacity(offset + keyRecords.reduce(0) { $0 + $1.count } + abbrRecords.reduce(0) { $0 + $1.count })
        func put(_ v: Int) { var x = UInt32(v).littleEndian; withUnsafeBytes(of: &x) { out.append(contentsOf: $0) } }
        out.append(contentsOf: magic)
        put(version)
        put(entries.map(\.key.count).max() ?? 0)
        put(keyRecords.count); put(keyTable)
        put(abbrRecords.count); put(abbrTable)
        for r in keyRecords + abbrRecords { put(offset); offset += r.count }
        for r in keyRecords + abbrRecords { out.append(contentsOf: r) }
        return out
    }
}

extension Lexicon {
    /// Reads a `key<TAB>word<TAB>cost` text file (the old format, and dictgen's intermediate output).
    /// - Parameter normalizeKey: turns the key as written in the file into the typed key
    ///   (for pinyin, drops the `'` between syllables).
    /// - Parameter abbreviate: the abbreviation of the key as written in the file, if it has one.
    public static func readText(_ url: URL, normalizeKey: (Substring) -> String = { String($0) },
                                abbreviate: (Substring) -> String? = { _ in nil })
        throws -> (entries: [LexiconEntry], abbreviated: [(abbreviation: String, entry: LexiconEntry)]) {
        let text = try String(contentsOf: url, encoding: .utf8)
        var entries: [LexiconEntry] = []
        var abbreviated: [(abbreviation: String, entry: LexiconEntry)] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count == 3, let cost = Int(parts[2]) else { continue }
            let entry = LexiconEntry(key: normalizeKey(parts[0]), word: String(parts[1]), cost: cost)
            entries.append(entry)
            if let a = abbreviate(parts[0]) { abbreviated.append((a, entry)) }
        }
        return (entries, abbreviated)
    }

    /// Opens a text dictionary by building it in memory.
    public convenience init(text url: URL, normalizeKey: (Substring) -> String = { String($0) },
                            abbreviate: (Substring) -> String? = { _ in nil }) throws {
        let t = try Self.readText(url, normalizeKey: normalizeKey, abbreviate: abbreviate)
        self.init(entries: t.entries, abbreviated: t.abbreviated)
    }
}
