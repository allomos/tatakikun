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

/// The keyboard inside the app, typing into a text view above it: for trying it without turning it
/// on in Settings, and for the UI tests (a simulator without a window shows no third-party keyboards).
final class DemoViewController: UIViewController {
    private let textView = UITextView()
    private let keyboard = KeyboardView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        textView.font = .systemFont(ofSize: 20)
        textView.layer.cornerRadius = 8
        textView.accessibilityIdentifier = "demoText"
        textView.inputView = UIView() // no system keyboard: the Tatakikun keys below type here
        keyboard.backgroundColor = .secondarySystemBackground
        keyboard.showsNextKeyboard = false
        keyboard.target = textView
        for v in [textView, keyboard] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: keyboard.topAnchor, constant: -12),
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }
}

struct DemoView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DemoViewController { DemoViewController() }
    func updateUIViewController(_ controller: DemoViewController, context: Context) {}
}
