import SwiftUI

/// The app only holds the keyboard: it tells how to turn it on and gives a field to try it in.
@main
struct TatakikunApp: App {
    var body: some Scene {
        WindowGroup { SetupView() }
    }
}

struct SetupView: View {
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Turn on the keyboard") {
                    Text("Settings → General → Keyboard → Keyboards → Add New Keyboard… → Tatakikun")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Section("Try it") {
                    TextField("Type here: ai, woaini, arigatou, hello", text: $text)
                        .accessibilityIdentifier("tryField")
                    NavigationLink("Try it here, without turning it on") {
                        DemoView().navigationTitle("Try Tatakikun").navigationBarTitleDisplayMode(.inline)
                    }
                    .accessibilityIdentifier("demo")
                }
                Section("Keys") {
                    Text("Letters show English, Chinese and Japanese candidates in one bar. Space inserts the first candidate, return inserts the letters as typed, tap a candidate to insert it, ⌄ shows more.")
                }
            }
            .navigationTitle("Tatakikun")
        }
    }
}
