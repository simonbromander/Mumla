import Foundation
import XCTest
@testable import MumlaCore

final class DictationHistoryStoreTests: XCTestCase {
    func testAppendKeepsNewestRecordsWithinLimit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MumlaHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = DictationHistoryStore(directory: directory, limit: 2)

        try store.append(DictationRecord(text: "first", language: .swedish))
        try store.append(DictationRecord(text: "second", language: .english))
        let records = try store.append(DictationRecord(text: "third", language: .swedish))

        XCTAssertEqual(records.map(\.text), ["third", "second"])
        XCTAssertEqual(try store.load().map(\.text), ["third", "second"])

        try? FileManager.default.removeItem(at: directory)
    }

    func testDictionaryStoreAddsReplacesAndDeletesEntries() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MumlaDictionaryStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = DictionaryStore(directory: directory)

        var entries = try store.add(original: "Kubernetis", replacement: "Kubernetes")
        XCTAssertEqual(entries.map(\.replacement), ["Kubernetes"])

        entries = try store.add(original: "kubernetis", replacement: "Kubernetes")
        XCTAssertEqual(entries.count, 1)

        entries = try store.delete(id: entries[0].id)
        XCTAssertTrue(entries.isEmpty)
        XCTAssertTrue(try store.load().isEmpty)

        try? FileManager.default.removeItem(at: directory)
    }
}
