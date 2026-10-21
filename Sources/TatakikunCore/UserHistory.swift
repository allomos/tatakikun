#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Remembers which candidate was chosen for which letters, so it ranks higher next time.
/// Kept only on this Mac, in a small `input<TAB>text<TAB>count` file.
public final class UserHistory {
    private var counts: [String: Int] = [:]
    private let url: URL?

    /// ~/Library/Application Support/Tatakikun/history.tsv
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tatakikun/history.tsv")
    }

    /// With no `url` the history lives in memory only.
    public init(url: URL?) {
        self.url = url
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            if parts.count == 3, let n = Int(parts[2]) { counts[parts[0] + "\t" + parts[1]] = n }
        }
    }

    public func count(input: String, text: String) -> Int { counts[input.lowercased() + "\t" + text] ?? 0 }

    /// How much cheaper a candidate becomes: enough after one choice to move it to the front
    /// of words with similar frequency, growing with more choices.
    public func boost(input: String, text: String) -> Int {
        let n = count(input: input, text: text)
        return n == 0 ? 0 : min(100, 40 + 20 * (n - 1))
    }

    public func record(input: String, text: String) {
        guard !input.isEmpty, !text.isEmpty, !input.contains("\t"), !text.contains("\t") else { return }
        counts[input.lowercased() + "\t" + text, default: 0] += 1
        save()
    }

    public func clear() {
        counts = [:]
        save()
    }

    private func save() {
        guard let url else { return }
        let text = counts.map { "\($0.key)\t\($0.value)" }.sorted().joined(separator: "\n") + "\n"
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
