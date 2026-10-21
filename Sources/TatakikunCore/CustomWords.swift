#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Words the user built by hand (two picks, or a candidate other than the first), remembered under
/// the letters typed so they are offered as one candidate next time. Kept only on this device, in a
/// small `input<TAB>word<TAB>kind` file next to the learning data.
public final class CustomWords {
    private var words: [String: [(word: String, kind: CandidateKind)]] = [:]
    private let url: URL?

    /// Results this long are remembered: one character is already a candidate, longer ones are phrases.
    public static let lengths = 2...4

    /// ~/Library/Application Support/Tatakikun/custom-words.tsv
    public static var defaultURL: URL {
        UserHistory.defaultURL.deletingLastPathComponent().appendingPathComponent("custom-words.tsv")
    }

    /// With no `url` the words live in memory only.
    public init(url: URL?) {
        self.url = url
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") {
            let p = line.split(separator: "\t", omittingEmptySubsequences: false)
            if p.count == 3, let kind = CandidateKind(rawValue: String(p[2])) { insert(String(p[0]), String(p[1]), kind) }
        }
    }

    /// The words remembered for these letters.
    public func words(for input: String) -> [(word: String, kind: CandidateKind)] { words[input.lowercased()] ?? [] }

    /// Remembers `word` for `input` when it is 2–4 Chinese or Japanese characters; false otherwise.
    @discardableResult
    public func add(input: String, word: String, kind: CandidateKind) -> Bool {
        guard Self.lengths.contains(word.count), [.chinese, .kanji, .hiragana, .katakana].contains(kind),
              !input.isEmpty, !input.contains("\t"), !word.contains("\t"), !word.contains("\n") else { return false }
        guard insert(input.lowercased(), word, kind) else { return true }
        save()
        return true
    }

    /// False when it was already there (it moves to the front).
    @discardableResult
    private func insert(_ input: String, _ word: String, _ kind: CandidateKind) -> Bool {
        var list = words[input] ?? []
        let isNew = !list.contains { $0.word == word }
        list.removeAll { $0.word == word }
        list.insert((word, kind), at: 0)
        words[input] = list
        return isNew
    }

    public func clear() {
        words = [:]
        save()
    }

    private func save() {
        guard let url else { return }
        let lines = words.flatMap { input, list in list.reversed().map { "\(input)\t\($0.word)\t\($0.kind.rawValue)" } }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? (lines.sorted().joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
