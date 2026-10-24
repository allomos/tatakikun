import UIKit
import TatakikunCore

/// The engine is shared by every keyboard this process shows. It loads the packs bundled with the
/// keyboard extension (the app finds them inside its copy of the extension).
enum Shared {
    static let engine: Engine = {
        let bundle = Bundle.main.bundleURL.pathExtension == "appex" ? Bundle.main.bundleURL
            : Bundle.main.builtInPlugInsURL!.appendingPathComponent("TatakikunKeyboard.appex")
        let engine = (try? Engine(packFolders: [bundle.appendingPathComponent("packs")], rowSize: 9))
            ?? Engine(chinese: nil, japanese: nil, english: nil)
        engine.history = UserHistory(url: UserHistory.defaultURL)
        engine.customWords = CustomWords(url: CustomWords.defaultURL)
        return engine
    }()
}

/// Where the keyboard types: the text field through the extension's proxy, or the app's demo field.
protocol KeyboardTarget: AnyObject {
    var documentContextBeforeInput: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
    /// Shows `text` as typed but not yet inserted (underlined), or replaces what was shown.
    func mark(_ text: String, selectedRange: NSRange)
    /// Keeps what is shown as inserted text.
    func endMarking()
}

/// The Tatakikun keyboard: a candidate bar over a QWERTY layout, driven by the same Composer as
/// the macOS input method. The letters being typed show underlined in the text field.
final class KeyboardView: UIView {
    weak var target: KeyboardTarget?
    var onNextKeyboard: ((UIView, UIEvent) -> Void)? { didSet { keys.onNextKeyboard = onNextKeyboard } }
    var showsNextKeyboard: Bool {
        get { keys.showsNextKeyboard }
        set { keys.showsNextKeyboard = newValue }
    }
    private lazy var composer: Composer = {
        let composer = Composer(engine: Shared.engine)
        composer.columns = 5
        composer.textBeforeCursor = { [weak self] in
            self?.target?.documentContextBeforeInput.map { String($0.suffix(4)) }
        }
        return composer
    }()
    private let bar = CandidateBar()
    private let more = CandidateGrid()
    private let keys = KeyboardKeys()
    private var hasMarkedText = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        for v in [bar, keys, more] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        more.isHidden = true
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 46),
            keys.topAnchor.constraint(equalTo: bar.bottomAnchor),
            keys.leadingAnchor.constraint(equalTo: leadingAnchor),
            keys.trailingAnchor.constraint(equalTo: trailingAnchor),
            keys.bottomAnchor.constraint(equalTo: bottomAnchor),
            keys.heightAnchor.constraint(equalToConstant: 216),
            more.topAnchor.constraint(equalTo: keys.topAnchor),
            more.leadingAnchor.constraint(equalTo: keys.leadingAnchor),
            more.trailingAnchor.constraint(equalTo: keys.trailingAnchor),
            more.bottomAnchor.constraint(equalTo: keys.bottomAnchor),
        ])
        bar.onChoose = { [weak self] column in self?.choose(row: 0, column: column) }
        bar.onToggle = { [weak self] in self?.send(self?.composer.isExpanded == true ? .escape : .down) }
        more.onChoose = { [weak self] row, column in self?.choose(row: row, column: column) }
        keys.onKey = { [weak self] key in self?.send(key) }
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Switching away: insert what is typed, like the macOS input method does.
    func finish() {
        if let text = composer.finish() { insert(text) }
        Shared.engine.forgetRecent()
        refresh()
    }

    private func send(_ key: Key) {
        guard let target else { return }
        let update = composer.handle(key)
        (0..<update.deleteBefore).forEach { _ in target.deleteBackward() }
        if let text = update.commit { insert(text) }
        if !update.handled {
            // Keys the composer leaves to the application.
            switch key {
            case .backspace: target.deleteBackward()
            case .space: target.insertText(" ")
            case .enter: target.insertText("\n")
            case .digit(let n): target.insertText(String(n))
            case .other(let c): target.insertText(String(c))
            default: break
            }
        }
        refresh()
    }

    private func choose(row: Int, column: Int) {
        let update = composer.choose(row: row, column: column)
        if let text = update.commit { insert(text) }
        refresh()
    }

    /// Inserts text in place of the letters shown as typed.
    private func insert(_ text: String) {
        guard let target else { return }
        if hasMarkedText {
            target.mark(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
            target.endMarking()
            hasMarkedText = false
        } else {
            target.insertText(text)
        }
    }

    private func refresh() {
        if composer.isComposing {
            target?.mark(composer.input, selectedRange: NSRange(location: (composer.input as NSString).length, length: 0))
            hasMarkedText = true
        } else if hasMarkedText {
            target?.mark("", selectedRange: NSRange(location: 0, length: 0))
            target?.endMarking()
            hasMarkedText = false
        }
        let selected = composer.selectedRow == 0 ? composer.selectedColumn : nil
        bar.show(composer.rows.first ?? [], input: composer.input, selected: selected,
                 canExpand: composer.canExpand, expanded: composer.isExpanded)
        more.isHidden = !composer.isExpanded
        keys.isHidden = composer.isExpanded
        if composer.isExpanded { more.show(composer.rows) }
    }
}

// MARK: - Candidates

/// Gray for candidates that match only part of the letters (completions, corrections, prefixes).
private func color(for candidate: Candidate) -> UIColor { candidate.isExact ? .label : .secondaryLabel }

private func candidateButton(_ candidate: Candidate, selected: Bool) -> UIButton {
    var config = UIButton.Configuration.plain()
    config.attributedTitle = AttributedString(candidate.text, attributes: AttributeContainer([
        .font: UIFont.systemFont(ofSize: 20), .foregroundColor: color(for: candidate),
    ]))
    config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
    config.background.cornerRadius = 6
    config.background.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.18) : .clear
    let button = UIButton(configuration: config)
    button.accessibilityLabel = candidate.text
    return button
}

/// The bar: the letters as typed, the first row of candidates in a strip that scrolls sideways,
/// and ⌄ / ⌃ to show or hide more.
final class CandidateBar: UIView {
    var onChoose: ((Int) -> Void)?
    var onToggle: (() -> Void)?
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let toggle = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        scroll.showsHorizontalScrollIndicator = false
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .center
        toggle.titleLabel?.font = .systemFont(ofSize: 20)
        toggle.accessibilityIdentifier = "expand"
        toggle.addAction(UIAction { [weak self] _ in self?.onToggle?() }, for: .touchUpInside)
        for v in [scroll, stack, toggle] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(scroll)
        addSubview(toggle)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: toggle.leadingAnchor),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor),
            toggle.topAnchor.constraint(equalTo: topAnchor),
            toggle.bottomAnchor.constraint(equalTo: bottomAnchor),
            toggle.widthAnchor.constraint(equalToConstant: 44),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ row: [Candidate], input: String, selected: Int?, canExpand: Bool, expanded: Bool) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, candidate) in row.enumerated() {
            let button = candidateButton(candidate, selected: i == selected)
            button.addAction(UIAction { [weak self] _ in self?.onChoose?(i) }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        scroll.contentOffset = .zero
        toggle.setTitle(expanded ? "⌃" : "⌄", for: .normal)
        toggle.isHidden = !canExpand && !expanded
    }
}

/// More candidates, shown in place of the keys: rows that wrap and scroll up and down.
final class CandidateGrid: UIView {
    var onChoose: ((Int, Int) -> Void)?
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        for v in [scroll, stack] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Every row but the bar; a row too wide for the screen scrolls sideways.
    func show(_ rows: [[Candidate]]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (r, row) in rows.enumerated().dropFirst() {
            let line = UIStackView()
            line.axis = .horizontal
            line.spacing = 2
            for (c, candidate) in row.enumerated() {
                let button = candidateButton(candidate, selected: false)
                button.addAction(UIAction { [weak self] _ in self?.onChoose?(r, c) }, for: .touchUpInside)
                line.addArrangedSubview(button)
            }
            let strip = UIScrollView()
            strip.showsHorizontalScrollIndicator = false
            strip.translatesAutoresizingMaskIntoConstraints = false
            line.translatesAutoresizingMaskIntoConstraints = false
            strip.addSubview(line)
            NSLayoutConstraint.activate([
                line.leadingAnchor.constraint(equalTo: strip.contentLayoutGuide.leadingAnchor),
                line.trailingAnchor.constraint(equalTo: strip.contentLayoutGuide.trailingAnchor),
                line.topAnchor.constraint(equalTo: strip.contentLayoutGuide.topAnchor),
                line.bottomAnchor.constraint(equalTo: strip.contentLayoutGuide.bottomAnchor),
                line.heightAnchor.constraint(equalTo: strip.frameLayoutGuide.heightAnchor),
                strip.heightAnchor.constraint(equalToConstant: 42),
            ])
            stack.addArrangedSubview(strip)
            strip.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        scroll.contentOffset = .zero
    }
}

// MARK: - Keys

/// QWERTY letters, a layer of digits and punctuation, and space, return, backspace, shift and 🌐.
final class KeyboardKeys: UIView {
    var onKey: ((Key) -> Void)?
    var onNextKeyboard: ((UIView, UIEvent) -> Void)?
    var showsNextKeyboard = true { didSet { if oldValue != showsNextKeyboard { build() } } }
    private var symbols = false { didSet { build() } }
    /// Shift: off, on for the next letter only, or caps lock (two quick taps) until tapped again.
    private enum Shift { case off, once, locked }
    private var shift = Shift.off { didSet { if oldValue != shift { showShift() } } }
    /// The letter keys and the shift key, updated in place when shift changes: rebuilding the keys
    /// under the finger would lose the second tap of a double tap.
    private var letterKeys: [(button: UIButton, letter: Character)] = []
    private var shiftButton: UIButton?
    private var lastShiftTap = Date.distantPast
    /// Two taps on shift closer than this turn on caps lock.
    private static let doubleTap: TimeInterval = 0.4
    private let rows = UIStackView()

    private static let letters = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    private static let symbolRows = ["1234567890", "-/:;()&@\"", ".,?!'"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        rows.axis = .vertical
        rows.distribution = .fillEqually
        rows.spacing = 8
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            rows.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            rows.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func shiftKey() -> UIView {
        let k = key("⇧", id: "shift", dark: true) { [weak self] in self?.tapShift() }
        shiftButton = k
        return k
    }

    private func letter(_ c: Character) -> String { shift != .off ? String(c).uppercased() : String(c) }

    private func showShift() {
        for (button, c) in letterKeys {
            button.setTitle(letter(c), for: .normal)
            button.accessibilityIdentifier = letter(c)
        }
        guard let k = shiftButton else { return }
        k.setTitle(shift == .locked ? "⇪" : "⇧", for: .normal)
        k.backgroundColor = shift == .off ? UIColor.systemGray3 : UIColor.systemBackground
        k.accessibilityValue = switch shift { case .off: "off"; case .once: "on"; case .locked: "caps lock" }
    }

    private func tapShift() {
        let now = Date()
        shift = switch shift {
        case .once where now.timeIntervalSince(lastShiftTap) < Self.doubleTap: .locked
        case .off: .once
        default: .off
        }
        lastShiftTap = now
    }

    private func build() {
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        letterKeys = []
        shiftButton = nil
        let top = symbols ? Self.symbolRows : Self.letters
        for (i, chars) in top.enumerated() {
            var keys = chars.map { c -> UIView in
                let shown = symbols ? String(c) : letter(c)
                let button = key(shown, id: shown) { [weak self] in
                    guard let self else { return }
                    let ch = self.symbols ? c : Character(self.letter(c))
                    if ch.isLetter { self.onKey?(.letter(ch)); if self.shift == .once { self.shift = .off } }
                    else if let n = ch.wholeNumberValue { self.onKey?(.digit(n)) }
                    else { self.onKey?(.other(ch)) }
                }
                if !symbols { letterKeys.append((button, c)) }
                return button
            }
            if i == 2 {
                let left = symbols ? key("#+=", id: "spacer", dark: true) {} : shiftKey()
                if symbols { left.alpha = 0 }
                keys.insert(left, at: 0)
                keys.append(key("⌫", id: "delete", dark: true) { [weak self] in self?.onKey?(.backspace) })
            }
            rows.addArrangedSubview(row(keys, weights: i == 2 ? [1.4] + Array(repeating: 1, count: chars.count) + [1.4] : nil))
        }
        var bottom: [UIView] = [key(symbols ? "ABC" : "123", id: "layer", dark: true) { [weak self] in self?.symbols.toggle() }]
        if showsNextKeyboard {
            let globe = UIButton(type: .system)
            style(globe, title: "🌐", dark: true)
            globe.accessibilityIdentifier = "nextKeyboard"
            globe.addTarget(self, action: #selector(nextKeyboard(_:event:)), for: .allTouchEvents)
            bottom.append(globe)
        }
        bottom += [
            key("，", id: "comma", dark: true) { [weak self] in self?.onKey?(.other(",")) },
            key("space", id: "space") { [weak self] in self?.onKey?(.space) },
            key("。", id: "period", dark: true) { [weak self] in self?.onKey?(.other(".")) },
            key("return", id: "return", dark: true) { [weak self] in self?.onKey?(.enter) },
        ]
        let weights: [CGFloat] = (showsNextKeyboard ? [1.2, 1.2] : [1.2]) + [1, 4, 1, 2]
        rows.addArrangedSubview(row(bottom, weights: weights))
        showShift()
    }

    @objc private func nextKeyboard(_ sender: UIView, event: UIEvent) { onNextKeyboard?(sender, event) }

    private func row(_ keys: [UIView], weights: [CGFloat]?) -> UIView {
        let line = UIView()
        var previous: UIView?
        let first = keys.first
        for (i, k) in keys.enumerated() {
            k.translatesAutoresizingMaskIntoConstraints = false
            line.addSubview(k)
            k.topAnchor.constraint(equalTo: line.topAnchor).isActive = true
            k.bottomAnchor.constraint(equalTo: line.bottomAnchor).isActive = true
            if let previous { k.leadingAnchor.constraint(equalTo: previous.trailingAnchor, constant: 6).isActive = true }
            if let first, k !== first {
                let w = weights.map { $0[i] / $0[0] } ?? 1
                k.widthAnchor.constraint(equalTo: first.widthAnchor, multiplier: w).isActive = true
            }
            previous = k
        }
        // A short row (asdf…) is centered with keys as wide as a full row's.
        if weights == nil, keys.count < 10, let first, let last = keys.last {
            first.widthAnchor.constraint(equalTo: line.widthAnchor, multiplier: 1 / 10, constant: -6 * 9 / 10).isActive = true
            first.leadingAnchor.constraint(greaterThanOrEqualTo: line.leadingAnchor).isActive = true
            let center = UILayoutGuide()
            line.addLayoutGuide(center)
            NSLayoutConstraint.activate([
                center.leadingAnchor.constraint(equalTo: first.leadingAnchor),
                center.trailingAnchor.constraint(equalTo: last.trailingAnchor),
                center.centerXAnchor.constraint(equalTo: line.centerXAnchor),
            ])
        } else {
            first?.leadingAnchor.constraint(equalTo: line.leadingAnchor).isActive = true
            previous?.trailingAnchor.constraint(equalTo: line.trailingAnchor).isActive = true
        }
        return line
    }

    private func key(_ title: String, id: String, dark: Bool = false, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        style(button, title: title, dark: dark)
        button.accessibilityIdentifier = id
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func style(_ button: UIButton, title: String, dark: Bool) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: title.count == 1 ? 22 : 16)
        button.backgroundColor = dark ? UIColor.systemGray3 : UIColor.systemBackground
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
    }
}
