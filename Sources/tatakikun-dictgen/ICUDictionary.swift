import Foundation

/// Reads the CJK word list (`brkitr/cjdict.dict`) out of the system ICU data file.
/// The list is a UCharsTrie whose values are costs: lower means more frequent.
struct ICUDictionary {
    enum Failure: Error { case noICUData, noCJDict, badFormat }

    static func defaultDataPath() throws -> String {
        let dir = "/usr/share/icu"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        guard let name = names.filter({ $0.hasPrefix("icudt") && $0.hasSuffix("l.dat") }).sorted().last else {
            throw Failure.noICUData
        }
        return dir + "/" + name
    }

    /// Every (word, cost) pair in cjdict.
    static func readCJDict(path: String) throws -> [(String, Int)] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> [(String, Int)] in
            func u16(_ o: Int) -> Int { Int(raw.loadUnaligned(fromByteOffset: o, as: UInt16.self).littleEndian) }
            func u32(_ o: Int) -> Int { Int(raw.loadUnaligned(fromByteOffset: o, as: UInt32.self).littleEndian) }
            // Common data package: header, then a table of contents of (nameOffset, dataOffset).
            let headerSize = u16(0)
            let count = u32(headerSize)
            var itemOffset: Int?
            for i in 0..<count {
                let nameOff = headerSize + u32(headerSize + 4 + 8 * i)
                let dataOff = headerSize + u32(headerSize + 8 + 8 * i)
                var end = nameOff
                while raw[end] != 0 { end += 1 }
                let name = String(decoding: UnsafeRawBufferPointer(rebasing: raw[nameOff..<end]), as: UTF8.self)
                if name.hasSuffix("/brkitr/cjdict.dict") { itemOffset = dataOff; break }
            }
            guard let item = itemOffset else { throw Failure.noCJDict }
            let body = item + u16(item)
            let trieOffset = Int(Int32(truncatingIfNeeded: u32(body)))
            let totalSize = Int(Int32(truncatingIfNeeded: u32(body + 12)))
            let trieType = u32(body + 16)
            guard trieType & 7 == 1 else { throw Failure.badFormat } // UChars trie
            let start = body + trieOffset
            let units = (0..<((totalSize - trieOffset) / 2)).map { UInt16(u16(start + 2 * $0)) }
            var walker = TrieWalker(u: units)
            walker.walk(0, [])
            return walker.out
        }
    }
}

/// Enumerates a UCharsTrie (format from ICU's ucharstrie.h).
private struct TrieWalker {
    let u: [UInt16]
    var out: [(String, Int)] = []

    func at(_ p: Int) -> Int { Int(u[p]) }

    func readValue(_ pos: Int, _ lead: Int) -> (Int, Int) {
        if lead < 0x4000 { return (lead, pos) }
        if lead < 0x7fff { return (((lead - 0x4000) << 16) | at(pos), pos + 1) }
        return ((at(pos) << 16) | at(pos + 1), pos + 2)
    }

    func readNodeValue(_ pos: Int, _ lead: Int) -> (Int, Int) {
        if lead < 0x4040 { return ((lead >> 6) - 1, pos) }
        if lead < 0x7fc0 { return ((((lead & 0x7fc0) - 0x4040) << 10) | at(pos), pos + 1) }
        return ((at(pos) << 16) | at(pos + 1), pos + 2)
    }

    func jumpByDelta(_ p: Int) -> Int {
        var pos = p
        var delta = at(pos); pos += 1
        if delta >= 0xfc00 {
            if delta == 0xffff { delta = (at(pos) << 16) | at(pos + 1); pos += 2 }
            else { delta = ((delta - 0xfc00) << 16) | at(pos); pos += 1 }
        }
        return pos + delta
    }

    func skipDelta(_ p: Int) -> Int {
        let delta = at(p)
        if delta >= 0xfc00 { return p + 1 + (delta == 0xffff ? 2 : 1) }
        return p + 1
    }

    mutating func emit(_ s: [UInt16], _ v: Int) { out.append((String(decoding: s, as: UTF16.self), v)) }

    mutating func walk(_ p: Int, _ prefix: [UInt16]) {
        var pos = p
        var s = prefix
        while true {
            var node = at(pos); pos += 1
            if node >= 0x40 {
                if node & 0x8000 != 0 {
                    emit(s, readValue(pos, node & 0x7fff).0)
                    return
                }
                let (v, next) = readNodeValue(pos, node)
                emit(s, v)
                pos = next
                node &= 0x3f
            }
            if node < 0x30 {
                if node == 0 { node = at(pos); pos += 1 }
                branch(pos, node + 1, s)
                return
            }
            let n = node - 0x30 + 1
            s.append(contentsOf: u[pos..<(pos + n)])
            pos += n
        }
    }

    mutating func branch(_ p: Int, _ len: Int, _ s: [UInt16]) {
        var pos = p
        var length = len
        while length > 5 {
            pos += 1
            branch(skipDelta(pos), length - (length >> 1), s)
            length >>= 1
            pos = jumpByDelta(pos)
        }
        for _ in 0..<(length - 1) {
            let c = u[pos]; pos += 1
            let node = at(pos); pos += 1
            let (v, next) = readValue(pos, node & 0x7fff)
            pos = next
            if node & 0x8000 != 0 { emit(s + [c], v) } else { walk(pos + v, s + [c]) }
        }
        let c = u[pos]; pos += 1
        walk(pos, s + [c])
    }
}
