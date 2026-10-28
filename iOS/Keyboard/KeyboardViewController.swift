import UIKit
import TatakikunCore

extension UIInputViewController: KeyboardTarget {
    var documentContextBeforeInput: String? { textDocumentProxy.documentContextBeforeInput }
    func insertText(_ text: String) { textDocumentProxy.insertText(text) }
    func deleteBackward() { textDocumentProxy.deleteBackward() }
    func mark(_ text: String, selectedRange: NSRange) { textDocumentProxy.setMarkedText(text, selectedRange: selectedRange) }
    func endMarking() { textDocumentProxy.unmarkText() }
    var selectedText: String? { textDocumentProxy.selectedText }
    var canUsePasteboard: Bool { hasFullAccess }
    var pasteboardAsks: Bool { false }

    /// A keyboard extension has no UIApplication.shared: the application is found up the responder
    /// chain, and opens Tatakikun's page in Settings through the Objective-C method.
    func openSettings() {
        guard let url = URL(string: "app-settings:") else { return }
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let r = responder {
            if r is UIApplication, r.responds(to: selector) {
                typealias Open = @convention(c) (NSObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
                unsafeBitCast(r.method(for: selector), to: Open.self)(r, selector, url as NSURL, NSDictionary(), nil)
                return
            }
            responder = r.next
        }
    }
}

/// The keyboard extension's entry point: shows the KeyboardView and types through the text proxy.
final class KeyboardViewController: UIInputViewController {
    private let keyboard = KeyboardView()

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let root = inputView else { return }
        root.allowsSelfSizing = true
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(keyboard)
        // On iPad the keyboard is 90% of the screen's width, centered, in either orientation;
        // phones use the full width.
        let share: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 0.9 : 1
        NSLayoutConstraint.activate([
            keyboard.topAnchor.constraint(equalTo: root.topAnchor),
            keyboard.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            keyboard.widthAnchor.constraint(equalTo: root.widthAnchor, multiplier: share),
            keyboard.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        keyboard.target = self
        keyboard.onNextKeyboard = { [weak self] view, event in self?.handleInputModeList(from: view, with: event) }
    }

    /// Each time the keyboard comes up it follows the language switches in the app, so a change
    /// there works at once.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Shared.engine.turnedOff = hasFullAccess ? Settings.turnedOff : Settings.firstOff
        keyboard.longPress = hasFullAccess ? Settings.longPress : Settings.defaultLongPress
        // What was copied since the keyboard was last up (the chip and the clipboard list).
        keyboard.noteClipboard()
    }

    override func viewWillLayoutSubviews() {
        keyboard.showsNextKeyboard = needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
    }

    /// The text or the cursor changed: the punctuation keys follow the text before the cursor.
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        keyboard.refreshMarks()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        keyboard.refreshMarks()
    }

    override func viewWillDisappear(_ animated: Bool) {
        keyboard.finish()
        super.viewWillDisappear(animated)
    }
}
