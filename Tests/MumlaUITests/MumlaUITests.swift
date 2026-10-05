import XCTest
import UIKit

@MainActor
final class MumlaUITests: XCTestCase {
    func testAppearanceSelectionPersistsAndSharesWithSheets() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "--seed-transcript", "-AppleLanguages", "(sv)"]
        app.launch()
        XCTAssertTrue(app.buttons["Inställningar"].waitForExistence(timeout: 10))
        app.buttons["Inställningar"].tap()
        let light = app.buttons["appearance.light"]
        XCTAssertTrue(light.waitForExistence(timeout: 3))
        light.tap()
        XCTAssertTrue(light.isSelected)
        XCTAssertFalse(app.buttons["appearance.dark"].isSelected)
        capture("21-light-settings", app: app)
        app.buttons["Klart"].tap()
        capture("22-light-recorder", app: app)
        app.buttons["Historik"].tap()
        capture("23-light-history", app: app)
        app.buttons["Ordlista"].tap()
        capture("24-light-dictionary", app: app)
        app.terminate()
        app.launch()
        app.buttons["Inställningar"].tap()
        XCTAssertTrue(app.buttons["appearance.light"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["appearance.light"].isSelected)
        app.buttons["appearance.dark"].tap()
        XCTAssertTrue(app.buttons["appearance.dark"].isSelected)
        XCTAssertFalse(app.buttons["appearance.light"].isSelected)
        capture("25-dark-settings", app: app)
        app.buttons["Klart"].tap()
        capture("26-dark-recorder", app: app)
        app.buttons["Inställningar"].tap()
        app.buttons["appearance.system"].tap()
        XCTAssertTrue(app.buttons["appearance.system"].isSelected)
    }

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
        let preview = app.staticTexts["latestTranscript.preview"]
        let copy = app.buttons["latestTranscript.copy"]
        let share = app.buttons["latestTranscript.share"]
        XCTAssertTrue(copy.waitForExistence(timeout: 10))
        XCTAssertEqual(preview.label, "Vi bestämde att…")
        XCTAssertTrue(copy.isHittable)
        XCTAssertTrue(share.isHittable)
        preview.tap()
        XCTAssertFalse(app.textViews["transcript.text"].exists)
        copy.tap()
        XCTAssertEqual(copy.value as? String, "Kopierat")
        capture("06-latest-transcript", app: app)
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
        let shared = app.otherElements["LP.CaptionBar.BottomCaption"].label
        XCTAssertTrue(shared.hasPrefix("Vi bestämde att börja med den svenska versionen"))
        XCTAssertTrue(shared.hasSuffix("planera nästa steg tillsammans."))
        let systemCopy = app.cells.matching(NSPredicate(format: "label IN %@", ["Copy", "Kopiera"])).firstMatch
        XCTAssertTrue(systemCopy.waitForExistence(timeout: 5))
        capture("07-share-transcript", app: app)
        systemCopy.tap()
        app.buttons["showLatestTranscript"].tap()
        XCTAssertTrue(app.textViews["transcript.text"].waitForExistence(timeout: 3))
        capture("16-transcript-detail", app: app)
    }

    func testLatestTranscriptLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "--seed-transcript", "-AppleLanguages", "(en)", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["showLatestTranscript"].waitForExistence(timeout: 10))
        let copy = app.buttons["latestTranscript.copy"]
        let share = app.buttons["latestTranscript.share"]
        XCTAssertTrue(copy.waitForExistence(timeout: 3))
        XCTAssertTrue(copy.isHittable)
        XCTAssertTrue(share.isHittable)
        XCTAssertFalse(copy.frame.intersects(share.frame))
        let preview = app.staticTexts["latestTranscript.preview"]
        XCTAssertLessThanOrEqual(preview.frame.height, 44)
        XCTAssertLessThanOrEqual(preview.frame.maxX, copy.frame.minX)
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
        let preview = app.textViews["transcript.text"]
        openCorrection(in: preview, app: app)
        XCTAssertFalse(app.buttons["correction.save"].isEnabled)
        app.textFields["correction.replacement"].typeText("Kubernetes")
        capture("12-correct-word", app: app)
        app.buttons["correction.save"].tap()
        let corrected = "Kubernetes fungerar. Vi använder Kubernetis varje dag."
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        XCTAssertEqual(preview.value as? String, corrected)
        app.buttons["transcript.copy"].tap()
        app.buttons["transcript.share"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.otherElements["LP.CaptionBar.BottomCaption"].label, corrected)
        app.cells.matching(NSPredicate(format: "label IN %@", ["Copy", "Kopiera"])).firstMatch.tap()
        app.buttons["Klart"].tap()
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
        let preview = app.textViews["transcript.text"]
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

    func testRecorderIsFixedInPortraitAndLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "--seed-transcript", "-AppleLanguages", "(sv)"]
        app.launch()
        let preview = app.staticTexts["latestTranscript.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        let before = preview.frame
        XCTAssertEqual(app.scrollViews.count, 0)
        app.swipeUp()
        XCTAssertEqual(preview.frame.minY, before.minY, accuracy: 1)
        XCTAssertTrue(app.buttons["latestTranscript.copy"].isHittable)
        XCTAssertTrue(app.buttons["latestTranscript.share"].isHittable)
        XCTAssertLessThan(preview.frame.maxY, app.buttons["tab.dictate"].frame.minY)
        capture("17-fixed-recorder", app: app)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            defer { XCUIDevice.shared.orientation = .portrait }
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertTrue(app.buttons["latestTranscript.copy"].waitForExistence(timeout: 3))
            XCTAssertEqual(app.scrollViews.count, 0)
            XCTAssertTrue(app.buttons["latestTranscript.copy"].isHittable)
            XCTAssertTrue(app.buttons["latestTranscript.share"].isHittable)
            capture("18-landscape-recorder", app: app)
        }
    }

    func testAboutCreditsAndBundledNotice() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-data", "-AppleLanguages", "(en)"]
        app.launch()
        app.buttons["Settings"].tap()
        let about = app.buttons["settings.about"]
        for _ in 0..<6 {
            if about.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(about.isHittable)
        about.tap()
        XCTAssertTrue(app.staticTexts["Pianissimo-sv"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Klang AI AB"].exists)
        capture("19-about", app: app)
        let notice = app.buttons["about.notice.Pianissimo-attribution"]
        for _ in 0..<12 {
            if notice.isHittable { break }
            app.scrollViews["about.content"].swipeUp()
        }
        XCTAssertTrue(notice.isHittable)
        notice.tap()
        let text = app.staticTexts["about.notice.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 3))
        XCTAssertTrue(text.label.contains("Klang Pianissimo"))
        XCTAssertTrue(text.label.contains("Creative Commons Attribution 4.0"))
        XCTAssertTrue(text.label.contains("NVIDIA Parakeet"))
        capture("20-bundled-notice", app: app)
    }

    private func openCorrection(in text: XCUIElement, app: XCUIApplication, title: String = "Rätta ord") {
        XCTAssertTrue(text.waitForExistence(timeout: 3))
        text.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 12)).doubleTap()
        let action = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        action.tap()
        XCTAssertTrue(app.textFields["correction.replacement"].waitForExistence(timeout: 3))
        let keyboardIntro = app.otherElements["UIContinuousPathIntroductionView"].buttons["Continue"]
        if keyboardIntro.exists { keyboardIntro.tap() }
    }

    private func assertLatchedKey(_ index: Int, keys: [XCUIElement]) {
        for (position, key) in keys.enumerated() {
            XCTAssertEqual(key.isSelected, position == index)
        }
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
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
