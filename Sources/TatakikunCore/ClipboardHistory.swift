#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The text copied lately, newest first, for the phone keyboard's clipboard list; the latest copy
/// is also offered as a chip for a while, until it is pasted from there. Kept only on the device,
/// in a small JSON file.
public final class ClipboardHistory {
    /// How many copies the list keeps: the oldest drop off.
    public static let limit = 30
    /// Longer copies are left out: the list is for snippets, not whole documents.
    public static let longest = 20_000
    /// How long the latest copy is offered as a chip, in seconds.
    public static let chipTime: Double = 10 * 60

    private struct Stored: Codable {
        var items: [String]
        var chip: String?
        var chipSince: Date?
    }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tatakikun/clipboard.json")
    }

    public private(set) var items: [String] = []
    private var chipText: String?
    private var chipSince: Date?
    private let url: URL?

    /// With no `url` the history lives in memory only.
    public init(url: URL?) {
        self.url = url
        guard let url, let data = try? Data(contentsOf: url), let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        items = stored.items
        chipText = stored.chip
        chipSince = stored.chipSince
    }

    /// Records a copy: it goes on top (moved up when it is there already) and becomes the chip.
    /// Blank or very long text is left out.
    public func add(_ text: String, at date: Date = Date()) {
        guard !text.allSatisfy(\.isWhitespace), text.count <= Self.longest else { return }
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
        chipText = text
        chipSince = date
        save()
    }

    /// The latest copy while it is offered as a chip.
    public func chip(at date: Date = Date()) -> String? {
        guard let chipText, let chipSince, date.timeIntervalSince(chipSince) < Self.chipTime, items.first == chipText else { return nil }
        return chipText
    }

    /// The chip was used: it goes away (the copy stays in the list).
    public func dismissChip() {
        chipText = nil
        chipSince = nil
        save()
    }

    public func remove(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        save()
    }

    public func clear() {
        items = []
        chipText = nil
        chipSince = nil
        save()
    }

    private func save() {
        guard let url, let data = try? JSONEncoder().encode(Stored(items: items, chip: chipText, chipSince: chipSince)) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
