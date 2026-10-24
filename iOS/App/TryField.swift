import SwiftUI
import UIKit

extension UITextView: KeyboardTarget {
    var documentContextBeforeInput: String? {
        guard let cursor = selectedTextRange?.start, let range = textRange(from: beginningOfDocument, to: cursor) else { return nil }
        return text(in: range)
    }
    func mark(_ text: String, selectedRange: NSRange) { setMarkedText(text, selectedRange: selectedRange) }
    func endMarking() { unmarkText() }
}

/// The Try it field: it always types with Tatakikun, the keys built into the app (the same
/// KeyboardView as the keyboard extension), whatever keyboard is chosen in Settings and before
/// Tatakikun is turned on. The UI tests type here too (a simulator run by tests shows no
/// third-party keyboards).
struct TryField: UIViewRepresentable {
    var placeholder: String
    /// The field became active: the screen scrolls it above the keys.
    var onFocus: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFocus: onFocus) }

    func makeUIView(context: Context) -> UITextView {
        let field = UITextView()
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.backgroundColor = .clear
        field.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        field.accessibilityIdentifier = "tryField"
        field.delegate = context.coordinator

        let hint = UILabel()
        hint.text = placeholder
        hint.font = field.font
        hint.textColor = .placeholderText
        hint.translatesAutoresizingMaskIntoConstraints = false
        field.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: field.topAnchor, constant: 14),
            hint.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 17),
        ])
        context.coordinator.hint = hint

        // Tatakikun's keys in place of the system keyboard: the keyboard view (its candidate bar and
        // keys) with the home indicator's room below it, as a system keyboard leaves.
        let indicator = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
        let keys = UIInputView(frame: CGRect(x: 0, y: 0, width: 0, height: KeyboardView.height + indicator), inputViewStyle: .keyboard)
        let keyboard = context.coordinator.keyboard
        keyboard.showsNextKeyboard = false
        keyboard.target = field
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        keys.addSubview(keyboard)
        NSLayoutConstraint.activate([
            keyboard.topAnchor.constraint(equalTo: keys.topAnchor),
            keyboard.leadingAnchor.constraint(equalTo: keys.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: keys.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: keys.bottomAnchor, constant: -indicator),
        ])
        field.inputView = keys
        return field
    }

    func updateUIView(_ field: UITextView, context: Context) {}

    final class Coordinator: NSObject, UITextViewDelegate {
        let keyboard = KeyboardView()
        weak var hint: UILabel?
        let onFocus: () -> Void

        init(onFocus: @escaping () -> Void) { self.onFocus = onFocus }

        func textViewDidBeginEditing(_ field: UITextView) { onFocus() }
        func textViewDidEndEditing(_ field: UITextView) { keyboard.finish() }
        func textViewDidChange(_ field: UITextView) { hint?.isHidden = !field.text.isEmpty; keyboard.refreshMarks() }
        func textViewDidChangeSelection(_ field: UITextView) { keyboard.refreshMarks() }
    }
}
