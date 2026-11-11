import Foundation
import MumlaCore
import MumlaUI
import SwiftUI
import XCTest

@MainActor
final class DestinationHostedTests: XCTestCase {
    func testAppOnlyKeychainSaveUpdateReadDeleteAndSettingsContainNoToken() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var parts = URLComponents(); parts.scheme = "https"; parts.host = "receiver.invalid"
        let url = parts.url!, store = DestinationTokenStore(service: "app.mumla.destination.tests." + UUID().uuidString)
        defer { try? store.delete(for: url) }
        XCTAssertNil(try store.read(for: url))
        let first = UUID().uuidString, second = UUID().uuidString
        try store.save(first, for: url); XCTAssertEqual(try store.read(for: url), first)
        try store.save(second, for: url); XCTAssertEqual(try store.read(for: url), second)
        let settings = AppSettingsStore(directory: directory)
        try settings.setTranscriptDestination(TranscriptDestination(name: "Test destination", url: url))
        let json = String(decoding: try Data(contentsOf: directory.appendingPathComponent("settings.json")), as: UTF8.self)
        XCTAssertFalse(json.contains(first)); XCTAssertFalse(json.contains(second)); XCTAssertFalse(json.lowercased().contains("token"))
        try store.delete(for: url); XCTAssertNil(try store.read(for: url))
        try store.delete(for: url)
    }

    func testNativeTextOnlySendAndPersistedReceipt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = AppSettingsStore(directory: directory), history = DictationHistoryStore(directory: directory)
        let controller = TranscriptDestinationController.uiFixture(settings: settings, configured: true)
        let record = DictationRecord(text: "A complete native test transcript.\nSecond line.", language: .english, durationMilliseconds: 2500)
        try history.append(record)
        let result = await controller.send(try record.outgoingTranscript(version: "1"), id: record.id,
                                           approvedDestination: try XCTUnwrap(controller.destination)) { date in
            _ = try history.markSent(recordID: record.id, at: date)
        }
        XCTAssertEqual(result, .sent(statusCode: 201)); XCTAssertNotNil(try history.load().first?.sentAt)
        XCTAssertEqual(try history.load().first?.text, record.text)
    }
}
