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
}
