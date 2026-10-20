import Foundation
import TatakikunCore

// Builds Tatakikun's dictionaries.
//   tatakikun-dictgen <output folder> [icu data file]
//       the base zh/ja dictionaries from this Mac's data (SystemDictionaries.swift)
//   tatakikun-dictgen --compile <folder>
//       turn existing zh.tsv / ja.tsv into .ttkd files
//   tatakikun-dictgen pack <zh|ja|en> <base folder> <sources folder> <output folder>
//       a language pack from the base dictionaries and the downloaded open data (Packs.swift)

let args = CommandLine.arguments
if args.count == 3, args[1] == "--compile" {
    let dir = URL(fileURLWithPath: args[2])
    try DictionaryFiles.compileChinese(text: dir.appendingPathComponent("zh.tsv"), to: dir.appendingPathComponent(DictionaryFiles.chinese))
    try DictionaryFiles.compileJapanese(text: dir.appendingPathComponent("ja.tsv"), to: dir.appendingPathComponent(DictionaryFiles.japanese))
} else if args.count == 6, args[1] == "pack" {
    let (base, sources, out) = (URL(fileURLWithPath: args[3]), URL(fileURLWithPath: args[4]), URL(fileURLWithPath: args[5]))
    switch args[2] {
    case "zh": try buildChinesePack(base: base, sources: sources, out: out)
    case "ja": try buildJapanesePack(base: base, sources: sources, out: out)
    case "en": try buildEnglishPack(sources: sources, out: out)
    default: log("unknown language \(args[2]): use zh, ja or en"); exit(2)
    }
} else if args.count >= 2, !args[1].hasPrefix("-") {
    try buildSystemDictionaries(outDir: URL(fileURLWithPath: args[1]),
                                icuPath: args.count >= 3 ? args[2] : try ICUDictionary.defaultDataPath())
} else {
    log("usage: tatakikun-dictgen <output folder> [icu data file] | --compile <folder> | pack <zh|ja|en> <base> <sources> <out>")
    exit(2)
}
