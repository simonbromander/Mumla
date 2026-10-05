import XCTest
@testable import MumlaCore

final class KeyboardSessionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_198_000)
    private func active(_ phase: KeyboardSessionPhase = .ready) -> KeyboardSessionSnapshot {
        var snapshot = KeyboardSessionSnapshot()
        snapshot.sessionID = UUID(); snapshot.phase = phase; snapshot.heartbeat = now
        snapshot.expiresAt = now.addingTimeInterval(900)
        return snapshot
    }

    func testSessionNeedsFreshHeartbeatAndUnexpiredIdentity() {
        var snapshot = active()
        XCTAssertTrue(snapshot.isAlive(at: now))
        XCTAssertFalse(snapshot.isAlive(at: now.addingTimeInterval(5)))
        XCTAssertFalse(snapshot.isAlive(at: now.addingTimeInterval(-2)))
        snapshot.expiresAt = now
        XCTAssertFalse(snapshot.isAlive(at: now))
        snapshot = active(); snapshot.sessionID = nil
        XCTAssertFalse(snapshot.isAlive(at: now))
        snapshot = active(.inactive)
        XCTAssertFalse(snapshot.isAlive(at: now))
        snapshot = active(); snapshot.version = 99
        XCTAssertFalse(snapshot.isAlive(at: now))
    }

    func testCommandsRejectWrongSessionAgeVersionAndReplay() throws {
        var snapshot = active()
        var command = KeyboardSessionCommand(sessionID: try XCTUnwrap(snapshot.sessionID), action: .start, createdAt: now)
        XCTAssertTrue(snapshot.accepts(command, at: now))
        command.sessionID = UUID(); XCTAssertFalse(snapshot.accepts(command, at: now))
        command.sessionID = try XCTUnwrap(snapshot.sessionID)
        command.createdAt = now.addingTimeInterval(-5); XCTAssertFalse(snapshot.accepts(command, at: now))
        command.createdAt = now.addingTimeInterval(2); XCTAssertFalse(snapshot.accepts(command, at: now))
        command.createdAt = now; command.version = 99; XCTAssertFalse(snapshot.accepts(command, at: now))
        command.version = 1; snapshot.acknowledgedCommandID = command.id
        XCTAssertFalse(snapshot.accepts(command, at: now))
    }

    func testStopAndCancelCannotTargetAnotherRecording() throws {
        var snapshot = active(.recording); snapshot.requestID = UUID()
        for action in [KeyboardSessionCommand.Action.stop, .cancel] {
            var command = KeyboardSessionCommand(sessionID: try XCTUnwrap(snapshot.sessionID), action: action, createdAt: now)
            XCTAssertFalse(snapshot.accepts(command, at: now))
            command.requestID = snapshot.requestID
            XCTAssertTrue(snapshot.accepts(command, at: now))
        }
        let start = KeyboardSessionCommand(sessionID: try XCTUnwrap(snapshot.sessionID), action: .start, createdAt: now)
        XCTAssertFalse(snapshot.accepts(start, at: now))
        snapshot.requestID = nil
        let invalidStop = KeyboardSessionCommand(sessionID: try XCTUnwrap(snapshot.sessionID), action: .stop, createdAt: now)
        XCTAssertFalse(snapshot.accepts(invalidStop, at: now))
    }

    func testRetryAndConsumeAreBoundToFailedClipAndResult() throws {
        var snapshot = active(.failed)
        var retry = KeyboardSessionCommand(sessionID: try XCTUnwrap(snapshot.sessionID), action: .retry, createdAt: now)
        XCTAssertFalse(snapshot.accepts(retry, at: now))
        snapshot.requestID = UUID()
        snapshot.canRetry = true
        XCTAssertFalse(snapshot.accepts(retry, at: now))
        retry.requestID = UUID()
        XCTAssertFalse(snapshot.accepts(retry, at: now))
        retry.requestID = snapshot.requestID
        XCTAssertTrue(snapshot.accepts(retry, at: now))
        snapshot.phase = .result; snapshot.resultID = UUID()
        var consume = KeyboardSessionCommand(sessionID: try XCTUnwrap(snapshot.sessionID), action: .consume, createdAt: now, resultID: UUID())
        XCTAssertFalse(snapshot.accepts(consume, at: now))
        consume.resultID = snapshot.resultID
        XCTAssertTrue(snapshot.accepts(consume, at: now))
        snapshot.resultID = nil; consume.resultID = nil
        XCTAssertFalse(snapshot.accepts(consume, at: now))
    }

    func testAutoInsertionRequiresVisibleMatchingDocumentAndRequest() throws {
        var snapshot = active(.result); snapshot.resultID = UUID(); snapshot.requestID = UUID()
        let document = UUID()
        let result = KeyboardSessionResult(id: try XCTUnwrap(snapshot.resultID), sessionID: try XCTUnwrap(snapshot.sessionID),
                                           requestID: try XCTUnwrap(snapshot.requestID), documentID: document, text: "Hej!", createdAt: now)
        XCTAssertTrue(result.shouldAutoInsert(snapshot: snapshot, requestID: snapshot.requestID, documentID: document, visible: true, at: now))
        XCTAssertFalse(result.shouldAutoInsert(snapshot: snapshot, requestID: snapshot.requestID, documentID: UUID(), visible: true, at: now))
        XCTAssertFalse(result.shouldAutoInsert(snapshot: snapshot, requestID: nil, documentID: document, visible: true, at: now))
        XCTAssertFalse(result.shouldAutoInsert(snapshot: snapshot, requestID: snapshot.requestID, documentID: document, visible: false, at: now))
        snapshot.heartbeat = now.addingTimeInterval(91)
        XCTAssertFalse(result.shouldAutoInsert(snapshot: snapshot, requestID: snapshot.requestID, documentID: document, visible: true, at: now.addingTimeInterval(91)))
    }

    func testSharedStoreRoundTripsAndClaimsOnlyOnceAcrossInstances() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KeyboardSessionStore(directory: directory)
        XCTAssertEqual(try store.snapshot().phase, .inactive)
        XCTAssertNil(try store.command()); XCTAssertNil(try store.result())
        let snapshot = active()
        try store.write(snapshot)
        XCTAssertEqual(try store.snapshot(), snapshot)
        let command = KeyboardSessionCommand(sessionID: try XCTUnwrap(snapshot.sessionID), action: .start, createdAt: now)
        try store.send(command); XCTAssertEqual(try store.command(), command)
        let result = KeyboardSessionResult(id: UUID(), sessionID: try XCTUnwrap(snapshot.sessionID), requestID: command.id,
                                           documentID: UUID(), text: "Åäö stannar här.", createdAt: now)
        try store.publish(result); XCTAssertEqual(try store.result(), result)
        XCTAssertTrue(try store.claim(result.id))
        XCTAssertFalse(try KeyboardSessionStore(directory: directory).claim(result.id))
        XCTAssertTrue(store.hasClaim(result.id))
        try store.clearResult(); XCTAssertNil(try store.result())
    }

    func testCorruptUnknownAndOversizedPacketsFailClosed() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let store = KeyboardSessionStore(directory: base)
        var snapshot = active(); snapshot.version = 99
        try store.write(snapshot); XCTAssertThrowsError(try store.snapshot())
        try Data("broken".utf8).write(to: store.directory.appendingPathComponent("state.json"))
        XCTAssertThrowsError(try store.snapshot())
        try Data(repeating: 0, count: 128 * 1024 + 1).write(to: store.directory.appendingPathComponent("state.json"))
        XCTAssertThrowsError(try store.snapshot())
        let result = KeyboardSessionResult(id: UUID(), sessionID: UUID(), requestID: UUID(), documentID: nil,
                                           text: String(repeating: "a", count: 128 * 1024))
        XCTAssertThrowsError(try store.publish(result))
    }

    func testKeyboardHasSwedishLettersAndASCIINumbers() {
        let letters = MumlaKeyboardLayout.letters.rows.flatMap { $0 }
        for character in ["å", "ä", "ö", "a", "z"] { XCTAssertTrue(letters.contains(character)) }
        XCTAssertEqual(Set(letters).count, 29)
        XCTAssertEqual(MumlaKeyboardLayout.numbers.rows[0].joined(), "1234567890")
        XCTAssertTrue(MumlaKeyboardLayout.symbols.rows.flatMap { $0 }.contains("€"))
    }

    func testShiftSingleTapDoubleTapAndTyping() {
        var shift = MumlaKeyboardShift()
        shift.tap(at: 1); XCTAssertTrue(shift.uppercase); XCTAssertFalse(shift.locked)
        shift.didType(); XCTAssertFalse(shift.uppercase)
        shift.tap(at: 2); shift.tap(at: 2.2)
        XCTAssertTrue(shift.locked); shift.didType(); XCTAssertTrue(shift.uppercase)
        shift.tap(at: 3); XCTAssertFalse(shift.uppercase); XCTAssertFalse(shift.locked)
        shift.tap(at: 4); shift.tap(at: 5); XCTAssertFalse(shift.uppercase)
        shift.reset(); XCTAssertEqual(shift, MumlaKeyboardShift())
    }
}
