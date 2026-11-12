import Foundation
import XCTest
@testable import MumlaCore

final class MeetingStoreTests: XCTestCase {
    private func withStore(_ body: (MeetingStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(MeetingStore(directory: directory))
    }
    private func create(_ store: MeetingStore) throws -> MeetingRecord {
        try store.create(MeetingRecord(title: "Project review", sourceName: "Test call", microphoneOnly: false))
    }
    private func chunk(_ store: MeetingStore, _ id: UUID, start: Double = 0) throws -> MeetingAudioChunk {
        let chunk = MeetingAudioChunk(id: "microphone-" + UUID().uuidString, track: .microphone, start: start, duration: 3)
        try Data([1, 2, 3]).write(to: store.audioURL(chunk, meetingID: id))
        try store.appendChunk(chunk, meetingID: id)
        return chunk
    }

    func testInterruptionReasonIsOptionalForOldHistoryAndPersistsWithoutAudioOrText() throws {
        var record = MeetingRecord(title: "Synthetic", sourceName: "Synthetic", microphoneOnly: true)
        record.capture = .interrupted; record.interruptionReason = .captureFailure
        let encoded = try JSONEncoder().encode(record)
        XCTAssertEqual(try JSONDecoder().decode(MeetingRecord.self, from: encoded).interruptionReason, .captureFailure)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        old.removeValue(forKey: "interruptionReason")
        let decoded = try JSONDecoder().decode(MeetingRecord.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(decoded.interruptionReason)
        XCTAssertEqual(decoded.capture, .interrupted)
    }

    func testChunksCannotEscapeMeetingDirectory() throws {
        try withStore { store in
            let record = try create(store)
            for id in ["../private", "/tmp/data", "a.wav", "", "å"] {
                XCTAssertThrowsError(try store.audioURL(.init(id: id, track: .system, start: 0, duration: 3), meetingID: record.id))
            }
            XCTAssertFalse(MeetingAudioChunk(id: "valid", track: .system, start: .nan, duration: 3).isValid)
            XCTAssertFalse(MeetingAudioChunk(id: "valid", track: .system, start: 0, duration: .infinity).isValid)
        }
    }

    func testAppendRequiresSavedAudioAndPreservesPauseTimeline() throws {
        try withStore { store in
            let record = try create(store)
            XCTAssertThrowsError(try store.appendChunk(.init(id: "missing", track: .system, start: 0, duration: 3), meetingID: record.id))
            let first = try chunk(store, record.id)
            _ = try chunk(store, record.id, start: 25)
            let saved = try store.load(record.id)
            XCTAssertEqual(saved.duration, 28)
            XCTAssertEqual(saved.chunks.count, 2)
            XCTAssertThrowsError(try store.appendChunk(first, meetingID: record.id))
        }
    }

    func testTranscriptRetryIsIdempotentAndDoesNotOverwriteCorrections() throws {
        try withStore { store in
            let record = try create(store); let audio = try chunk(store, record.id)
            let segment = MeetingSegment(id: audio.id + "-0", chunkID: audio.id, track: .microphone,
                start: 0, end: 2, speaker: "microphone", text: "Kubernetis")
            try store.commitTranscript([segment], chunkID: audio.id, meetingID: record.id)
            try store.correct(segment.id, meetingID: record.id, expectedText: "Kubernetis", text: "Kubernetes")
            try store.commitTranscript([segment], chunkID: audio.id, meetingID: record.id)
            let saved = try store.load(record.id)
            XCTAssertEqual(saved.segments.count, 1); XCTAssertEqual(saved.segments[0].text, "Kubernetes")
            XCTAssertEqual(saved.segments[0].originalText, "Kubernetis")
            XCTAssertThrowsError(try store.correct(segment.id, meetingID: record.id, expectedText: "old", text: "new"))
        }
    }

    func testCrashRecoveryFindsCommittedOrphanChunksAndDoesNotRestartRecording() throws {
        try withStore { store in
            let record = try create(store)
            let orphan = MeetingAudioChunk(id: "microphone-orphan", track: .microphone, start: 6, duration: 2)
            let url = try store.audioURL(orphan, meetingID: record.id)
            try Data([1, 2]).write(to: url)
            try JSONEncoder().encode(orphan).write(to: url.appendingPathExtension("json"))
            try store.recover(); try store.recover()
            let saved = try store.load(record.id)
            XCTAssertEqual(saved.capture, .interrupted); XCTAssertEqual(saved.processing, .pending)
            XCTAssertEqual(saved.chunks, [orphan])
        }
    }

    func testInterruptedProcessingBecomesRetryable() throws {
        try withStore { store in
            let record = try create(store)
            _ = try store.update(record.id) { $0.capture = .saved; $0.processing = .processing }
            try store.recover()
            XCTAssertEqual(try store.load(record.id).processing, .pending)
        }
    }

    func testDeletionRejectsLateWorkerCommitAndCannotBeResurrected() throws {
        try withStore { store in
            let record = try create(store); let audio = try chunk(store, record.id)
            try store.delete(record.id)
            XCTAssertThrowsError(try store.commitTranscript([], chunkID: audio.id, meetingID: record.id))
            XCTAssertThrowsError(try store.create(record))
            try store.recover(); XCTAssertTrue(try store.list().isEmpty)
        }
    }

    func testRetentionKeepsUntranscribedAudioButDeletesExpiredCompletedAudio() throws {
        try withStore { store in
            let pending = try create(store); let pendingAudio = try chunk(store, pending.id)
            _ = try store.update(pending.id) { $0.capture = .saved }
            let ready = try create(store); let readyAudio = try chunk(store, ready.id)
            _ = try store.update(ready.id) { $0.capture = .saved; $0.processing = .ready; $0.completedAt = Date(timeIntervalSince1970: 0) }
            try store.pruneAudio(now: Date(timeIntervalSince1970: 8 * 86400))
            XCTAssertTrue(FileManager.default.fileExists(atPath: try store.audioURL(pendingAudio, meetingID: pending.id).path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: try store.audioURL(readyAudio, meetingID: ready.id).path))
            XCTAssertTrue(try store.load(ready.id).audioDeleted)
            XCTAssertFalse(try store.load(pending.id).audioDeleted)
        }
    }

    func testExportsContainCorrectedTextAndNamesButNoInternalAudioMetadata() throws {
        var record = MeetingRecord(title: "Review", sourceName: "Private app", microphoneOnly: false)
        record.segments = [.init(id: "private-segment", chunkID: "private-file", track: .system,
            start: 61, end: 64, speaker: "system-0", text: "We agreed to meet tomorrow.")]
        record.speakerNames["system-0"] = "Anna"
        XCTAssertTrue(record.markdown.contains("[01:01] Anna:"))
        XCTAssertEqual(record.transcript(timestamps: false), "We agreed to meet tomorrow.")
        let exported = String(decoding: try record.exportJSON(), as: UTF8.self)
        XCTAssertTrue(exported.contains("Anna")); XCTAssertFalse(exported.contains("private-file"))
        XCTAssertFalse(exported.contains("Private app")); XCTAssertFalse(exported.contains("processedChunkIDs"))
        XCTAssertEqual(MeetingRecord.timestamp(7205), "2:00:05")
        XCTAssertEqual(MeetingRecord.timestamp(.infinity), "00:00")
    }

    func testAcousticBoundaryOverlapRemovesOnlyAlreadyCommittedPhrase() {
        let previous = [MeetingWord(text: "nästa", start: 2.0, end: 2.4),
            MeetingWord(text: "produkt.", start: 2.4, end: 2.8), MeetingWord(text: "Vi", start: 2.9, end: 3)]
        let incoming = [MeetingWord(text: "nästa", start: 2.0, end: 2.4),
            MeetingWord(text: "produkt.", start: 2.4, end: 2.8), MeetingWord(text: "Vi", start: 3, end: 3.2),
            MeetingWord(text: "ska", start: 3.3, end: 3.5)]
        XCTAssertEqual(MeetingTranscriptBoundary.committedPrefixCount(previous: previous, incoming: incoming, boundary: 3), 3)
        XCTAssertEqual(MeetingTranscriptBoundary.committedPrefixCount(previous: previous,
            incoming: [MeetingWord(text: "Vi", start: 3.3, end: 3.4), MeetingWord(text: "Vi", start: 3.5, end: 3.7)], boundary: 3), 0)
        let later = incoming.map { MeetingWord(text: $0.text, start: $0.start + 20, end: $0.end + 20) }
        XCTAssertEqual(MeetingTranscriptBoundary.committedPrefixCount(previous: previous, incoming: later, boundary: 3), 0)
        let repeatedPhrase = [MeetingWord(text: "ja", start: 3.05, end: 3.15), MeetingWord(text: "tack", start: 3.2, end: 3.35)]
        XCTAssertEqual(MeetingTranscriptBoundary.committedPrefixCount(previous: [MeetingWord(text: "ja", start: 2.5, end: 2.7),
            MeetingWord(text: "tack", start: 2.75, end: 2.95)], incoming: repeatedPhrase, boundary: 3), 0)
    }
}
