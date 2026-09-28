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

        let preview = app.staticTexts["latestTranscript.preview"]
        let copy = app.buttons["latestTranscript.copy"]
        let share = app.buttons["latestTranscript.share"]
        let fullTranscript = preview.label
        XCTAssertTrue(copy.waitForExistence(timeout: 3))
        XCTAssertTrue(copy.isHittable)
        XCTAssertTrue(share.isHittable)
        XCTAssertFalse(app.buttons["Visa historik"].exists)
        XCTAssertFalse(app.staticTexts["An older transcript."].exists)
        preview.tap()
        XCTAssertFalse(app.navigationBars["Diktering"].exists)
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
        XCTAssertTrue(app.navigationBars["Diktering"].waitForExistence(timeout: 3))
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
