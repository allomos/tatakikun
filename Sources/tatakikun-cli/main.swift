import Foundation
import TatakikunCore

// Prints Tatakikun's candidates for each word given (or each line on standard input).
// Usage: tatakikun-cli [--dict <folder>] [--more <n>] <letters>...
var args = Array(CommandLine.arguments.dropFirst())
var dict = ProcessInfo.processInfo.environment["TATAKIKUN_DICT"] ?? "build/dict"
var moreCount = 10
while let flag = args.first, flag.hasPrefix("--") {
    args.removeFirst()
    guard !args.isEmpty else { break }
    switch flag {
    case "--dict": dict = args.removeFirst()
    case "--more": moreCount = Int(args.removeFirst()) ?? moreCount
    default: break
    }
}
let engine = try Engine(dictionaryFolder: URL(fileURLWithPath: dict))
func show(_ input: String) {
    let list = engine.candidates(for: input)
    func fmt(_ c: Candidate) -> String { "\(c.text)[\(c.kind.tag)\(c.consumed.map { "…\($0)" } ?? (c.isExact ? "" : "…"))]" }
    print("\(input): " + list.firstRow.enumerated().map { "\($0.offset + 1).\(fmt($0.element))" }.joined(separator: "  "))
    if moreCount > 0, !list.more.isEmpty {
        print("  more: " + list.more.prefix(moreCount).map(fmt).joined(separator: "  "))
    }
}
if args.isEmpty {
    while let line = readLine() { show(line.trimmingCharacters(in: .whitespaces)) }
} else {
    args.forEach(show)
}
