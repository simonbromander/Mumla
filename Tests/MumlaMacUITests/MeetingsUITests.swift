import XCTest

@MainActor
final class MeetingsUITests: XCTestCase {
    private func launch(compact: Bool = false, long: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--meeting-ui-testing", "--reset-ui-data", "--seed-meeting", "-AppleLanguages", "(en)", "-mumla.appearance", "light"]
        if compact { app.launchArguments.append("--compact-window") }
        if long { app.launchArguments.append("--long-meeting") }
        app.launch()
        XCTAssertTrue(app.buttons["meeting.actions"].waitForExistence(timeout: 10))
        return app
    }

    func testCompactTranscriptUsesFullWidthAndWrapsLongTitle() {
        let app = launch(compact: true, long: true)
        let title = app.staticTexts["meeting.document.title"]
        XCTAssertTrue(title.exists)
        XCTAssertGreaterThan(title.frame.height, 30)
        XCTAssertGreaterThan(title.frame.width, 400)
        XCTAssertLessThanOrEqual(title.frame.maxX, app.windows.firstMatch.frame.maxX)
        XCTAssertFalse(app.scrollViews["meeting.library.list"].exists)
        for id in ["meeting.actions", "meeting.speakers", "meeting.library"] {
            XCTAssertTrue(app.buttons[id].isHittable)
            XCTAssertGreaterThanOrEqual(app.buttons[id].frame.width, 44)
        }
        capture("meetings-compact-long", app)
        app.buttons["meeting.library"].click()
        XCTAssertTrue(app.scrollViews["meeting.library.list"].waitForExistence(timeout: 3))
        capture("meetings-library-picker", app)
    }

    func testCorrectionSheetSavesTextAndSpeakerAndCancelDoesNotApply() {
        let app = launch()
        app.buttons["meeting.correct.example-0"].click()
        let editor = app.textViews["meeting.edit.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.click(); editor.typeKey("a", modifierFlags: .command); editor.typeText("A corrected line.")
        let speaker = app.textFields["meeting.edit.speaker"].firstMatch
        speaker.click(); speaker.typeKey("a", modifierFlags: .command); speaker.typeText("Mumla tester")
        capture("meetings-correction", app)
        app.buttons["meeting.edit.save"].click()
        let passage = app.descendants(matching: .any).matching(identifier: "meeting.passage.example-0").firstMatch
        XCTAssertTrue(passage.waitForExistence(timeout: 3))
        XCTAssertTrue((passage.value as? String ?? passage.label).contains("A corrected line."))
        app.buttons["meeting.correct.example-0"].click()
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.click(); editor.typeKey("a", modifierFlags: .command); editor.typeText("Must not save this.")
        app.buttons["meeting.edit.cancel"].click()
        XCTAssertTrue(passage.waitForExistence(timeout: 3))
        XCTAssertFalse((passage.value as? String ?? passage.label).contains("Must not"))
    }

    func testAudioDeletionKeepsTranscriptAndFullDeletionNeedsConfirmation() {
        let app = launch()
        app.buttons["meeting.actions"].click(); app.buttons["Delete audio only"].click()
        XCTAssertTrue(app.buttons["meeting.delete.cancel"].waitForExistence(timeout: 3))
        capture("meetings-delete-audio", app)
        app.buttons["meeting.delete.cancel"].click()
        XCTAssertTrue(app.buttons["meeting.actions"].waitForExistence(timeout: 3))
        app.buttons["meeting.actions"].click(); app.buttons["Delete audio only"].click()
        app.buttons["meeting.delete.confirm"].click()
        let status = app.staticTexts["meeting.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertEqual(status.value as? String ?? status.label, "Audio deleted")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "meeting.passage.example-0").firstMatch.exists)
        app.buttons["meeting.actions"].click(); app.buttons["Delete meeting"].click()
        capture("meetings-delete-meeting", app)
        app.buttons["meeting.delete.confirm"].click()
        XCTAssertTrue(app.buttons["meeting.start"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["meeting.library"].isEnabled)
    }

    func testCompactRecordingKeepsPauseAndStopAccessible() {
        let app = launch(compact: true)
        app.buttons["meeting.new"].click()
        app.buttons["meeting.source"].click()
        XCTAssertTrue(app.buttons["Microphone only"].waitForExistence(timeout: 3))
        capture("meetings-source-picker", app)
        app.buttons["Microphone only"].click()
        app.buttons["meeting.start"].click()
        let stop = app.buttons["meeting.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 3)); XCTAssertTrue(stop.isHittable)
        XCTAssertFalse(app.buttons["meeting.new"].isEnabled)
        app.buttons["Pause recording"].click()
        XCTAssertTrue(app.buttons["Resume recording"].waitForExistence(timeout: 3))
        XCTAssertTrue(stop.isHittable)
        capture("meetings-paused-compact", app)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.buttons["meeting.quit.cancel"].waitForExistence(timeout: 3))
        capture("meetings-quit-confirmation", app)
        app.buttons["meeting.quit.cancel"].click()
        XCTAssertTrue(stop.waitForExistence(timeout: 3))
        app.buttons["Resume recording"].click(); stop.click()
        XCTAssertTrue(app.buttons["meeting.new"].isEnabled)
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
}
