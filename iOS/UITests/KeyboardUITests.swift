import XCTest

/// Types with the Tatakikun keyboard in the app's Try it field (the same KeyboardView as the
/// extension; a simulator without a window never shows third-party keyboards in other apps).
final class KeyboardUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-languagesOff", "()"]   // every language on, whatever a test left
        app.launch()
        app.textViews["tryField"].tap()   // the Try it field always brings up Tatakikun's keys
        XCTAssertTrue(app.buttons["layer"].waitForExistence(timeout: 5), "the Tatakikun keys are not showing")
    }

    var field: XCUIElement { app.textViews["tryField"] }

    func type(_ letters: String) {
        for c in letters { app.buttons[String(c)].firstMatch.tap() }
    }

    var text: String { (field.value as? String) ?? "" }

    func testWholeSentencePinyinByTappingCandidate() {
        type("woaini")
        let candidate = app.buttons["我爱你"]
        XCTAssertTrue(candidate.waitForExistence(timeout: 3))
        attach("woaini")
        candidate.tap()
        XCTAssertEqual(text, "我爱你")
    }

    func testMixedCandidatesForAi() {
        type("ai")
        for word in ["ai", "爱", "あい"] { XCTAssertTrue(app.buttons[word].waitForExistence(timeout: 3), word) }
        attach("ai")
        app.buttons["expand"].tap()
        attach("ai expanded")
        app.buttons["expand"].tap()
        app.buttons["space"].tap()
        XCTAssertFalse(text.isEmpty)
    }

    func testRomajiAndReturnKeepsLetters() {
        type("arigatou")
        XCTAssertTrue(app.buttons["ありがとう"].waitForExistence(timeout: 3))
        app.buttons["return"].tap()
        XCTAssertEqual(text, "arigatou")
    }

    func testInitialsAndPunctuation() {
        type("nh")
        XCTAssertTrue(app.buttons["你好"].waitForExistence(timeout: 3))
        app.buttons["你好"].tap()
        app.buttons["comma"].tap()
        XCTAssertEqual(text, "你好，")
    }

    func testEnglishCompletion() {
        type("compu")
        XCTAssertTrue(app.buttons["computer"].waitForExistence(timeout: 3) || {
            app.buttons["expand"].tap(); return app.buttons["computer"].waitForExistence(timeout: 2)
        }())
    }

    /// A04-quail228: one tap on shift is for the next letter only; two quick taps are caps lock
    /// until shift is tapped again.
    func testShiftOnceAndCapsLock() {
        let shift = app.buttons["shift"]
        shift.tap()
        XCTAssertEqual(shift.value as? String, "on")
        type("Hi")
        XCTAssertEqual(shift.value as? String, "off")
        app.buttons["return"].tap()
        shift.doubleTap()
        XCTAssertEqual(shift.value as? String, "caps lock")
        type("OK")
        XCTAssertEqual(shift.value as? String, "caps lock")
        attach("caps lock")
        shift.tap()
        XCTAssertEqual(shift.value as? String, "off")
        type("a")
        app.buttons["return"].tap()
        XCTAssertEqual(text, "HiOKa")
    }

    /// A04-tide827: a tap that misses every key types the nearest one: in the gap between two
    /// keys, on the blank start of the asdf row, and just outside a key on the edge.
    func testTapsBetweenKeysTypeTheNearestKey() {
        /// Taps `x`, `y` points from the key's center.
        func tap(_ key: String, x: CGFloat, y: CGFloat) {
            let frame = app.buttons[key].firstMatch.frame
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX + x, dy: frame.midY + y)).tap()
        }
        let q = app.buttons["q"].firstMatch.frame, a = app.buttons["a"].firstMatch.frame
        let p = app.buttons["p"].firstMatch.frame, b = app.buttons["b"].firstMatch.frame
        tap("q", x: q.width / 2 + 1, y: 0)            // in the gap between q and w, nearer q
        tap("a", x: -a.width / 2 - a.width / 4, y: 0)  // on the blank half key left of a
        tap("p", x: p.width / 2 + 2, y: 0)            // past the right edge of p
        tap("b", x: 0, y: b.height / 2 + 2)           // in the gap below b, nearer b
        attach("taps between keys")
        app.buttons["return"].tap()
        XCTAssertEqual(text, "qapb")
    }

    /// A04-peak016: the comma and period keys show what a tap types: half-width after English,
    /// full-width while a Chinese word is composed and after Chinese text.
    func testPunctuationKeysShowWhatTheyType() {
        let comma = app.buttons["comma"], period = app.buttons["period"]
        XCTAssertEqual(comma.label, ",", "an empty field: English")
        type("hello")
        app.buttons["space"].tap()
        XCTAssertEqual(comma.label, ",")
        XCTAssertEqual(period.label, ".")
        type("nihao")
        XCTAssertTrue(app.buttons["你好"].waitForExistence(timeout: 3))
        XCTAssertEqual(comma.label, "，", "composing a Chinese word")
        app.buttons["你好"].tap()
        XCTAssertEqual(comma.label, "，", "after Chinese text")
        XCTAssertEqual(period.label, "。")
        attach("punctuation after Chinese")
        comma.tap()
        XCTAssertEqual(text, "hello 你好，")
    }

    /// A04-leaf790: holding a letter offers its corner symbol half-width and full-width; lifting
    /// types the one under the finger; a tap still types the letter.
    func testLongPressTypesTheCornerSymbol() {
        let g = app.buttons["g"].firstMatch
        g.press(forDuration: 0.8)
        XCTAssertEqual(text, "&")
        let center = g.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.8, thenDragTo: g.coordinate(withNormalizedOffset: CGVector(dx: 2.0, dy: 0.5)))
        XCTAssertEqual(text, "&＆")
        attach("long press")
        type("g")
        app.buttons["return"].tap()
        XCTAssertEqual(text, "&＆g")
    }

    /// A04-canvas393: the popup starts on the form a tap would type now: full-width after
    /// Chinese, half-width after English; lifting without sliding types it.
    func testLongPressStartsOnWhatATapTypes() {
        type("nihao")
        XCTAssertTrue(app.buttons["你好"].waitForExistence(timeout: 3))
        app.buttons["你好"].tap()
        app.buttons["m"].firstMatch.press(forDuration: 0.8)
        XCTAssertEqual(text, "你好？")
        // The period key shows 。 after Chinese; held, it also offers . (the last choice).
        let period = app.buttons["period"]
        period.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.8, thenDragTo: app.buttons["return"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
        XCTAssertEqual(text, "你好？.")
        // After Chinese again the comma key shows ，; held, it offers 、 and , (slide right to ,).
        type("nihao")
        XCTAssertTrue(app.buttons["你好"].waitForExistence(timeout: 3))
        app.buttons["你好"].tap()
        let comma = app.buttons["comma"]
        comma.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.8, thenDragTo: comma.coordinate(withNormalizedOffset: CGVector(dx: 2.5, dy: 0.5)))
        XCTAssertEqual(text, "你好？.你好,")
        type("hello")
        app.buttons["space"].tap()
        app.buttons["m"].firstMatch.press(forDuration: 0.8)
        XCTAssertEqual(text, "你好？.你好,hello ?")
    }

    /// A04-plate725: a symbol picked by long press while a word is being typed comes after the word.
    func testLongPressAfterAWordComesAfterIt() {
        type("good")
        app.buttons["m"].firstMatch.press(forDuration: 0.8)
        XCTAssertEqual(text, "good?")
    }

    /// A04-cell054: iPad has a Ctrl key at the start of the bottom row; iPhone does not. The
    /// Full Access explanation is on the iPad setup screen.
    func testCtrlKeyOnlyOnPad() {
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        XCTAssertEqual(app.buttons["ctrl"].exists, pad)
        guard pad else { return }
        XCTAssertLessThan(app.buttons["ctrl"].frame.minX, app.buttons["layer"].frame.minX)
        attach("ctrl key")
        app.buttons["layer"].tap()
        XCTAssertFalse(app.buttons["ctrl"].exists, "the symbols layer has no Ctrl")
        app.buttons["layer"].tap()
        XCTAssertTrue(app.buttons["ctrl"].exists)
    }

    /// A04-tuna688: Input languages turns each pack on or off; a language turned off gives no
    /// candidates, the choice is kept after a restart, and the last language stays on.
    func testInputLanguageSwitches() {
        func languages() {
            app.buttons["languagePacks"].tap()
            XCTAssertTrue(app.switches["language-ja"].waitForExistence(timeout: 3))
        }
        func turn(_ id: String, on: Bool) {
            let toggle = app.switches["language-\(id)"]
            if (toggle.value as? String == "1") != on { toggle.switches.firstMatch.tap() }
            XCTAssertEqual(toggle.value as? String, on ? "1" : "0", id)
        }
        func back() { app.navigationBars.buttons.firstMatch.tap() }
        app.terminate()
        app.launchArguments = []   // the switches as saved
        app.launch()
        languages()
        for id in ["en", "zh", "ja", "es", "fr", "hi", "bn", "ar"] { turn(id, on: true) }
        turn("ja", on: false)
        attach("Japanese off")
        back()
        field.tap()
        type("watashi")
        XCTAssertTrue(app.buttons["return"].waitForExistence(timeout: 3))
        sleep(1)
        XCTAssertFalse(app.buttons["わたし"].exists)
        XCTAssertFalse(app.buttons["私"].exists)
        app.buttons["return"].tap()

        app.terminate()
        app.launch()
        languages()
        XCTAssertEqual(app.switches["language-ja"].value as? String, "0", "kept after a restart")
        turn("ja", on: true)
        turn("en", on: false)
        turn("zh", on: false)
        turn("es", on: false)
        turn("fr", on: false)
        turn("hi", on: false)
        turn("bn", on: false)
        turn("ar", on: false)
        XCTAssertFalse(app.switches["language-ja"].isEnabled, "the last language stays on")
        attach("only Japanese on")
        turn("en", on: true)
        turn("zh", on: true)
        turn("es", on: true)
        turn("fr", on: true)
        turn("hi", on: true)
        turn("bn", on: true)
        turn("ar", on: true)
        back()
        field.tap()
        type("watashi")
        XCTAssertTrue(app.buttons["私"].waitForExistence(timeout: 3) || app.buttons["わたし"].exists)
    }

    /// A03-wood850-01: Spanish accents come from plain letters.
    func testSpanishAccentsFromPlainLetters() {
        type("cancion")
        let candidate = app.buttons["canción"]
        XCTAssertTrue(candidate.waitForExistence(timeout: 3))
        attach("cancion")
        candidate.tap()
        XCTAssertEqual(text, "canción")
        type("nino")
        XCTAssertTrue(app.buttons["niño"].waitForExistence(timeout: 3))
        app.buttons["niño"].tap()
        XCTAssertEqual(text, "canciónniño")
    }

    /// A03-wood850-02: French accents, ç and œ come from plain letters.
    func testFrenchAccentsFromPlainLetters() {
        type("francais")
        XCTAssertTrue(app.buttons["français"].waitForExistence(timeout: 3))
        app.buttons["français"].tap()
        type("coeur")
        XCTAssertTrue(app.buttons["cœur"].waitForExistence(timeout: 3))
        attach("coeur")
        app.buttons["cœur"].tap()
        XCTAssertEqual(text, "françaiscœur")
    }

    /// A03-wood850-03: Hindi typed by sound; Devanagari shows in the bar and the field.
    func testHindiBySound() {
        type("namaste")
        XCTAssertTrue(app.buttons["नमस्ते"].waitForExistence(timeout: 3))
        attach("namaste")
        app.buttons["नमस्ते"].tap()
        XCTAssertEqual(text, "नमस्ते")
    }

    /// A03-wood850-05: Bengali typed by sound; Bengali script shows in the bar and the field.
    func testBengaliBySound() {
        type("dhonnobad")
        XCTAssertTrue(app.buttons["ধন্যবাদ"].waitForExistence(timeout: 3))
        attach("dhonnobad")
        app.buttons["ধন্যবাদ"].tap()
        XCTAssertEqual(text, "ধন্যবাদ")
    }

    /// A03-wood850-04: Arabic in Arabizi; right to left in the bar, and in order after English.
    func testArabicInArabizi() {
        type("hello")
        app.buttons["space"].tap()
        type("marhaba")
        XCTAssertTrue(app.buttons["مرحبا"].waitForExistence(timeout: 3))
        attach("marhaba")
        app.buttons["مرحبا"].tap()
        XCTAssertEqual(text, "hello مرحبا")
    }

    /// The Try it field reads the pasteboard when the clipboard list opens; iOS asks first.
    func openClipboard() {
        app.buttons["clipboard"].tap()
        // "Allow Paste" in the simulator's language (ペーストを許可 in Japanese), not "Don't Allow Paste".
        let allow = NSPredicate(format: "label IN %@", ["Allow Paste", "ペーストを許可", "允许粘贴"])
        for alerts in [XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts, app.alerts] {
            let button = alerts.buttons.matching(allow).firstMatch
            if button.waitForExistence(timeout: 2) { button.tap(); return }
        }
    }

    func testClipboardHistory() {
        XCTAssertTrue(app.buttons["clipboard"].exists, "the clipboard button is on the bar while nothing is typed")
        openClipboard()
        if app.buttons["clipClear"].exists { app.buttons["clipClear"].tap() }
        app.buttons["clipBack"].tap()
        for text in ["first copy", "second copy\nwith two lines", "first copy"] {
            UIPasteboard.general.string = text
            openClipboard()
            app.buttons["clipBack"].tap()
        }
        openClipboard()
        XCTAssertTrue(app.buttons["clip0"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["clip2"].exists, "copying the same text again moves it up instead of adding it twice")
        XCTAssertEqual(app.buttons["clip0"].label, "first copy")
        XCTAssertEqual(app.buttons["clip1"].label, "second copy ⏎ with two lines", "a copy shows on as few lines as it can")
        XCTAssertFalse(app.buttons["layer"].isHittable, "the list shows in place of the keys")
        attach("clipboard list")
        app.buttons["clip1"].tap()
        XCTAssertEqual(text, "second copy\nwith two lines", "tapping a copy pastes all of it")
        XCTAssertTrue(app.buttons["layer"].waitForExistence(timeout: 2), "the keys come back")

        openClipboard()
        app.buttons["clipDelete0"].tap()
        XCTAssertFalse(app.buttons["clip1"].exists)
        app.buttons["clipClear"].tap()
        XCTAssertFalse(app.buttons["clip0"].exists)
        attach("clipboard empty")
        app.buttons["clipBack"].tap()

        // The chip: the latest copy, pasted with one tap, then gone.
        UIPasteboard.general.string = "chip text"
        openClipboard()
        app.buttons["clipBack"].tap()
        XCTAssertTrue(app.buttons["clipChip"].waitForExistence(timeout: 2))
        attach("clipboard chip")
        app.buttons["clipChip"].tap()
        XCTAssertTrue(text.hasSuffix("chip text"))
        XCTAssertFalse(app.buttons["clipChip"].exists)
        type("ni")
        XCTAssertFalse(app.buttons["clipboard"].exists, "while typing the bar shows candidates")
    }

    func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
