import XCTest

/// Types with the Tatakikun keyboard in the app's Try it field (the same KeyboardView as the
/// extension; a simulator without a window never shows third-party keyboards in other apps).
final class KeyboardUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
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

    func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
