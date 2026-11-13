import XCTest

@MainActor
final class SkinUITests: XCTestCase {
    func testSwitchingStylesKeepsAppearanceAndMeetingHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--meeting-ui-testing", "--reset-ui-data", "--reset-ui-style", "--seed-meeting", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        app.buttons["Settings"].click()
        app.buttons["appearance.dark"].click()
        app.radioButtons["style.native"].click()
        XCTAssertTrue(app.radioButtons["moon"].waitForExistence(timeout: 5))
        XCTAssertEqual("\(app.radioButtons["moon"].value ?? "")", "1")
        app.radioButtons["style.classic"].click()
        XCTAssertTrue(app.buttons["appearance.dark"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["appearance.dark"].isSelected)
        app.buttons["Meetings"].click()
        XCTAssertTrue(app.staticTexts["meeting.document.title"].waitForExistence(timeout: 5))
        app.buttons["Settings"].click()
        app.buttons["appearance.system"].click()
    }
}
