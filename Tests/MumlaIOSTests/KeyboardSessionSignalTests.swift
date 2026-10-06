import MumlaCore
import XCTest

@MainActor
final class KeyboardSessionSignalTests: XCTestCase {
    func testCommandNotificationOnlyFollowsAReadableAtomicPacket() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let store = KeyboardSessionStore(directory: base)
        let command = KeyboardSessionCommand(sessionID: UUID(), action: .start)
        let received = expectation(description: "Command available when the hint arrives")
        received.assertForOverFulfill = false
        var signal = KeyboardSessionSignal(.command) {
            XCTAssertEqual(try? store.command(), command)
            received.fulfill()
        }
        XCTAssertNotNil(signal)
        try store.send(command)
        await fulfillment(of: [received], timeout: 2)
        signal = nil
    }

    func testStateNotificationOnlyFollowsAReadableSnapshot() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let store = KeyboardSessionStore(directory: base)
        var state = KeyboardSessionSnapshot()
        state.sessionID = UUID(); state.phase = .ready; state.heartbeat = Date()
        state.expiresAt = Date().addingTimeInterval(900)
        let expected = state
        let received = expectation(description: "Ready state available")
        received.assertForOverFulfill = false
        var signal = KeyboardSessionSignal(.state) {
            XCTAssertEqual(try? store.snapshot(), expected)
            received.fulfill()
        }
        XCTAssertNotNil(signal)
        try store.write(state)
        await fulfillment(of: [received], timeout: 2)
        signal = nil
    }

    func testHeartbeatRemainsReadableWithoutAStateNotification() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let store = KeyboardSessionStore(directory: base)
        let received = expectation(description: "No redundant heartbeat hint")
        received.isInverted = true
        var signal = KeyboardSessionSignal(.state) { received.fulfill() }
        XCTAssertNotNil(signal)
        let snapshot = KeyboardSessionSnapshot()
        try store.write(snapshot, notify: false)
        XCTAssertEqual(try store.snapshot(), snapshot)
        await fulfillment(of: [received], timeout: 0.2)
        signal = nil
    }

    func testReleasingObserverStopsDelivery() async {
        let received = expectation(description: "Released observer stays silent")
        received.isInverted = true
        var signal = KeyboardSessionSignal(.command) { received.fulfill() }
        XCTAssertNotNil(signal)
        signal = nil
        KeyboardSessionSignal.post(.command)
        await fulfillment(of: [received], timeout: 0.2)
    }

    func testNotificationDoesNotAuthorizeAnInvalidCommand() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let store = KeyboardSessionStore(directory: base)
        var state = KeyboardSessionSnapshot()
        state.sessionID = UUID(); state.phase = .ready; state.heartbeat = Date()
        state.expiresAt = Date().addingTimeInterval(900)
        let active = state
        let received = expectation(description: "Wrong-session command rejected")
        received.assertForOverFulfill = false
        var signal = KeyboardSessionSignal(.command) {
            if let command = try? store.command() { XCTAssertFalse(active.accepts(command)) }
            else { XCTFail("Expected a readable command") }
            received.fulfill()
        }
        XCTAssertNotNil(signal)
        try store.send(KeyboardSessionCommand(sessionID: UUID(), action: .start))
        await fulfillment(of: [received], timeout: 2)
        signal = nil
    }
}
