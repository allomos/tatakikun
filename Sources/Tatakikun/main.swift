import AppKit
import InputMethodKit
import TatakikunCore

enum TatakikunApp {
    /// The installed language packs (see LanguagePacks); TATAKIKUN_DICT, for development, uses the
    /// base dictionaries in that folder with the system spell checker for English.
    static let engine: Engine = {
        do {
            if let folder = ProcessInfo.processInfo.environment["TATAKIKUN_DICT"] {
                return try Engine(dictionaryFolder: URL(fileURLWithPath: folder))
            }
            let engine = try Engine()
            if engine.languages.isEmpty {
                NSLog("Tatakikun: no language packs in \(LanguagePacks.defaultFolders.map(\.path)); only the letters as typed are offered")
            }
            return engine
        } catch {
            NSLog("Tatakikun: cannot load the language packs: \(error)")
            return Engine(chinese: nil, japanese: nil, english: nil)
        }
    }()
    static let panel = CandidatePanel()
    static var server: IMKServer?

    /// The installed languages in the order the input menu shows them, with their names.
    static var languageNames: [(language: LanguagePacks.Language, name: String)] {
        [(.en, "English"), (.zh, "中文"), (.ja, "日本語"), (.es, "Español"), (.fr, "Français"), (.hi, "हिन्दी"), (.bn, "বাংলা"), (.ar, "العربية")].filter { engine.languages.contains($0.0) }
    }

    /// The languages turned off in the input menu, kept in the input method's defaults; setting it
    /// applies it to the engine at once.
    static var turnedOff: Set<LanguagePacks.Language> {
        get { Set((UserDefaults.standard.stringArray(forKey: "languagesOff") ?? []).compactMap(LanguagePacks.Language.init)) }
        set {
            UserDefaults.standard.set(newValue.map(\.rawValue).sorted(), forKey: "languagesOff")
            engine.turnedOff = newValue
        }
    }
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
// Learning from choices and the languages turned off (not for snapshots, which should look the same every time).
TatakikunApp.engine.history = UserHistory(url: UserHistory.defaultURL)
TatakikunApp.engine.turnedOff = TatakikunApp.turnedOff
TatakikunApp.engine.customWords = CustomWords(url: CustomWords.defaultURL)
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
