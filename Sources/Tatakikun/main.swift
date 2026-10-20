import AppKit
import InputMethodKit
import TatakikunCore

enum TatakikunApp {
    /// The dictionaries are in the app bundle's Resources/dict (or TATAKIKUN_DICT, for development).
    static let engine: Engine = {
        let folder = ProcessInfo.processInfo.environment["TATAKIKUN_DICT"].map { URL(fileURLWithPath: $0) }
            ?? Bundle.main.resourceURL!.appendingPathComponent("dict")
        do {
            return try Engine(dictionaryFolder: folder)
        } catch {
            NSLog("Tatakikun: cannot load dictionaries from \(folder.path): \(error)")
            return Engine(chinese: Lexicon(entries: []), japanese: Lexicon(entries: []), english: SystemEnglish())
        }
    }()
    static let panel = CandidatePanel()
    static var server: IMKServer?
}

let app = NSApplication.shared
let arguments = CommandLine.arguments
if let i = arguments.firstIndex(of: "--snapshot"), i + 2 < arguments.count {
    // Tatakikun --snapshot <letters> <out.png> [dark] [keys=down,right,...]: draw the panel after
    // typing those letters (and pressing those keys), then exit.
    let composer = Composer(engine: TatakikunApp.engine)
    arguments[i + 1].forEach { _ = composer.handle(.letter($0)) }
    let names: [String: Key] = ["down": .down, "up": .up, "left": .left, "right": .right, "tab": .tab, "esc": .escape]
    for arg in arguments where arg.hasPrefix("keys=") {
        for name in arg.dropFirst(5).split(separator: ",") { if let key = names[String(name)] { _ = composer.handle(key) } }
    }
    try PanelContentView.snapshot(composer, to: URL(fileURLWithPath: arguments[i + 2]),
                                  appearance: arguments.contains("dark") ? .darkAqua : .aqua)
    exit(0)
}
if CommandLine.arguments.contains("--demo") {
    // A window that types through the same composer and panel, for trying Tatakikun without installing it.
    let demo = DemoWindow()
    app.setActivationPolicy(.regular)
    demo.makeKeyAndOrderFront(nil)
    app.activate(ignoringOtherApps: true)
} else {
    let connection = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String
        ?? "com.tatakikun.inputmethod.Tatakikun_Connection"
    TatakikunApp.server = IMKServer(name: connection, bundleIdentifier: Bundle.main.bundleIdentifier)
}
_ = TatakikunApp.engine // load the dictionaries now, not on the first key press
app.run()
