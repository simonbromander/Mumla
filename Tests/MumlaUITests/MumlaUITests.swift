import XCTest

@MainActor
final class MumlaUITests: XCTestCase {
    func testNavigationAndDictionaryPersistence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "-AppleLanguages", "(sv)"]
        app.launch()
        XCTAssertTrue(app.buttons["Inställningar"].waitForExistence(timeout: 10))
        capture("01-dictate", app: app)

        app.buttons["Historik"].tap()
        XCTAssertTrue(app.textFields["Sök dikteringar"].waitForExistence(timeout: 3))
        capture("02-history", app: app)
        app.buttons["Ordlista"].tap()
        app.buttons["Lägg till ord"].tap()
        app.textFields["Ersätt"].tap()
        app.textFields["Ersätt"].typeText("Kubernetis")
        app.textFields["Med"].tap()
        app.textFields["Med"].typeText("Kubernetes")
        capture("15-add-word", app: app)
        app.buttons["Spara"].tap()
        XCTAssertTrue(app.staticTexts["Kubernetes"].waitForExistence(timeout: 3))
        capture("03-dictionary", app: app)
        app.terminate()

        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(sv)"]
        app.launch()
        app.buttons["Ordlista"].tap()
        XCTAssertTrue(app.staticTexts["Kubernetes"].waitForExistence(timeout: 3))
        app.buttons["Ta bort Kubernetes"].tap()
        XCTAssertTrue(app.staticTexts["Din ordlista är tom"].waitForExistence(timeout: 3))

        app.buttons["Inställningar"].tap()
        XCTAssertTrue(app.staticTexts["Språkmodell"].waitForExistence(timeout: 3))
        capture("04-settings", app: app)
        let haptics = app.switches["Haptisk återkoppling"]
        setSwitch(haptics, enabled: false)
        app.buttons["Klart"].tap()
        app.terminate()
        app.launch()
        app.buttons["Inställningar"].tap()
        let restoredHaptics = app.switches["Haptisk återkoppling"]
        XCTAssertTrue(restoredHaptics.waitForExistence(timeout: 3))
        XCTAssertEqual(restoredHaptics.value as? String, "0")
        setSwitch(restoredHaptics, enabled: true)
        app.buttons["Klart"].tap()
    }

    func testLargeTextAndEnglish() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        app.buttons["Dictionary"].tap()
        XCTAssertTrue(app.buttons["Add word"].waitForExistence(timeout: 3))
        capture("05-large-text", app: app)
    }

    func testLatestTranscriptInlineActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "--seed-transcript", "-AppleLanguages", "(sv)"]
        app.launch()
        XCTAssertTrue(app.buttons["showLatestTranscript"].waitForExistence(timeout: 10))
        app.buttons["showLatestTranscript"].tap()

        let preview = app.textViews["latestTranscript.preview"]
        let copy = app.buttons["latestTranscript.copy"]
        let share = app.buttons["latestTranscript.share"]
        let fullTranscript = preview.value as? String
        XCTAssertTrue(copy.waitForExistence(timeout: 3))
        XCTAssertTrue(copy.isHittable)
        XCTAssertTrue(share.isHittable)
        XCTAssertFalse(app.buttons["Visa historik"].exists)
        XCTAssertFalse(app.staticTexts["An older transcript."].exists)
        preview.tap()
        XCTAssertFalse(app.staticTexts["Diktering"].exists)
        copy.tap()
        XCTAssertEqual(app.staticTexts["latestTranscript.copyStatus"].label, "Kopierat")
        capture("06-latest-transcript", app: app)

        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.otherElements["LP.CaptionBar.BottomCaption"].label, fullTranscript)
        let systemCopy = app.cells.matching(NSPredicate(format: "label IN %@", ["Copy", "Kopiera"])).firstMatch
        XCTAssertTrue(systemCopy.waitForExistence(timeout: 5))
        capture("07-share-transcript", app: app)
        systemCopy.tap()
        XCTAssertTrue(share.waitForExistence(timeout: 3))
        app.buttons["Historik"].tap()
        let record = app.buttons.containing(.staticText, identifier: "An older transcript.").firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 3))
        record.tap()
        XCTAssertTrue(app.textViews["transcript.text"].waitForExistence(timeout: 3))
        capture("16-transcript-detail", app: app)
    }

    func testLatestTranscriptLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "--seed-transcript", "-AppleLanguages", "(en)", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["showLatestTranscript"].waitForExistence(timeout: 10))
        app.buttons["showLatestTranscript"].tap()
        let copy = app.buttons["latestTranscript.copy"]
        let share = app.buttons["latestTranscript.share"]
        XCTAssertTrue(copy.waitForExistence(timeout: 3))
        XCTAssertTrue(copy.isHittable)
        XCTAssertTrue(share.isHittable)
        XCTAssertFalse(copy.frame.intersects(share.frame))
        capture("08-latest-transcript-large-text", app: app)
    }

    func testStereoTabsLatchOneAtATime() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "-AppleLanguages", "(sv)"]
        app.launch()
        let names = ["dictate", "history", "dictionary"]
        let keys = names.map { app.buttons["tab.\($0)"] }
        XCTAssertTrue(keys[0].waitForExistence(timeout: 10))
        let frames = keys.map(\.frame)
        assertLatchedKey(0, keys: keys)
        capture("09-stereo-dictate", app: app)

        keys[1].tap()
        assertLatchedKey(1, keys: keys)
        XCTAssertTrue(app.textFields["Sök dikteringar"].exists)
        capture("10-stereo-history", app: app)
        keys[2].tap()
        assertLatchedKey(2, keys: keys)
        XCTAssertTrue(app.buttons["Lägg till ord"].exists)
        capture("11-stereo-dictionary", app: app)

        keys[2].tap()
        assertLatchedKey(2, keys: keys)
        keys[1].press(forDuration: 0.15, thenDragTo: app.buttons["Inställningar"])
        assertLatchedKey(2, keys: keys)
        keys[0].tap()
        assertLatchedKey(0, keys: keys)
        for (key, original) in zip(keys, frames) {
            XCTAssertEqual(key.frame.minY, original.minY, accuracy: 1)
            XCTAssertEqual(key.frame.height, original.height, accuracy: 1)
            XCTAssertGreaterThanOrEqual(key.frame.height, 44)
        }
    }

    func testSelectedWordCorrectionAndPersistence() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "--seed-correction", "-AppleLanguages", "(sv)"]
        app.launch()
        XCTAssertTrue(app.buttons["showLatestTranscript"].waitForExistence(timeout: 10))
        app.buttons["showLatestTranscript"].tap()
        let preview = app.textViews["latestTranscript.preview"]
        openCorrection(in: preview, app: app)
        XCTAssertFalse(app.buttons["correction.save"].isEnabled)
        app.textFields["correction.replacement"].typeText("Kubernetes")
        capture("12-correct-word", app: app)
        app.buttons["correction.save"].tap()
        let corrected = "Kubernetes fungerar. Vi använder Kubernetis varje dag."
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        XCTAssertEqual(preview.value as? String, corrected)
        app.buttons["latestTranscript.copy"].tap()
        XCTAssertEqual(app.staticTexts["latestTranscript.copyStatus"].label, "Kopierat")
        app.buttons["latestTranscript.share"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.otherElements["LP.CaptionBar.BottomCaption"].label, corrected)
        app.cells.matching(NSPredicate(format: "label IN %@", ["Copy", "Kopiera"])).firstMatch.tap()
        app.buttons["tab.dictionary"].tap()
        XCTAssertTrue(app.staticTexts["Kubernetes"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Kubernetis"].exists)
        capture("13-learned-word", app: app)
        app.terminate()

        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(sv)"]
        app.launch()
        app.buttons["tab.history"].tap()
        app.buttons.containing(.staticText, identifier: corrected).firstMatch.tap()
        let detail = app.textViews["transcript.text"]
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        XCTAssertEqual(detail.value as? String, corrected)
        openCorrection(in: detail, app: app)
        app.textFields["correction.replacement"].typeText("Cancelled")
        app.buttons["correction.cancel"].tap()
        XCTAssertEqual(detail.value as? String, corrected)
        openCorrection(in: detail, app: app)
        app.textFields["correction.replacement"].typeText("Kube")
        app.buttons["correction.save"].tap()
        XCTAssertEqual(detail.value as? String, "Kube fungerar. Vi använder Kubernetis varje dag.")
        app.buttons["Klart"].tap()
        app.buttons["tab.dictionary"].tap()
        XCTAssertTrue(app.staticTexts["Kube"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Cancelled"].exists)
    }

    func testCorrectionLargeTextAndEnglish() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "--seed-correction", "-AppleLanguages", "(en)", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["showLatestTranscript"].waitForExistence(timeout: 10))
        app.buttons["showLatestTranscript"].tap()
        let preview = app.textViews["latestTranscript.preview"]
        openCorrection(in: preview, app: app, title: "Correct word")
        let field = app.textFields["correction.replacement"]
        field.typeText("two words")
        XCTAssertFalse(app.buttons["correction.save"].isEnabled)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 9) + "Kubernetes")
        XCTAssertTrue(app.buttons["correction.save"].isEnabled)
        capture("14-correction-large-text", app: app)
        app.buttons["correction.save"].tap()
        XCTAssertEqual(preview.value as? String, "Kubernetes fungerar. Vi använder Kubernetis varje dag.")
    }

    private func openCorrection(in text: XCUIElement, app: XCUIApplication, title: String = "Rätta ord") {
        XCTAssertTrue(text.waitForExistence(timeout: 3))
        text.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 12)).doubleTap()
        let action = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        action.tap()
        XCTAssertTrue(app.textFields["correction.replacement"].waitForExistence(timeout: 3))
        if app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
    }

    private func assertLatchedKey(_ index: Int, keys: [XCUIElement]) {
        for (position, key) in keys.enumerated() {
            XCTAssertEqual(key.isSelected, position == index)
        }
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func setSwitch(_ control: XCUIElement, enabled: Bool) {
        let value = enabled ? "1" : "0"
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        if control.value as? String != value {
            // SwiftUI exposes the entire Form row as a switch on iPad.
            control.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
                .withOffset(CGVector(dx: -25, dy: 0)).tap()
        }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }
}
