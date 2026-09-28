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
