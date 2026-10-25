import SwiftUI
import TatakikunCore

/// The app only holds the keyboard: it tells how to turn it on and gives a field to try it in.
@main
struct TatakikunApp: App {
    /// The Try it field follows the language switches too.
    init() { Shared.engine.turnedOff = Settings.turnedOff }

    var body: some Scene {
        WindowGroup { SetupView() }
    }
}

/// Light and dark colours, from one purple ramp: the same as the Android app's.
private enum Palette {
    static func color(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) })
    }
    private static func rgb(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat(v >> 16 & 0xff) / 255, green: CGFloat(v >> 8 & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
    static let page = color(0xFBFAFF, 0x1B1B1F)
    static let text = color(0x1C1B1F, 0xE6E1E5)
    static let secondary = color(0x5F5E66, 0xA9A6B0)
    static let divider = Color.primary.opacity(0.12)
    static let heroBackground = color(0xEEEDFE, 0x2F2A5C)
    static let heroTitle = color(0x26215C, 0xEEEDFE)
    static let heroText = color(0x3C3489, 0xCECBF6)
    static let chip = color(0xFFFFFF, 0x3C3489)
    static let accent = color(0x534AB7, 0xAFA9EC)
    static let done = color(0x3B6D11, 0x97C459)
    static let pillBackground = color(0xEEEDFE, 0x3C3489)
    static let pillText = color(0x3C3489, 0xEEEDFE)
}

/// The first screen, laid out like the Android app's: a header with sample candidates, the setup
/// steps (whether the keyboard is added is checked again whenever the app comes back), the
/// language packs and version, and a field to try the keyboard in.
struct SetupView: View {
    @State private var added = SetupView.keyboardAdded()
    @State private var off = Settings.turnedOff
    @State private var showsLanguages = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var openURL

    private static let keyboardID = "com.tatakikun.ios.Tatakikun.Keyboard"
    private static let projectURL = URL(string: "https://github.com/allomos/tatakikun")!

    /// Whether Tatakikun is among the keyboards added in Settings.
    static func keyboardAdded() -> Bool {
        (UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String])?.contains(keyboardID) == true
    }

    /// The language packs inside the keyboard, in the Android app's order.
    private static let packs: [(language: LanguagePacks.Language, name: String)] = {
        let folder = Bundle.main.builtInPlugInsURL?.appendingPathComponent("TatakikunKeyboard.appex/packs")
        let present = Set((try? FileManager.default.contentsOfDirectory(atPath: folder?.path ?? "")) ?? [])
        return [(.en, "English"), (.zh, "中文"), (.ja, "日本語"), (.es, "Español")].filter { present.contains($0.0.rawValue) }
    }()

    /// The packs turned on in Input languages.
    private var packsOn: [String] { Self.packs.filter { !off.contains($0.language) }.map(\.name) }

    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        hero.padding(.top, 12)

                        section("Set up")
                        SettingsRow(icon: added ? "checkmark.circle.fill" : "circle", iconColor: added ? Palette.done : Palette.accent,
                                    title: "Turn on Tatakikun",
                                    detail: added ? "Done" : "Settings → General → Keyboard → Keyboards → Add New Keyboard… → Tatakikun",
                                    detailColor: added ? Palette.done : Palette.secondary, action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        })
                        .accessibilityIdentifier("openSettings")
                        divider
                        SettingsRow(icon: "globe", iconColor: Palette.accent, title: "Choose it as your keyboard",
                                    detail: added ? "Hold 🌐 on the keyboard and pick Tatakikun" : "After you turn it on")
                        divider
                        fullAccess

                        section("Keyboard")
                        SettingsRow(icon: "character.bubble", title: "Language packs", detail: packsOn.joined(separator: " · "),
                                    action: { showsLanguages = true }) {
                            Text("\(packsOn.count)")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Palette.pillText)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(Capsule().fill(Palette.pillBackground))
                        }
                        .accessibilityIdentifier("languagePacks")

                        section("Try it")
                        TryField(placeholder: "ai, woaini, arigatou, hello") {
                            // Once the keys are up, scroll the field to just above them.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation { scroll.scrollTo("tryField", anchor: .bottom) }
                            }
                        }
                        .frame(height: 104)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.accent, lineWidth: 1))
                        .id("tryField")
                        help("Types with Tatakikun's keys built into this app, even before you turn the keyboard on.")
                            .padding(.horizontal, 4).padding(.top, 8)
                        section("Keys")
                        VStack(alignment: .leading, spacing: 8) {
                            help("Letters show English, Chinese and Japanese candidates in one bar. Space inserts the first candidate (with a space after an English word), return inserts the letters as typed, tap a candidate to insert it, ⌄ shows more.")
                            help("Hold a letter for the symbol in its corner (g → &); slide to pick it half-width or full-width.")
                            help("The comma and period keys show what they type: ，。 after Chinese, 、。 after Japanese, , . after English.")
                            if Self.isPad {
                                help("Hold ctrl and tap c to copy the selected text, or v to cut it (needs Full Access).")
                            }
                        }
                        .padding(.horizontal, 4)

                        // About comes last, under everything else.
                        Palette.divider.frame(height: 1).padding(.top, 24)
                        SettingsRow(icon: "info.circle", title: "About", detail: "Open source, MIT license", action: { openURL(Self.projectURL) }) {
                            Text("v\(version)").font(.subheadline).foregroundStyle(Palette.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .background(Palette.page.ignoresSafeArea())
                .scrollDismissesKeyboard(.interactively)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showsLanguages) {
                    LanguagesView(off: $off, languages: Self.packs)
                }
            }
        }
        .onChange(of: off) { Settings.turnedOff = $0 }
        .tint(Palette.accent)
        .onChange(of: phase) { now in if now == .active { added = Self.keyboardAdded() } }
    }

    private static let isPad = UIDevice.current.userInterfaceIdiom == .pad

    /// Full Access, explained before iOS shows its own warning: what it is for, and that typed
    /// text is not sent anywhere (the app and keyboard have no networking at all). It is optional:
    /// without it the keyboard uses every language and has no copy or cut.
    private var fullAccess: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(icon: "lock.shield", iconColor: Palette.accent, title: "Allow Full Access",
                        detail: "Settings → General → Keyboard → Keyboards → Tatakikun → Allow Full Access", action: {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            })
            .accessibilityIdentifier("fullAccess")
            help((Self.isPad
                  ? "Optional. Tatakikun needs it only to follow the input languages you choose in this app and to copy and cut with the ctrl key: iOS lets a keyboard read an app's settings or use the clipboard only with Full Access."
                  : "Optional. Tatakikun needs it only to follow the input languages you choose in this app: iOS lets a keyboard read an app's settings only with Full Access.")
                 + " iOS will warn that a keyboard with Full Access could send what you type. Tatakikun never does: it has no network code, and what you type stays on this device.")
                .padding(.leading, 46).padding(.trailing, 4).padding(.bottom, 8)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tatakikun").font(.system(size: 30, weight: .medium)).foregroundStyle(Palette.heroTitle)
            Text("Type letters, get English, Chinese and Japanese in one candidate bar.")
                .font(.system(size: 15)).foregroundStyle(Palette.heroText)
                .lineSpacing(2)
                .padding(.top, 6).padding(.bottom, 14)
            HStack(spacing: 8) {
                ForEach(["hello", "我爱你", "ありがとう"], id: \.self) { sample in
                    Text(sample).font(.system(size: 14)).foregroundStyle(Palette.heroText)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.chip))
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 28).fill(Palette.heroBackground))
    }

    private func section(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Palette.accent)
            .padding(.horizontal, 4).padding(.top, 24).padding(.bottom, 6)
    }

    private func help(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private var divider: some View { Palette.divider.frame(height: 1).padding(.leading, 46) }
}

/// Input languages: a switch for each installed pack; only the languages that are on give
/// candidates, and the last one on cannot be turned off.
struct LanguagesView: View {
    @Binding var off: Set<LanguagePacks.Language>
    let languages: [(language: LanguagePacks.Language, name: String)]

    var body: some View {
        List {
            Section {
                ForEach(languages, id: \.language) { pack in
                    let on = !off.contains(pack.language)
                    Toggle(pack.name, isOn: Binding(get: { on }, set: { now in
                        if now { off.remove(pack.language) } else { off.insert(pack.language) }
                    }))
                    .disabled(on && languages.filter { !off.contains($0.language) }.count == 1)
                    .accessibilityIdentifier("language-\(pack.language.rawValue)")
                }
            } footer: {
                Text("Only the languages that are on give candidates. At least one language stays on.\n\nThe Tatakikun keyboard follows these switches when Full Access is allowed (Set up → Allow Full Access); without it, it uses every language. The Try it field always follows them.")
            }
        }
        .navigationTitle("Input languages")
        .toolbar(.visible, for: .navigationBar)
    }
}

/// A settings row: icon, title over a detail line, something on the right, and a chevron when it opens something.
private struct SettingsRow<Trailing: View>: View {
    var icon: String
    var iconColor: Color = Palette.secondary
    var title: String
    var detail: String
    var detailColor: Color = Palette.secondary
    var action: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        let content = SettingsRowContent(icon: icon, iconColor: iconColor, title: title, detail: detail,
                                         detailColor: detailColor, chevron: action != nil, trailing: trailing)
        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, iconColor: Color = Palette.secondary, title: String, detail: String,
         detailColor: Color = Palette.secondary, action: (() -> Void)? = nil) {
        self.init(icon: icon, iconColor: iconColor, title: title, detail: detail, detailColor: detailColor,
                  action: action, trailing: { EmptyView() })
    }
}

private struct SettingsRowContent<Trailing: View>: View {
    var icon: String
    var iconColor: Color = Palette.secondary
    var title: String
    var detail: String
    var detailColor: Color = Palette.secondary
    var chevron = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(iconColor).frame(width: 24).padding(.trailing, 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17)).foregroundStyle(Palette.text)
                Text(detail).font(.system(size: 14)).foregroundStyle(detailColor).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.secondary).padding(.leading, 8)
            }
        }
        .padding(.horizontal, 4).padding(.vertical, 10)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
    }
}

extension SettingsRowContent where Trailing == EmptyView {
    init(icon: String, iconColor: Color = Palette.secondary, title: String, detail: String,
         detailColor: Color = Palette.secondary, chevron: Bool = false) {
        self.init(icon: icon, iconColor: iconColor, title: title, detail: detail, detailColor: detailColor,
                  chevron: chevron, trailing: { EmptyView() })
    }
}
