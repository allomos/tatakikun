#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import TatakikunCore

// Prints Tatakikun's candidates for each word given (or each line on standard input).
// Usage: tatakikun-cli [--dict <folder> | --packs <folder>] [--more <n>] [--phone] <letters>...
//   --dict   base dictionaries (zh.ttkd, ja.ttkd) with the system spell checker for English (default build/dict)
//   --packs  language packs (<folder>/<lang>/<lang>.ttkd), only the languages found
//   --phone  as the phone keyboards: also words with a letter on a neighbouring key (nihai → 你好)
var args = Array(CommandLine.arguments.dropFirst())
var dict = ProcessInfo.processInfo.environment["TATAKIKUN_DICT"] ?? "build/dict"
var packs: String?
var moreCount = 10
var phone = false
while let flag = args.first, flag.hasPrefix("--") {
    args.removeFirst()
    if flag == "--phone" { phone = true; continue }
    guard !args.isEmpty else { break }
    switch flag {
    case "--dict": dict = args.removeFirst()
    case "--packs": packs = args.removeFirst()
    case "--more": moreCount = Int(args.removeFirst()) ?? moreCount
    default: break
    }
}
let engine = try packs.map { try Engine(packFolders: [URL(fileURLWithPath: $0)]) }
    ?? Engine(dictionaryFolder: URL(fileURLWithPath: dict))
engine.nearbyKeyCorrections = phone
func show(_ input: String) {
    let list = engine.candidates(for: input)
    func fmt(_ c: Candidate) -> String { "\(c.text)[\(c.kind.tag)\(c.consumed.map { "…\($0)" } ?? (c.isExact ? "" : "…"))]" }
    print("\(input): " + list.firstRow.enumerated().map { "\($0.offset + 1).\(fmt($0.element))" }.joined(separator: "  "))
    if moreCount > 0, !list.more.isEmpty {
        print("  more: " + list.more.prefix(moreCount).map(fmt).joined(separator: "  "))
    }
}
if args.isEmpty {
    while let line = readLine() { show(String(line.drop { $0.isWhitespace }.reversed().drop { $0.isWhitespace }.reversed())) }
} else {
    args.forEach(show)
}
