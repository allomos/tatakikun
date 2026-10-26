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
        NSLayoutConstraint.activate([
            keyboard.topAnchor.constraint(equalTo: root.topAnchor),
            keyboard.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: root.trailingAnchor),
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
