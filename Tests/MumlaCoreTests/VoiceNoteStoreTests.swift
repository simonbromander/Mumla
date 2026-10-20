import Foundation
import XCTest
@testable import MumlaCore

final class VoiceNoteStoreTests: XCTestCase {
    private func fixture() throws -> (URL, URL, VoiceNoteStore) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceNoteTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let audio = directory.appendingPathComponent("input.wav")
        try Data(repeating: 1, count: 100).write(to: audio)
        return (directory, audio, VoiceNoteStore(directory: directory.appendingPathComponent("notes")))
    }

    func testRecordingAndTranscriptSurviveRelaunchWithoutSourceFile() throws {
        let (directory, audio, store) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = try store.saveRecording(from: audio, duration: 2, language: "sv")
        XCTAssertNil(try store.load().first?.transcript)
        XCTAssertNil(note.deliveryID)
        try FileManager.default.removeItem(at: audio)
        try store.setTranscript("Vi ses klockan två.", for: note.id)
        let restored = try VoiceNoteStore(directory: store.directory).load()
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].transcript, "Vi ses klockan två.")
        XCTAssertFalse(restored[0].delivered)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioURL(for: note.id).path))
    }

    func testReceiveCopiesTemporaryFileAndDuplicateDeliveryIsIdempotent() throws {
        let (directory, audio, watch) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = try watch.saveRecording(from: audio, duration: 1, language: "en")
        try watch.setTranscript("A new thought.", for: note.id)
        let payload = try XCTUnwrap(watch.load().first).transferData()
        let deliveryID = try XCTUnwrap(watch.load().first?.deliveryID)
        let phone = VoiceNoteStore(directory: directory.appendingPathComponent("phone"))
        let received = try phone.receive(payload, audio: audio, deliveryID: deliveryID)
        _ = try phone.receive(payload, audio: audio, deliveryID: deliveryID)
        try FileManager.default.removeItem(at: audio)
        XCTAssertEqual(try phone.load().count, 1)
        XCTAssertEqual(received.transcript, "A new thought.")
        XCTAssertTrue(FileManager.default.fileExists(atPath: phone.audioURL(for: note.id).path))
        XCTAssertFalse(try XCTUnwrap(watch.load().first).delivered)
        try watch.acknowledge(id: note.id, deliveryID: try XCTUnwrap(received.deliveryID))
        XCTAssertTrue(try XCTUnwrap(watch.load().first).delivered)
    }

    func testCorruptTransferCannotCommitOrAcknowledge() throws {
        let (directory, audio, watch) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = try watch.saveRecording(from: audio, duration: 1, language: "sv")
        try watch.setTranscript("Hej.", for: note.id)
        let complete = try XCTUnwrap(watch.load().first)
        let phone = VoiceNoteStore(directory: directory.appendingPathComponent("phone"))
        try Data(repeating: 2, count: 100).write(to: audio)
        XCTAssertThrowsError(try phone.receive(complete.transferData(), audio: audio, deliveryID: try XCTUnwrap(complete.deliveryID)))
        XCTAssertEqual(try phone.load().count, 0)
        try watch.acknowledge(id: note.id, deliveryID: "wrong")
        XCTAssertFalse(try XCTUnwrap(watch.load().first).delivered)
        XCTAssertTrue(FileManager.default.fileExists(atPath: watch.audioURL(for: note.id).path))
    }

    func testDeletedNoteDoesNotReturnAfterRedeliveryOrRelaunch() throws {
        let (directory, audio, store) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = try store.saveRecording(from: audio, duration: 1, language: "sv")
        try store.setTranscript("Radera mig.", for: note.id)
        let complete = try XCTUnwrap(store.load().first)
        try store.delete(id: note.id)
        let restored = VoiceNoteStore(directory: store.directory)
        XCTAssertTrue(restored.isDeleted(note.id))
        XCTAssertThrowsError(try restored.receive(complete.transferData(), audio: audio, deliveryID: try XCTUnwrap(complete.deliveryID)))
        XCTAssertTrue(try restored.load().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: restored.audioURL(for: note.id).path))
    }

    func testConflictingIdentityDoesNotOverwriteRecording() throws {
        let (directory, audio, store) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = try store.saveRecording(from: audio, duration: 1, language: "sv")
        XCTAssertThrowsError(try store.saveRecording(from: audio, id: note.id, createdAt: note.createdAt,
                                                     duration: 2, language: "en"))
        XCTAssertEqual(try store.load().first, note)
    }

    func testInvalidPayloadsAndEmptyTranscriptsAreRejected() throws {
        let (directory, audio, store) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        for duration in [0.0, -.infinity, .nan, 62] {
            XCTAssertThrowsError(try store.saveRecording(from: audio, duration: duration, language: "sv"))
        }
        XCTAssertThrowsError(try store.saveRecording(from: audio, duration: 1, language: "../../unknown"))
        let note = try store.saveRecording(from: audio, duration: 1, language: "sv")
        XCTAssertThrowsError(try store.setTranscript("   ", for: note.id))
        XCTAssertThrowsError(try store.setTranscript(String(repeating: "x", count: 24_001), for: note.id))
        XCTAssertThrowsError(try store.receive(Data(repeating: 1, count: 32_001), audio: audio, deliveryID: "wrong"))
        XCTAssertNil(try store.load().first?.transcript)
    }

    func testInterruptedAudioCommitDoesNotHideOtherNotes() throws {
        let (directory, audio, store) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try store.saveRecording(from: audio, duration: 1, language: "sv")
        let incomplete = store.directory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: true)
        try Data().write(to: incomplete.appendingPathComponent("audio.wav"))
        XCTAssertEqual(try store.load().count, 1)
    }

    func testIncorrectDeliveryIdentityCannotCommit() throws {
        let (directory, audio, watch) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = try watch.saveRecording(from: audio, duration: 1, language: "sv")
        try watch.setTranscript("Hej.", for: note.id)
        let phone = VoiceNoteStore(directory: directory.appendingPathComponent("phone"))
        let payload = try XCTUnwrap(watch.load().first).transferData()
        XCTAssertThrowsError(try phone.receive(payload, audio: audio, deliveryID: "wrong"))
        XCTAssertTrue(try phone.load().isEmpty)
    }

    func testOversizedAudioAndEscapedPayloadAreRejected() throws {
        let (directory, audio, store) = try fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = try store.saveRecording(from: audio, duration: 1, language: "sv")
        try store.setTranscript(String(repeating: "\"", count: 20_000), for: note.id)
        XCTAssertThrowsError(try XCTUnwrap(store.load().first).transferData())
        try Data(repeating: 1, count: 2_000_001).write(to: audio)
        XCTAssertThrowsError(try store.saveRecording(from: audio, duration: 1, language: "sv"))
        XCTAssertEqual(try store.load().count, 1)
    }
}
