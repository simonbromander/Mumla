import AppKit
import XCTest

@MainActor
final class MeetingsUITests: XCTestCase {
    func testInterruptedMeetingStaysClearlyMarkedAfterTranscriptIsReady() {
        let app = XCUIApplication()
        app.launchArguments = ["--meeting-ui-testing", "--reset-ui-data", "--seed-meeting", "--interrupted-meeting",
                               "--compact-window", "-AppleLanguages", "(en)", "-mumla.appearance", "light"]
        app.launch()
        let document = app.staticTexts["meeting.document.title"]
        XCTAssertTrue(document.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "meeting.interrupted").firstMatch.exists)
        let status = app.staticTexts["meeting.status"]
        XCTAssertEqual(status.value as? String ?? status.label, "Interrupted · partial recording")
        XCTAssertTrue(app.buttons["meeting.actions"].isHittable)
        capture("meetings-interrupted-compact", app)
    }

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
        XCTAssertTrue(app.textFields["meeting.library.search"].exists)
        XCTAssertFalse(app.buttons["meeting.start"].exists)
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

    func testSpeakerSelectorAssignsOnlyTheChosenPassageAndCanRestoreItsPreviousSpeaker() {
        let app = launch(compact: true)
        let speaker = app.buttons["meeting.assign.example-1"]
        XCTAssertTrue(speaker.waitForExistence(timeout: 3))
        XCTAssertTrue(speaker.label.contains("Anna"))
        speaker.click()
        let unassigned = app.buttons["meeting.assign.choice.system"]
        XCTAssertTrue(unassigned.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["meeting.assign.choice.microphone"].exists)
        capture("meetings-speaker-selector", app)
        unassigned.click()
        XCTAssertTrue(speaker.label.contains("Unassigned remote"))
        XCTAssertTrue(app.buttons["meeting.assign.example-0"].label.contains("Me"))
        let passage = app.descendants(matching: .any).matching(identifier: "meeting.passage.example-1").firstMatch
        XCTAssertTrue((passage.value as? String ?? passage.label).contains("Bra. Jag vill"))
        speaker.click()
        app.buttons["meeting.assign.choice.system-0"].click()
        XCTAssertTrue(speaker.label.contains("Anna"))
        speaker.click()
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(speaker.label.contains("Anna"))
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
        XCTAssertTrue(app.buttons["meeting.new"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["meeting.start"].exists)
        XCTAssertTrue(app.staticTexts["No saved meetings"].exists)
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

    func testSystemAudioAndMicrophoneAreDefaultAndOtherSourcesRemainAvailable() {
        let app = launch(compact: true)
        app.buttons["meeting.new"].click()
        let source = app.buttons["meeting.source"]
        XCTAssertTrue(source.label.contains("System audio + microphone"))
        source.click()
        let system = app.buttons["meeting.source.system"]
        let microphone = app.buttons["meeting.source.microphone"]
        XCTAssertTrue(system.waitForExistence(timeout: 3))
        XCTAssertTrue(microphone.exists)
        XCTAssertTrue(app.buttons["Meeting app"].exists)
        capture("meetings-source-system-default", app)
        microphone.click()
        XCTAssertTrue(source.label.contains("Microphone only"))
        source.click(); system.click()
        XCTAssertTrue(source.label.contains("System audio + microphone"))
        app.buttons["meeting.start"].click()
        XCTAssertTrue(app.buttons["meeting.stop"].waitForExistence(timeout: 3))
        app.buttons["meeting.stop"].click()
    }

    func testMeetingSuggestionWaitsForExplicitStart() {
        let app = XCUIApplication()
        app.launchArguments = ["--meeting-ui-testing", "--reset-ui-data", "--suggest-meeting", "-AppleLanguages", "(en)"]
        app.launch()
        let start = app.buttons["meeting.suggestion.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["meeting.stop"].exists)
        capture("meetings-suggestion", app)
        start.click()
        XCTAssertTrue(app.buttons["meeting.stop"].waitForExistence(timeout: 5))
        XCTAssertFalse(start.exists)
        app.buttons["meeting.stop"].click()
    }

    func testMeetingSuggestionDismissalDoesNotRecord() {
        let app = XCUIApplication()
        app.launchArguments = ["--meeting-ui-testing", "--reset-ui-data", "--suggest-meeting", "-AppleLanguages", "(en)"]
        app.launch()
        let dismiss = app.buttons["meeting.suggestion.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 10))
        dismiss.click()
        XCTAssertFalse(dismiss.exists)
        XCTAssertFalse(app.buttons["meeting.stop"].exists)
        XCTAssertTrue(app.buttons["meeting.new"].exists)
        XCTAssertFalse(app.buttons["meeting.start"].exists)
    }

    func testLibraryFirstSearchOpensWholeMeetingAndBackPreservesSearch() {
        let app = XCUIApplication()
        app.launchArguments = ["--meeting-ui-testing", "--reset-ui-data", "--seed-meeting-library", "--compact-window",
                               "-AppleLanguages", "(en)", "-mumla.interfaceStyle", "native"]
        app.launch()
        let search = app.textFields["meeting.library.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["meeting.start"].exists)
        search.click(); search.typeText("design anna")
        let row = app.buttons["meeting.library.open.00000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["meeting.library.open.00000000-0000-0000-0000-000000000001"].exists)
        capture("meetings-library-search", app)
        row.click()
        XCTAssertTrue(app.buttons["meeting.copy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "meeting.export").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "meeting.passage.example-2").firstMatch.exists)
        let passageSearch = app.textFields["meeting.search"]
        passageSearch.click(); passageSearch.typeText("Vi börjar")
        XCTAssertTrue(app.buttons["meeting.showAll"].waitForExistence(timeout: 3))
        app.buttons["meeting.copy"].click()
        XCTAssertTrue(app.buttons["meeting.copy"].label.contains("Copied"))
        let copied = NSPasteboard.general.string(forType: .string) ?? ""
        XCTAssertTrue(copied.contains("[00:12] Me: Vi börjar"))
        XCTAssertTrue(copied.contains("[00:21] Anna: Bra."))
        XCTAssertTrue(copied.contains("[00:31] Me: Då testar"))
        app.buttons["meeting.showAll"].click()
        XCTAssertEqual(passageSearch.value as? String, "")
        app.buttons["meeting.library"].click()
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        XCTAssertEqual(search.value as? String, "design anna")
        search.click(); search.typeKey("a", modifierFlags: .command); search.typeText("no such meeting")
        XCTAssertTrue(app.staticTexts["No matching meetings"].waitForExistence(timeout: 3))
        app.buttons["Clear search"].firstMatch.click()
        XCTAssertTrue(row.waitForExistence(timeout: 3))
    }

    func testBrowsingSavedMeetingsDoesNotStopRecording() {
        let app = launch(compact: true)
        app.buttons["meeting.new"].click(); app.buttons["meeting.start"].click()
        XCTAssertTrue(app.buttons["meeting.stop"].waitForExistence(timeout: 3))
        app.buttons["meeting.library"].click()
        let current = app.buttons["meeting.current"]
        XCTAssertTrue(current.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["meeting.new"].isEnabled)
        current.click()
        XCTAssertTrue(app.buttons["meeting.stop"].waitForExistence(timeout: 3))
        app.buttons["meeting.stop"].click()
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
}
