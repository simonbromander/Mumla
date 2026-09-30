import Foundation
import XCTest
@testable import MumlaMac

final class MacStorageTests: XCTestCase {
    func testDirectBuildReusesExistingTestFlightDataWithoutMovingIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appendingPathComponent("direct")
        let previous = root.appendingPathComponent("sandbox")
        try FileManager.default.createDirectory(at: previous, withIntermediateDirectories: true)
        let history = previous.appendingPathComponent("history.json")
        try Data("[]".utf8).write(to: history)
        XCTAssertEqual(MacStorageDirectory.preferredDirectory(current: current, previous: previous), previous)
        XCTAssertTrue(FileManager.default.fileExists(atPath: history.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: current.path))
    }

    func testExistingDirectDataTakesPrecedenceAndFreshInstallUsesDirectDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let current = root.appendingPathComponent("direct")
        let previous = root.appendingPathComponent("sandbox")
        XCTAssertEqual(MacStorageDirectory.preferredDirectory(current: current, previous: previous), current)
        for directory in [current, previous] {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent("Models"), withIntermediateDirectories: true)
        }
        XCTAssertEqual(MacStorageDirectory.preferredDirectory(current: current, previous: previous), current)
    }
}
