import Foundation
import XCTest
@testable import MumlaCore

final class AppSettingsStoreTests: XCTestCase {
    func testMissingSettingsReturnsDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MumlaSettingsStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = AppSettingsStore(directory: directory)

        XCTAssertEqual(try store.load(), .default)

        try? FileManager.default.removeItem(at: directory)
    }

    func testSaveAndLoadRoundTripsSettings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MumlaSettingsStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = AppSettingsStore(directory: directory)
        let settings = AppSettings(
            languageMode: .swedish,
            lastLanguage: .english,
            soundFeedbackEnabled: false,
            launchAtLogin: true,
            onboardingCompleted: true,
            triggerKey: .rightOption
        )

        try store.save(settings)

        XCTAssertEqual(try AppSettingsStore(directory: directory).load(), settings)

        try? FileManager.default.removeItem(at: directory)
    }

    func testDecodesLegacySettingsWithDefaultsForNewFields() throws {
        let data = Data("""
        {
          "languageMode": "auto",
          "soundFeedbackEnabled": true,
          "launchAtLogin": false,
          "onboardingCompleted": true
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.lastLanguage, .swedish)
        XCTAssertTrue(settings.onboardingCompleted)
        XCTAssertEqual(settings.triggerKey, .control)
    }
}
