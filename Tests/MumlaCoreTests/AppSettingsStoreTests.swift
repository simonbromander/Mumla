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
            soundFeedbackEnabled: false,
            launchAtLogin: true,
            onboardingCompleted: true
        )

        try store.save(settings)

        XCTAssertEqual(try store.load(), settings)

        try? FileManager.default.removeItem(at: directory)
    }
}
