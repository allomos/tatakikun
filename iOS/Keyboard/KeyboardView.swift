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
    /// The text copied lately (A01-eclair008), kept on this device only.
    static let clips = ClipboardHistory(url: ClipboardHistory.defaultURL)
}

/// Settings made in the app, which the keyboard reads through their shared app group. The
/// keyboard can open the group only with Full Access; without it, the languages on at first are on.
enum Settings {
    static let group = "group.com.tatakikun.ios"
    private static let defaults = UserDefaults(suiteName: group)

    /// The installed languages turned off in the app (A04-tuna688); before the user has chosen, all
    /// but Chinese, Japanese and English (A04-aster924).
    static var turnedOff: Set<LanguagePacks.Language> {
        get {
            guard let saved = defaults?.stringArray(forKey: "languagesOff") else { return firstOff }
            return Set(saved.compactMap(LanguagePacks.Language.init))
        }
        set {
            defaults?.set(newValue.map(\.rawValue).sorted(), forKey: "languagesOff")
            Shared.engine.turnedOff = newValue
        }
    }

    /// How long a key is held for its long press, in seconds: set in the app from 0.2 to 0.6
    /// (A01-sloth938); the keyboard reads it with Full Access, else uses the default.
    static let defaultLongPress: TimeInterval = 0.3
    static let longPressRange: ClosedRange<TimeInterval> = 0.2...0.6
    static var longPress: TimeInterval {
        get {
            let ms = defaults?.integer(forKey: "longPressMs") ?? 0
            return ms == 0 ? defaultLongPress : min(max(Double(ms) / 1000, longPressRange.lowerBound), longPressRange.upperBound)
        }
        set { defaults?.set(Int((newValue * 1000).rounded()), forKey: "longPressMs") }
    }

    /// The languages off before the user has chosen any (or when the keyboard cannot read the choice).
    static var firstOff: Set<LanguagePacks.Language> { LanguagePacks.offAtFirst(installed: Shared.engine.languages) }
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
    /// The text selected in the field, if any (what Ctrl+C copies).
    var selectedText: String? { get }
    /// Whether the keyboard may use the pasteboard: an extension needs Full Access for it.
    var canUsePasteboard: Bool { get }
    /// Whether reading the pasteboard asks the person first (an app does; a keyboard with Full Access does not).
    var pasteboardAsks: Bool { get }
    /// Opens Tatakikun's page in Settings (where Full Access is turned on).
    func openSettings()
}

/// The Tatakikun keyboard: a candidate bar over a QWERTY layout, driven by the same Composer as
/// the macOS input method. The letters being typed show underlined in the text field. While nothing
/// is typed, the bar has a clipboard button, which shows the text copied lately in place of the keys,
/// and a chip with the latest copy, pasted with one tap.
final class KeyboardView: UIView {
    weak var target: KeyboardTarget?
    var onNextKeyboard: ((UIView, UIEvent) -> Void)? { didSet { keys.onNextKeyboard = onNextKeyboard } }
    var showsNextKeyboard: Bool {
        get { keys.showsNextKeyboard }
        set { keys.showsNextKeyboard = newValue }
    }
    /// How long a key is held for its symbol (Settings.longPress).
    var longPress: TimeInterval {
        get { keys.longPress }
        set { keys.longPress = newValue }
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
    private let clipList = ClipboardList()
    private var clipOpen = false
    private var hasMarkedText = false
    private static let barHeight: CGFloat = 46
    private static let keysHeight: CGFloat = 216
    /// The whole keyboard's height: the candidate bar over the keys.
    static let height = barHeight + keysHeight

    override init(frame: CGRect) {
        super.init(frame: frame)
        for v in [bar, keys, more, clipList] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        more.isHidden = true
        clipList.isHidden = true
        NSLayoutConstraint.activate([
            clipList.topAnchor.constraint(equalTo: keys.topAnchor),
            clipList.leadingAnchor.constraint(equalTo: keys.leadingAnchor),
            clipList.trailingAnchor.constraint(equalTo: keys.trailingAnchor),
            clipList.bottomAnchor.constraint(equalTo: keys.bottomAnchor),
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: Self.barHeight),
            keys.topAnchor.constraint(equalTo: bar.bottomAnchor),
            keys.leadingAnchor.constraint(equalTo: leadingAnchor),
            keys.trailingAnchor.constraint(equalTo: trailingAnchor),
            keys.bottomAnchor.constraint(equalTo: bottomAnchor),
            keys.heightAnchor.constraint(equalToConstant: Self.keysHeight),
            more.topAnchor.constraint(equalTo: keys.topAnchor),
            more.leadingAnchor.constraint(equalTo: keys.leadingAnchor),
            more.trailingAnchor.constraint(equalTo: keys.trailingAnchor),
            more.bottomAnchor.constraint(equalTo: keys.bottomAnchor),
        ])
        bar.onChoose = { [weak self] column in self?.choose(row: 0, column: column) }
        bar.onToggle = { [weak self] in self?.send(self?.composer.isExpanded == true ? .escape : .down) }
        more.onChoose = { [weak self] row, column in self?.choose(row: row, column: column) }
        keys.onKey = { [weak self] key in self?.send(key) }
        keys.onSymbol = { [weak self] text in self?.typeSymbol(text) }
        keys.onCtrl = { [weak self] letter in self?.ctrl(letter) }
        bar.onClipboard = { [weak self] in self?.toggleClipboard() }
        bar.onChip = { [weak self] in
            guard let text = Shared.clips.chip() else { return }
            Shared.clips.dismissChip()
            self?.paste(text)
        }
        clipList.onPaste = { [weak self] i in
            guard let self, Shared.clips.items.indices.contains(i) else { return }
            let text = Shared.clips.items[i]
            if Shared.clips.chip() == text { Shared.clips.dismissChip() }
            self.clipOpen = false
            self.paste(text)
        }
        clipList.onDelete = { [weak self] i in Shared.clips.remove(at: i); self?.refresh() }
        clipList.onClear = { [weak self] in Shared.clips.clear(); self?.refresh() }
        clipList.onBack = { [weak self] in self?.clipOpen = false; self?.refresh() }
        clipList.onOpenSettings = { [weak self] in self?.target?.openSettings() }
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Switching away: insert what is typed, like the macOS input method does.
    func finish() {
        if let text = composer.finish() { insert(text) }
        Shared.engine.forgetRecent()
        clipOpen = false
        refresh()
    }

    /// Records what is on the pasteboard when it changed since last time: iOS lets a keyboard look
    /// at it only while it is up, with Full Access. Text a password manager marks as concealed is
    /// left out. Where reading asks the person first (the app's Try it field), only when `asked`.
    func noteClipboard(asked: Bool = false) {
        guard let target, target.canUsePasteboard, asked || !target.pasteboardAsks else { return }
        let pasteboard = UIPasteboard.general
        let defaults = UserDefaults.standard
        guard pasteboard.changeCount != defaults.integer(forKey: "clipboardChange") else { return }
        defaults.set(pasteboard.changeCount, forKey: "clipboardChange")
        guard pasteboard.hasStrings, !pasteboard.types.contains("org.nspasteboard.ConcealedType"),
              let text = pasteboard.string else { return }
        Shared.clips.add(text)
        refresh()
    }

    /// The clipboard button: the list of copies in place of the keys, or what Full Access is for.
    private func toggleClipboard() {
        clipOpen.toggle()
        if clipOpen { noteClipboard(asked: true) }
        refresh()
    }

    /// Text from the clipboard list or chip, inserted at the cursor; the keys come back.
    private func paste(_ text: String) {
        insert((composer.finish() ?? "") + text)
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

    /// A symbol chosen in a key's long-press popup: typed exactly as shown, after what is being typed.
    /// Both go in as one edit: the text field gets a keyboard's edits later, and two of them could
    /// arrive the other way round (good + ? came out as ?good).
    private func typeSymbol(_ text: String) {
        insert((composer.finish() ?? "") + text)
        refresh()
    }

    /// Ctrl+C copies the selected text, Ctrl+V cuts it (iPad; Apple's keyboard API has no select
    /// all, undo or redo). What is being typed is inserted first. Without Full Access the
    /// pasteboard is closed to the keyboard: the bar says so instead.
    private func ctrl(_ letter: Character) {
        guard let target else { return }
        if let text = composer.finish() { insert(text) }
        refresh()
        guard target.canUsePasteboard else {
            bar.showNotice("Copy and cut need Full Access: see the Tatakikun app")
            return
        }
        guard let text = target.selectedText, !text.isEmpty else { return }
        UIPasteboard.general.string = text
        if letter == "v" { target.deleteBackward() }   // deletes the selection
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
        if composer.isComposing { clipOpen = false }
        bar.showTools(!composer.isComposing, chip: clipOpen ? nil : Shared.clips.chip())
        more.isHidden = !composer.isExpanded
        keys.isHidden = composer.isExpanded || clipOpen
        clipList.isHidden = !clipOpen
        if clipOpen { clipList.show(Shared.clips.items, hasAccess: target?.canUsePasteboard ?? false) }
        if composer.isExpanded { more.show(composer.rows) }
        refreshMarks()
    }

    /// Shows on the punctuation keys what they type now: it follows the text before the cursor
    /// (called again when that changes) and the word being composed.
    func refreshMarks() {
        keys.showMarks { [composer] in composer.mark(for: $0) }
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
    var onClipboard: (() -> Void)?
    var onChip: (() -> Void)?
    /// While nothing is typed: the clipboard button and the chip with the latest copy.
    private let tools = UIStackView()
    private let chip = UIButton(configuration: .tinted())
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let toggle = UIButton(type: .system)
    /// A short line in place of the candidates (Ctrl+C without Full Access), until the next key.
    private let notice = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        notice.font = .systemFont(ofSize: 15)
        notice.textColor = .secondaryLabel
        notice.isHidden = true
        notice.accessibilityIdentifier = "notice"
        notice.translatesAutoresizingMaskIntoConstraints = false
        addSubview(notice)
        NSLayoutConstraint.activate([
            notice.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            notice.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            notice.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        let clipboard = UIButton(type: .system)
        clipboard.setImage(UIImage(systemName: "doc.on.clipboard", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18)), for: .normal)
        clipboard.tintColor = .label
        clipboard.accessibilityIdentifier = "clipboard"
        clipboard.accessibilityLabel = "Clipboard"
        clipboard.addAction(UIAction { [weak self] _ in self?.onClipboard?() }, for: .touchUpInside)
        clipboard.widthAnchor.constraint(equalToConstant: 44).isActive = true
        chip.configuration?.cornerStyle = .capsule
        chip.configuration?.titleLineBreakMode = .byTruncatingTail
        chip.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        chip.accessibilityIdentifier = "clipChip"
        chip.addAction(UIAction { [weak self] _ in self?.onChip?() }, for: .touchUpInside)
        chip.widthAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true
        tools.axis = .horizontal
        tools.alignment = .center
        tools.spacing = 4
        tools.addArrangedSubview(clipboard)
        tools.addArrangedSubview(chip)
        tools.isHidden = true
        tools.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tools)
        NSLayoutConstraint.activate([
            tools.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            tools.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            tools.topAnchor.constraint(equalTo: topAnchor),
            tools.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
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
        bringSubviewToFront(tools)   // over the (empty) candidate strip, which would take its taps
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
        notice.isHidden = true
    }

    func showNotice(_ text: String) {
        notice.text = text
        notice.isHidden = false
        tools.isHidden = true
    }

    /// Shows the clipboard button (when `visible`) with the chip for `chip` beside it.
    func showTools(_ visible: Bool, chip text: String?) {
        tools.isHidden = !visible || !notice.isHidden
        chip.isHidden = text == nil
        chip.configuration?.attributedTitle = text.map {
            AttributedString(ClipboardList.preview($0), attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 15)]))
        }
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

// MARK: - Clipboard

/// The text copied lately, shown in place of the keys: a header (back, title, clear all) over the
/// copies, newest first, each with × to delete it. Without Full Access, what it needs instead.
final class ClipboardList: UIView {
    var onPaste: ((Int) -> Void)?
    var onDelete: ((Int) -> Void)?
    var onClear: (() -> Void)?
    var onBack: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    private let clear = UIButton(type: .system)
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // As on the keys: a keyboard extension gets no touches on fully transparent parts.
        backgroundColor = UIColor(white: 0.5, alpha: 0.01)
        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.tintColor = .label
        back.accessibilityIdentifier = "clipBack"
        back.addAction(UIAction { [weak self] _ in self?.onBack?() }, for: .touchUpInside)
        let title = UILabel()
        title.text = "Clipboard"
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        clear.setImage(UIImage(systemName: "trash"), for: .normal)
        clear.tintColor = .label
        clear.accessibilityIdentifier = "clipClear"
        clear.accessibilityLabel = "Clear all"
        clear.addAction(UIAction { [weak self] _ in self?.onClear?() }, for: .touchUpInside)
        stack.axis = .vertical
        stack.spacing = 6
        for v in [back, title, clear, scroll, stack] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false }
        [back, title, clear, scroll].forEach(addSubview)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            back.topAnchor.constraint(equalTo: topAnchor),
            back.widthAnchor.constraint(equalToConstant: 44),
            back.heightAnchor.constraint(equalToConstant: 36),
            title.leadingAnchor.constraint(equalTo: back.trailingAnchor),
            title.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            clear.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            clear.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            clear.widthAnchor.constraint(equalToConstant: 44),
            clear.heightAnchor.constraint(equalToConstant: 36),
            scroll.topAnchor.constraint(equalTo: back.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -6),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    /// A copy as the list and the chip show it: on as few lines as it can.
    static func preview(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ⏎ ").prefix(300))
    }

    func show(_ items: [String], hasAccess: Bool) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        clear.isHidden = !hasAccess || items.isEmpty
        guard hasAccess else { return showNeedsAccess() }
        if items.isEmpty {
            let empty = UILabel()
            empty.text = "Text you copy shows up here"
            empty.textColor = .secondaryLabel
            empty.font = .systemFont(ofSize: 15)
            empty.textAlignment = .center
            empty.heightAnchor.constraint(equalToConstant: 120).isActive = true
            stack.addArrangedSubview(empty)
        }
        for (i, text) in items.enumerated() {
            // The copy and its × side by side, so each is a button of its own (also for VoiceOver).
            let row = UIView()
            row.backgroundColor = .systemBackground
            row.layer.cornerRadius = 8
            let body = UIButton(type: .system)
            body.accessibilityIdentifier = "clip\(i)"
            body.accessibilityLabel = Self.preview(text)
            body.addAction(UIAction { [weak self] _ in self?.onPaste?(i) }, for: .touchUpInside)
            let label = UILabel()
            label.text = Self.preview(text)
            label.numberOfLines = 2
            label.font = .systemFont(ofSize: 15)
            label.textColor = .label
            label.isUserInteractionEnabled = false
            label.isAccessibilityElement = false
            let delete = UIButton(type: .system)
            delete.setImage(UIImage(systemName: "xmark"), for: .normal)
            delete.tintColor = .secondaryLabel
            delete.accessibilityIdentifier = "clipDelete\(i)"
            delete.accessibilityLabel = "Delete"
            delete.addAction(UIAction { [weak self] _ in self?.onDelete?(i) }, for: .touchUpInside)
            for v in [body, label, delete] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(v) }
            NSLayoutConstraint.activate([
                body.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                body.topAnchor.constraint(equalTo: row.topAnchor),
                body.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                body.trailingAnchor.constraint(equalTo: delete.leadingAnchor),
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
                label.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
                label.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10),
                label.trailingAnchor.constraint(equalTo: delete.leadingAnchor),
                delete.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                delete.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                delete.widthAnchor.constraint(equalToConstant: 44),
                delete.heightAnchor.constraint(equalToConstant: 40),
            ])
            stack.addArrangedSubview(row)
        }
        scroll.contentOffset = .zero
    }

    /// Without Full Access the keyboard cannot see the pasteboard: say so, with a way to turn it on.
    private func showNeedsAccess() {
        let text = UILabel()
        text.text = "The clipboard history needs Full Access. It stays on this \(UIDevice.current.model) and is never sent anywhere.\nIn Settings, turn on Keyboards › Allow Full Access."
        text.numberOfLines = 0
        text.font = .systemFont(ofSize: 15)
        text.textColor = .label
        text.textAlignment = .center
        text.accessibilityIdentifier = "clipNeedsAccess"
        var config = UIButton.Configuration.filled()
        config.title = "Open Settings"
        config.cornerStyle = .capsule
        let open = UIButton(configuration: config)
        open.accessibilityIdentifier = "clipOpenSettings"
        open.addAction(UIAction { [weak self] _ in self?.onOpenSettings?() }, for: .touchUpInside)
        let box = UIStackView(arrangedSubviews: [text, open])
        box.axis = .vertical
        box.alignment = .center
        box.spacing = 14
        box.isLayoutMarginsRelativeArrangement = true
        box.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.addArrangedSubview(box)
    }
}

// MARK: - Keys

/// QWERTY letters, a layer of digits and punctuation, and space, return, backspace, shift and 🌐.
final class KeyboardKeys: UIView {
    var onKey: ((Key) -> Void)?
    /// A symbol chosen in a key's long-press popup, typed exactly as shown.
    var onSymbol: ((String) -> Void)?
    var onNextKeyboard: ((UIView, UIEvent) -> Void)?
    var showsNextKeyboard = true { didSet { if oldValue != showsNextKeyboard { build() } } }
    /// A letter tapped while Ctrl is held (c or v), in place of typing it.
    var onCtrl: ((Character) -> Void)?
    /// iPad has a Ctrl key at the start of the bottom row (letters only); phones do not.
    private let showsCtrl = UIDevice.current.userInterfaceIdiom == .pad
    private static let ctrlLetters: Set<Character> = ["c", "v"]
    private var ctrlHeld = false { didSet { if oldValue != ctrlHeld { showCtrl() } } }
    private var ctrlButton: UIButton?
    /// Letters that went down while Ctrl was held: they run their shortcut when lifted, even if
    /// Ctrl was let go first (both fingers lifting together).
    private var ctrlTaps: Set<Character> = []
    private var symbols = false { didSet { build() } }
    /// Shift: off, on for the next letter only, or caps lock (two quick taps) until tapped again.
    private enum Shift { case off, once, locked }
    private var shift = Shift.off { didSet { if oldValue != shift { showShift() } } }
    /// The letter keys and the shift key, updated in place when shift changes: rebuilding the keys
    /// under the finger would lose the second tap of a double tap.
    private var letterKeys: [(button: UIButton, letter: Character)] = []
    private var shiftButton: UIButton?
    /// The punctuation keys, with the character each one types (`showMarks`).
    private var markKeys: [(button: UIButton, mark: Character)] = []
    private var mark: (Character) -> String = { String($0) }
    /// The corner symbols that follow `mark` too (the period key's ?).
    private var markHints: [(label: UILabel, mark: Character)] = []
    private let popup = SymbolPopup()
    /// The character of the pressed key, large above the finger, as on Android.
    private let preview = KeyPreview()
    /// The keys that show `preview` when pressed (letters, symbols, punctuation), with their corner symbol.
    private var previewKeys: [ObjectIdentifier: UILabel?] = [:]
    /// The press each key's `preview` belongs to, while it is down.
    private var previewPresses: [ObjectIdentifier: Int] = [:]
    /// How long a key is held for its symbol, as on Android; applied to the keys at once.
    var longPress = Settings.defaultLongPress {
        didSet { for case let press as SymbolPress in allPresses { press.minimumPressDuration = longPress } }
    }
    /// Every key's long press, so a new delay reaches them all.
    private var allPresses: [UIGestureRecognizer] {
        rows.arrangedSubviews.flatMap(\.subviews).flatMap { $0.gestureRecognizers ?? [] }
    }
    /// The symbol in each letter's corner, which a long press types, as on Android (and Gboard).
    private static let hints: [Character: Character] = [
        "q": "%", "w": "\\", "e": "|", "r": "=", "t": "[", "y": "]", "u": "<", "i": ">", "o": "{", "p": "}",
        "a": "@", "s": "#", "d": "$", "f": "-", "g": "&", "h": "_", "j": "+", "k": "(", "l": ")",
        "z": "*", "x": "\"", "c": "'", "v": ":", "b": ";", "n": "!", "m": "?",
    ]
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
        isMultipleTouchEnabled = true   // two thumbs landing between keys at once
        // iOS gives a keyboard extension no touches on fully transparent parts of it: without a
        // background, a tap in the gap between keys never arrives. Almost clear is enough.
        backgroundColor = UIColor(white: 0.5, alpha: 0.01)
        addSubview(rows)
        addSubview(preview)
        addSubview(popup)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            rows.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            rows.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// How far outside itself a key around the edge of the block still takes a tap, in points.
    private static let reach: CGFloat = 32

    /// A touch inside the block that misses every key goes to the nearest one: a tap in the gap
    /// between keys (or on the blank ends of the asdf row) types that key, and the keys around the
    /// edge also take taps up to `reach` outside them, since a finger is not that precise. The block
    /// takes such a touch itself and fires the key when the finger lifts: a button handed a touch
    /// that starts outside it does not reliably count it as a tap. Each finger is followed on its
    /// own, so fast typing with two thumbs works as before.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit == nil || hit is UIButton { return hit }   // outside the block (the candidate bar), or on a key
        return nearestKey(to: point) != nil ? self : hit
    }

    /// The key nearest to `point`, within `reach` of it (not 🌐, which only works under the finger).
    private func nearestKey(to point: CGPoint) -> UIButton? {
        var best: UIButton?
        var bestDistance = Self.reach * Self.reach
        for line in rows.arrangedSubviews {
            for case let button as UIButton in line.subviews
            where !button.isHidden && button.alpha >= 0.01 && button.accessibilityIdentifier != "nextKeyboard" {
                let frame = button.convert(button.bounds, to: self)
                let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
                let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
                if dx * dx + dy * dy <= bestDistance { bestDistance = dx * dx + dy * dy; best = button }
            }
        }
        return best
    }

    /// The fingers that landed between keys, with the key each one presses.
    private var gapTouches: [ObjectIdentifier: UIButton] = [:]

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let key = nearestKey(to: touch.location(in: self)) else { continue }
            gapTouches[ObjectIdentifier(touch)] = key
            key.isHighlighted = true
            showPreview(key)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let key = gapTouches.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            key.isHighlighted = false
            key.sendActions(for: .touchUpInside)
            hidePreview(key, soon: true)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let key = gapTouches.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            key.isHighlighted = false
            hidePreview(key, soon: false)
        }
    }

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

    /// Holding Ctrl lights up the letters that have a shortcut.
    private func showCtrl() {
        for (button, c) in letterKeys where Self.ctrlLetters.contains(c) {
            button.backgroundColor = ctrlHeld ? UIColor.systemBlue.withAlphaComponent(0.35) : UIColor.systemBackground
        }
        ctrlButton?.backgroundColor = ctrlHeld ? UIColor.systemBackground : UIColor.systemGray3
        ctrlButton?.accessibilityValue = ctrlHeld ? "held" : nil
    }

    private func ctrlKey() -> UIButton {
        let k = key("ctrl", id: "ctrl", dark: true) {}
        k.addAction(UIAction { [weak self] _ in self?.ctrlHeld = true }, for: .touchDown)
        k.addAction(UIAction { [weak self] _ in self?.ctrlHeld = false },
                    for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        ctrlButton = k
        return k
    }

    private func build() {
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        letterKeys = []
        markKeys = []
        markHints = []
        previewKeys = [:]
        previewPresses = [:]
        shiftButton = nil
        ctrlButton = nil
        ctrlHeld = false
        ctrlTaps = []
        let top = symbols ? Self.symbolRows : Self.letters
        for (i, chars) in top.enumerated() {
            var keys = chars.map { c -> UIView in
                let shown = symbols ? String(c) : letter(c)
                let button = key(shown, id: shown) { [weak self] in
                    guard let self else { return }
                    if !self.symbols, self.ctrlTaps.remove(c) != nil || self.ctrlHeld {
                        // Other letters do nothing while Ctrl is held.
                        if Self.ctrlLetters.contains(c) { self.onCtrl?(c) }
                        return
                    }
                    let ch = self.symbols ? c : Character(self.letter(c))
                    if ch.isLetter { self.onKey?(.letter(ch)); if self.shift == .once { self.shift = .off } }
                    else if let n = ch.wholeNumberValue { self.onKey?(.digit(n)) }
                    else { self.onKey?(.other(ch)) }
                }
                if !symbols { letterKeys.append((button, c)) } else if !c.isNumber { markKeys.append((button, c)) }
                let corner = !symbols ? Self.hints[c].map { addHint($0, to: button) } : nil
                addPreview(to: button, corner: corner)
                if !symbols && showsCtrl {
                    button.addAction(UIAction { [weak self] _ in
                        if self?.ctrlHeld == true { self?.ctrlTaps.insert(c) }
                    }, for: .touchDown)
                    button.addAction(UIAction { [weak self] _ in self?.ctrlTaps.remove(c) },
                                     for: [.touchUpOutside, .touchCancel])
                }
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
        let ctrl = showsCtrl && !symbols
        var bottom: [UIView] = ctrl ? [ctrlKey()] : []
        bottom.append(key(symbols ? "ABC" : "123", id: "layer", dark: true) { [weak self] in self?.symbols.toggle() })
        if showsNextKeyboard {
            let globe = UIButton(type: .system)
            style(globe, title: "🌐", dark: true)
            globe.accessibilityIdentifier = "nextKeyboard"
            globe.addTarget(self, action: #selector(nextKeyboard(_:event:)), for: .allTouchEvents)
            bottom.append(globe)
        }
        let comma = key("，", id: "comma", dark: true) { [weak self] in self?.onKey?(.other(",")) }
        let period = key("。", id: "period", dark: true) { [weak self] in self?.onKey?(.other(".")) }
        markKeys += [(comma, ","), (period, ".")]
        // Held, the comma key also offers the other comma: , when it shows ，, ， when it shows ,
        addPreview(to: comma, corner: addHint("、", to: comma) { [weak self] in self?.mark(",") == "," ? ["，"] : [","] })
        // Held, the period key also offers the other period: . when it shows 。, 。 when it shows .
        addPreview(to: period, corner: addHint("?", to: period, followsMark: true) { [weak self] in self?.mark(".") == "." ? ["。"] : ["."] })
        bottom += [
            comma,
            key("space", id: "space") { [weak self] in self?.onKey?(.space) },
            period,
            key("return", id: "return", dark: true) { [weak self] in self?.onKey?(.enter) },
        ]
        // Ctrl takes its room from the space bar.
        let weights: [CGFloat] = (ctrl ? [1.2] : []) + (showsNextKeyboard ? [1.2, 1.2] : [1.2]) + [1, ctrl ? 2.8 : 4, 1, 2]
        rows.addArrangedSubview(row(bottom, weights: weights))
        showShift()
        showCtrl()
        showMarks(mark)
    }

    /// Shows on each punctuation key what `mark` says it types now (， or , and so on).
    func showMarks(_ mark: @escaping (Character) -> String) {
        self.mark = mark
        for (button, c) in markKeys {
            let text = mark(c)
            guard button.title(for: .normal) != text else { continue }
            button.setTitle(text, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: text.count == 1 ? 22 : 16)
        }
        for (label, c) in markHints { label.text = mark(c) }
    }

    /// Puts `symbol` in the key's top right corner; held, the key offers it in a popup above it
    /// (half-width and full-width side by side), sliding picks one, lifting types it.
    @discardableResult
    private func addHint(_ symbol: Character, to button: UIButton, followsMark: Bool = false, extra: (() -> [String])? = nil) -> UILabel {
        let label = UILabel()
        label.text = String(symbol)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
        ])
        if followsMark { markHints.append((label, symbol)) }
        let press = SymbolPress(target: self, action: #selector(longPress(_:)))
        press.corner = label
        press.extra = extra
        press.minimumPressDuration = longPress
        button.addGestureRecognizer(press)
        return label
    }

    /// Pressed, the key shows its character in `preview`; lifted, it goes a moment later (never
    /// before `KeyPreview.minimum` on screen); sliding off or a long press hides it at once.
    private func addPreview(to button: UIButton, corner: UILabel?) {
        previewKeys[ObjectIdentifier(button)] = corner
        button.addAction(UIAction { [weak self, weak button] _ in if let button { self?.showPreview(button) } }, for: .touchDown)
        button.addAction(UIAction { [weak self, weak button] _ in if let button { self?.hidePreview(button, soon: true) } }, for: .touchUpInside)
        button.addAction(UIAction { [weak self, weak button] _ in if let button { self?.hidePreview(button, soon: false) } },
                         for: [.touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func showPreview(_ button: UIButton) {
        guard let corner = previewKeys[ObjectIdentifier(button)], !ctrlHeld, let text = button.title(for: .normal) else { return }
        previewPresses[ObjectIdentifier(button)] = preview.show(text, corner: corner?.text, over: button.convert(button.bounds, to: self),
                                                                within: CGRect(x: 0, y: -frame.minY, width: bounds.width, height: bounds.height + frame.minY))
    }

    private func hidePreview(_ button: UIButton, soon: Bool) {
        guard let number = previewPresses.removeValue(forKey: ObjectIdentifier(button)) else { return }
        if soon { preview.hideSoon(number) } else { preview.hide(number) }
    }

    @objc private func longPress(_ press: SymbolPress) {
        guard let button = press.view, let symbol = press.corner?.text, !symbol.isEmpty, !ctrlHeld else { return }
        switch press.state {
        case .began:
            // Over the key, reaching up over the candidate bar but not past the keyboard's top.
            // It starts on the form a tap would type now (全角 after Chinese, 半角 after English).
            if let button = button as? UIButton { hidePreview(button, soon: false) }
            let typed = SymbolPopup.halfWidth(of: symbol).map { mark($0) } ?? symbol
            popup.show(symbol, extra: press.extra?() ?? [], selecting: typed, over: button.convert(button.bounds, to: self),
                       within: CGRect(x: 0, y: -frame.minY, width: bounds.width, height: bounds.height + frame.minY))
        case .changed:
            popup.follow(x: press.location(in: popup).x)
        case .ended:
            if let text = popup.choice { onSymbol?(text) }
            popup.isHidden = true
        default:
            popup.isHidden = true
        }
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

/// The popup over a pressed key, as on Android: its character large, its corner symbol small.
/// One at a time: each press gets a number, and only the latest one shows.
final class KeyPreview: UIView {
    /// How long it stays at least, in seconds, so a quick tap still shows it.
    static let minimum: TimeInterval = 0.2
    private let main = UILabel()
    private let corner = UILabel()
    private var press = 0
    private var shownAt = Date.distantPast

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        isUserInteractionEnabled = false
        backgroundColor = .systemBackground
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 1)
        accessibilityIdentifier = "keyPreview"
        main.font = .systemFont(ofSize: 30)
        main.textAlignment = .center
        main.textColor = .label
        corner.font = .systemFont(ofSize: 12)
        corner.textAlignment = .right
        corner.textColor = .secondaryLabel
        addSubview(main)
        addSubview(corner)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Shows `text` over `key`; returns this press's number.
    func show(_ text: String, corner symbol: String?, over key: CGRect, within area: CGRect) -> Int {
        let width = max(key.width * 1.45, 54), height: CGFloat = 58
        let x = min(max(key.midX - width / 2, area.minX + 2), area.maxX - 2 - width)
        let y = max(key.minY - height + 4, area.minY)
        frame = CGRect(x: x, y: y, width: width, height: height)
        main.frame = bounds
        main.text = text
        corner.frame = CGRect(x: 0, y: 3, width: width - 6, height: 15)
        corner.text = symbol
        accessibilityLabel = text
        isHidden = false
        superview?.bringSubviewToFront(self)
        shownAt = Date()
        press += 1
        return press
    }

    /// Hides the press `number` once lifted: a moment after, and never before `minimum` on screen.
    func hideSoon(_ number: Int) {
        let wait = max(0.05, Self.minimum - Date().timeIntervalSince(shownAt))
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in self?.hide(number) }
    }

    func hide(_ number: Int) {
        if number == press { isHidden = true }
    }
}

/// A long press on a key with a symbol in its corner (the label it reads the symbol from).
final class SymbolPress: UILongPressGestureRecognizer {
    weak var corner: UILabel?
    /// More choices after the symbol's two forms (the period key's other period).
    var extra: (() -> [String])?
}

/// The popup over a held key: its symbol half-width and full-width side by side (one choice when
/// it has no other form), the one under the finger highlighted.
final class SymbolPopup: UIView {
    private var options: [String] = []
    private var selected = 0
    private var cells: [(view: UIView, symbol: UILabel, caption: UILabel)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        isUserInteractionEnabled = false
        backgroundColor = .systemBackground
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 1)
        accessibilityIdentifier = "symbolPopup"
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The symbol lifting the finger types, while shown.
    var choice: String? { isHidden || options.isEmpty ? nil : options[selected] }

    /// The half-width form of `symbol` (shown full-width on the key after Chinese), when it has a full-width one.
    static func halfWidth(of symbol: String) -> Character? {
        guard symbol.unicodeScalars.count == 1, var c = symbol.unicodeScalars.first?.value else { return nil }
        if (0xFF01...0xFF5E).contains(c) { c -= 0xFEE0 }
        return (0x21...0x7E).contains(c) ? Character(UnicodeScalar(c)!) : nil
    }

    /// Shows `symbol` half-width and full-width, then `extra`, with `typed` (the one a tap would type now) selected.
    func show(_ symbol: String, extra: [String] = [], selecting typed: String, over key: CGRect, within area: CGRect) {
        if let half = Self.halfWidth(of: symbol), let c = half.unicodeScalars.first?.value {
            options = [String(half), String(Character(UnicodeScalar(c + 0xFEE0)!))]
        } else {
            options = [symbol]
        }
        options += extra
        selected = options.firstIndex(of: typed) ?? 0
        start = nil
        sliding = false
        cells.forEach { $0.view.removeFromSuperview() }
        cells = []
        let cell = max(key.width * 1.45, 54), height: CGFloat = 58
        let width = cell * CGFloat(options.count)
        // The half-width one over the key, the full-width one beside it (to the left at the right edge).
        let x = min(max(key.midX - cell / 2, area.minX + 2), area.maxX - 2 - width)
        let y = max(key.minY - height + 4, area.minY)
        frame = CGRect(x: x, y: y, width: width, height: height)
        for (i, text) in options.enumerated() {
            let view = UIView(frame: CGRect(x: CGFloat(i) * cell + 3, y: 3, width: cell - 6, height: height - 6))
            view.layer.cornerRadius = 7
            let symbol = UILabel(frame: CGRect(x: 0, y: 2, width: view.bounds.width, height: options.count > 1 ? 34 : view.bounds.height - 4))
            symbol.text = text
            symbol.font = .systemFont(ofSize: 26)
            symbol.textAlignment = .center
            let caption = UILabel(frame: CGRect(x: 0, y: 36, width: view.bounds.width, height: 14))
            caption.text = options.count > 1 ? (text.unicodeScalars.allSatisfy(\.isASCII) ? "半角" : "全角") : nil
            caption.font = .systemFont(ofSize: 10)
            caption.textAlignment = .center
            view.addSubview(symbol)
            view.addSubview(caption)
            addSubview(view)
            cells.append((view, symbol, caption))
        }
        restyle()
        isHidden = false
        superview?.bringSubviewToFront(self)
    }

    /// Where the finger was when the popup opened, until it slides: the first choice stays until then.
    private var start: CGFloat?
    private var sliding = false

    /// The finger is at `x` (in the popup's coordinates): once it has slid, picks the choice under it.
    func follow(x: CGFloat) {
        guard !options.isEmpty else { return }
        if !sliding {
            guard let start else { self.start = x; return }
            if abs(x - start) < 8 { return }
            sliding = true
        }
        let i = min(max(Int(x / (bounds.width / CGFloat(options.count))), 0), options.count - 1)
        if i != selected { selected = i; restyle() }
    }

    private func restyle() {
        for (i, cell) in cells.enumerated() {
            let on = i == selected
            cell.view.backgroundColor = on ? .systemBlue : .clear
            cell.symbol.textColor = on ? .white : .label
            cell.caption.textColor = on ? .white : .secondaryLabel
        }
    }
}
