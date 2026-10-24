#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One slip of the fingers on a QWERTY keyboard, and the letters as they were meant.
enum Slip {
    /// Where each key sits: rows staggered as on a keyboard (a is half a key right of q, z a whole key).
    static let positions: [Character: (x: Double, y: Double)] = {
        var out: [Character: (x: Double, y: Double)] = [:]
        for (y, (row, offset)) in [("qwertyuiop", 0.0), ("asdfghjkl", 0.5), ("zxcvbnm", 1.0)].enumerated() {
            for (i, c) in row.enumerated() { out[c] = (Double(i) + offset, Double(y)) }
        }
        return out
    }()

    /// Whether what the letters give as typed is a likely reading: as cheap per letter as common words.
    static func isGood(_ cost: Int, letters: Int) -> Bool { cost <= Cost.slipSentenceLetter * letters }

    /// The keys touching each key: left and right, and the two above and below (g: f h t y v b).
    static let neighbours: [Character: [Character]] = {
        var out: [Character: [Character]] = [:]
        for (c, p) in positions {
            out[c] = positions.filter { k, q in
                k != c && ((q.y == p.y && abs(q.x - p.x) == 1) || (abs(q.y - p.y) == 1 && abs(q.x - p.x) <= 0.5))
            }.map(\.key).sorted()
        }
        return out
    }()

    /// The letters as they might have been meant, each with what the slip costs and whether to read
    /// whole sentences from them too: a neighbouring key (nihai → nihao), a letter too many (nihaoo),
    /// two letters swapped (nihoa); and, for words only (there are many), a letter left out (nhao).
    /// Nothing at the very end: a letter more there is the word being typed (completions cover it).
    static func variants(of letters: [Character]) -> [(key: String, cost: Int, sentences: Bool)] {
        var out: [(key: String, cost: Int, sentences: Bool)] = []
        for i in letters.indices {
            for n in neighbours[letters[i]] ?? [] {
                var fixed = letters
                fixed[i] = n
                out.append((String(fixed), Cost.nearbyKey, true))
            }
            // Not the last letter: that is still being typed, and choosing a word for the letters
            // before it already leaves it to go on with (renmina: 人民, then a).
            if letters.count > 3, i + 1 < letters.count {
                var fewer = letters
                fewer.remove(at: i)
                out.append((String(fewer), Cost.otherSlip, true))
            }
            if i + 1 < letters.count, letters[i] != letters[i + 1] {
                var swapped = letters
                swapped.swapAt(i, i + 1)
                out.append((String(swapped), Cost.otherSlip, true))
            }
        }
        // A letter left out could be any letter anywhere: only for short inputs, where it is cheap.
        for i in 0..<letters.count where letters.count <= Cost.leftOutLetters {
            for c in "abcdefghijklmnopqrstuvwxyz" where i == 0 || letters[i - 1] != c {
                var more = letters
                more.insert(c, at: i)
                out.append((String(more), Cost.otherSlip, false))
            }
        }
        return out
    }
}

extension Engine {
    /// What the letters give after one slip (`Slip.variants`), dearer than what was typed and shown as
    /// not typed exactly: Chinese and Japanese words, and whole sentences (wozaijua → 我在家). A slip
    /// is likely only when what it gives is at least as common as what the letters give as typed
    /// (`typedCost`), so a word typed right keeps a clean bar (nihao: no 怒号); a sentence only when it is
    /// as cheap per letter as common words (`Cost.slipSentenceLetter`), not rare characters (啊日伽头).
    /// Slips in another language than the best reading as typed (`language`) cost a little more.
    func slipCandidates(for input: String, typedCost: Int, language: Language? = nil) -> [Candidate] {
        func slip(_ text: String, _ kind: CandidateKind, _ cost: Int, _ extra: Int) -> Candidate? {
            guard cost <= typedCost else { return nil }
            // Never ahead of a good reading of the letters as typed (他们去那了 stays first), but still
            // in their own order; ahead of a poor one (には大 for nihaoo: 你好 first).
            var total = cost + extra + (language.map { $0 == Language(kind) ? 0 : Cost.slipOtherLanguage } ?? 0)
            if Slip.isGood(typedCost, letters: letters.count), total <= typedCost { total = typedCost + 1 + total / 16 }
            var c = Candidate(text: text, kind: kind, cost: total, isExact: false)
            c.isSlip = true
            return c
        }
        var best: [String: Candidate] = [:]
        func offer(_ c: Candidate?) {
            guard let c else { return }
            if best[c.text].map({ c.cost < $0.cost }) ?? true { best[c.text] = c }
        }
        let letters = Array(input.lowercased())
        // Reading a sentence for every variant takes long on long inputs: words only there.
        let sentences = letters.count <= Cost.slipSentenceLetters
        for v in Slip.variants(of: letters) where v.key != String(letters) {
            if let chinese {
                for e in chinese.lexicon.exact(v.key).prefix(3) { offer(slip(e.word, .chinese, e.cost, v.cost)) }
                if sentences, v.sentences, let path = segmentations(Array(v.key), lexicon: chinese.lexicon, count: 1).first, path.words.count > 1,
                   path.cost <= Cost.slipSentenceLetter * v.key.count {
                    offer(slip(path.words.joined(), .chinese, path.cost, v.cost))
                }
            }
            if let japanese, let kana = Romaji.toHiragana(v.key) {
                for e in japanese.lexicon.exact(kana).prefix(3) { offer(slip(e.word, JapaneseConverter.kind(of: e.word), e.cost, v.cost)) }
                if sentences, v.sentences, let path = segment(Array(kana), lexicon: japanese.lexicon), path.words.count > 1,
                   path.cost <= Cost.slipSentenceLetter * kana.count * 2 {
                    let text = path.words.joined()
                    offer(slip(text, JapaneseConverter.kind(of: text), path.cost, v.cost))
                }
            }
        }
        return Array(best.values.sorted { ($0.cost, $0.text) < ($1.cost, $1.text) }.prefix(Cost.nearbyKeyWords))
    }
}
