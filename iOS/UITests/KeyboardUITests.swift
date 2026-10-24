import XCTest

/// Types with the Tatakikun keyboard in the app's demo screen (the same KeyboardView as the
/// extension; a simulator without a window never shows third-party keyboards in other apps).
final class KeyboardUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        app.buttons["demo"].tap()
        XCTAssertTrue(app.buttons["layer"].waitForExistence(timeout: 5), "the Tatakikun keys are not showing")
    }

    var field: XCUIElement { app.textViews["demoText"] }

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

    func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
