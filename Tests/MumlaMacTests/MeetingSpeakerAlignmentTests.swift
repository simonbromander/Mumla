import AVFoundation
import FluidAudio
import Foundation
import MumlaCore
import XCTest
@testable import MumlaAudio

private final class DelayedSpeakerFixture: MeetingSpeakerStreaming, @unchecked Sendable {
    private let lock = NSLock()
    private let speech: [MeetingSpeakerRegion]
    private var samples = 0
    private var finished = false
    private var inputs: [Int] = []
    private var finishes = 0
    let paddingSamples = 16_000

    init(_ speech: [MeetingSpeakerRegion] = [.init(index: 1, start: 0, end: 120)]) { self.speech = speech }
    var inputSizes: [Int] { lock.withLock { inputs } }
    var finishCount: Int { lock.withLock { finishes } }

    func addAudio(_ audio: [Float]) throws {
        lock.withLock { samples += audio.count; inputs.append(audio.count) }
    }
    func process() throws {}
    func finish() throws { lock.withLock { if !finished { finished = true; finishes += 1 } } }
    func regions(in interval: Range<Double>) -> [MeetingSpeakerRegion] {
        lock.withLock {
            let available = Double(samples) / 16_000 - (finished ? 0 : 1)
            return speech.compactMap {
                let end = min($0.end, available)
                guard $0.start < end, $0.start < interval.upperBound, end > interval.lowerBound else { return nil }
                return .init(index: $0.index, start: $0.start, end: end)
            }
        }
    }
}

private final class RecognitionRetryFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var attempts = 0
    func words() throws -> [MeetingWord] {
        let first = lock.withLock { attempts += 1; return attempts == 1 }
        if first { throw MeetingStoreError.changed }
        return [.init(text: "Generated", start: 2.2, end: 2.5)]
    }
}

final class MeetingSpeakerAlignmentTests: XCTestCase {
    private var directory: URL!
    override func setUp() { directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    override func tearDown() { try? FileManager.default.removeItem(at: directory) }

    private func recording(seconds: Double, state: MeetingCaptureState = .recording) throws -> (MeetingStore, MeetingRecord) {
        let store = MeetingStore(directory: directory)
        let meeting = try store.create(.init(title: "Generated speaker fixture", sourceName: "Synthetic", microphoneOnly: false))
        try MeetingCapture.writeFixture([Float](repeating: 0.125, count: Int(seconds * 16_000)),
            track: .system, store: store, meetingID: meeting.id)
        return (store, try store.update(meeting.id) { $0.capture = state })
    }

    private func engine(_ stream: DelayedSpeakerFixture,
                        words: @escaping @Sendable ([Float]) async throws -> [MeetingWord] = { _ in [.init(text: "Generated", start: 2.2, end: 2.5)] }) -> MeetingLiveTranscriber {
        MeetingLiveTranscriber(modelDirectory: directory, speakerModelURL: directory.appendingPathComponent("unused-model"),
            speakerFactory: { _ in stream }, recognize: words)
    }

    func testLiveChunkTailUsesAvailableLookaheadInsteadOfBecomingAnotherSpeaker() async throws {
        let (store, meeting) = try recording(seconds: 6)
        let chunks = meeting.chunks.sorted { $0.start < $1.start }
        let stream = DelayedSpeakerFixture()
        let result = try await engine(stream).process(chunk: chunks[0], meeting: meeting, store: store)
        XCTAssertEqual(result.map(\.speaker), ["system-1"])
        XCTAssertEqual(stream.inputSizes, [48_000, 48_000])
        XCTAssertEqual(stream.finishCount, 0, "An active call must keep its speaker session alive")
    }

    func testLookaheadKeepsDistinctPeopleAndReturningSpeakerSeparate() async throws {
        let (store, meeting) = try recording(seconds: 9)
        let chunks = meeting.chunks.sorted { $0.start < $1.start }
        let stream = DelayedSpeakerFixture([
            .init(index: 1, start: 0, end: 3), .init(index: 2, start: 3, end: 6), .init(index: 1, start: 6, end: 9)])
        let engine = engine(stream)
        var labels: [String] = []
        for chunk in chunks {
            let snapshot = chunk.id == chunks.last?.id ? try store.update(meeting.id) { $0.capture = .saved } : meeting
            labels += try await engine.process(chunk: chunk, meeting: snapshot, store: store).map(\.speaker)
        }
        XCTAssertEqual(labels, ["system-1", "system-2", "system-1"])
        XCTAssertEqual(stream.inputSizes, [48_000, 48_000, 48_000])
    }

    func testRetryUsesOriginalModelOffsetAndDoesNotIngestAudioTwice() async throws {
        let (store, meeting) = try recording(seconds: 6)
        let chunk = try XCTUnwrap(meeting.chunks.min { $0.start < $1.start })
        let stream = DelayedSpeakerFixture()
        let recognition = RecognitionRetryFixture()
        let engine = engine(stream, words: { _ in try recognition.words() })
        do { _ = try await engine.process(chunk: chunk, meeting: meeting, store: store); XCTFail("Expected the first ASR attempt to fail") }
        catch MeetingStoreError.changed {}
        let retried = try await engine.process(chunk: chunk, meeting: meeting, store: store)
        XCTAssertEqual(retried.map(\.speaker), ["system-1"])
        XCTAssertEqual(stream.inputSizes, [48_000, 48_000])
    }

    func testFinalPartialChunkDrainsSpeakerContextWithoutAddingTranscriptWords() async throws {
        let (store, meeting) = try recording(seconds: 3.2, state: .saved)
        let chunks = meeting.chunks.sorted { $0.start < $1.start }
        let stream = DelayedSpeakerFixture()
        let engine = engine(stream, words: { samples in
            samples.count > 40_000 ? [.init(text: "Generated", start: 2.2, end: 2.5)] : [.init(text: "Tail", start: 2.05, end: 2.1)]
        })
        let first = try await engine.process(chunk: chunks[0], meeting: meeting, store: store)
        let last = try await engine.process(chunk: chunks[1], meeting: meeting, store: store)
        XCTAssertEqual(first.map(\.speaker), ["system-1"])
        XCTAssertEqual(last.map(\.speaker), ["system-1"])
        XCTAssertEqual(first.map(\.text), ["Generated"])
        XCTAssertEqual(last.map(\.text), ["Tail"])
        XCTAssertTrue(last.allSatisfy { $0.end <= 3.2 })
        XCTAssertEqual(stream.finishCount, 1)
    }

    func testPauseDrainsTailWithoutFinalizingAndResumeRetainsAnIndependentClock() async throws {
        let (store, original) = try recording(seconds: 6)
        let ordered = original.chunks.sorted { $0.start < $1.start }
        let paused = try store.update(original.id) { $0.capture = .paused; $0.chunks.removeAll { $0.id != ordered[0].id } }
        let stream = DelayedSpeakerFixture([
            .init(index: 1, start: 0, end: 3), .init(index: 2, start: 4, end: 7)])
        let engine = engine(stream)
        let first = try await engine.process(chunk: ordered[0], meeting: paused, store: store)
        XCTAssertEqual(first.map(\.speaker), ["system-1"])
        XCTAssertEqual(stream.finishCount, 0)
        let resumed = try store.update(original.id) {
            $0.chunks = ordered; $0.chunks[1].start = 30; $0.capture = .saved
        }
        let last = try await engine.process(chunk: resumed.chunks[1], meeting: resumed, store: store)
        XCTAssertEqual(last.map(\.speaker), ["system-2"])
        XCTAssertEqual(stream.inputSizes, [48_000, 16_000, 48_000])
        XCTAssertEqual(stream.finishCount, 1)
    }

    func testWordMidpointInShortActivityGapDoesNotSplitTheSameVoice() async throws {
        let (store, meeting) = try recording(seconds: 3, state: .saved)
        let stream = DelayedSpeakerFixture([.init(index: 1, start: 0, end: 0.44), .init(index: 1, start: 0.46, end: 3)])
        let engine = engine(stream, words: { _ in [.init(text: "Generated", start: 0.3, end: 0.6)] })
        let result = try await engine.process(chunk: meeting.chunks[0], meeting: meeting, store: store)
        XCTAssertEqual(result.map(\.speaker), ["system-1"])
    }

    func testOverlappingPeopleStayUnassignedInsteadOfBeingMerged() async throws {
        let (store, meeting) = try recording(seconds: 3, state: .saved)
        let stream = DelayedSpeakerFixture([.init(index: 1, start: 0, end: 3), .init(index: 2, start: 0, end: 3)])
        let result = try await engine(stream).process(chunk: meeting.chunks[0], meeting: meeting, store: store)
        XCTAssertEqual(result.map(\.speaker), [MeetingTrack.system.rawValue])
    }

    func testConcreteTimelineKeepsAbsoluteFramePositionsAfterHistoryIsTrimmed() throws {
        let timeline = DiarizerTimeline(config: .init(numSpeakers: 3, frameDurationSeconds: 0.1,
            maxStoredFrames: 40, storeSegments: false))
        for _ in 0..<150 {
            try timeline.addPredictions(finalizedPredictions: Array(repeating: [Float](arrayLiteral: 0.1, 0.9, 0.1), count: 10).flatMap { $0 }, tentativePredictions: [])
        }
        XCTAssertEqual(timeline.numFinalizedFrames, 1_500)
        XCTAssertEqual(timeline.finalizedPredictions.count, 120)
        let regions = LSEENDMeetingSpeakerStream.regions(in: 148..<149, timeline: timeline)
        XCTAssertEqual(MeetingSpeakerAlignment.index(in: 148.2..<148.5, regions: regions), 1)
        XCTAssertTrue(LSEENDMeetingSpeakerStream.regions(in: 0..<1, timeline: timeline).isEmpty)
        XCTAssertTrue(LSEENDMeetingSpeakerStream.regions(in: 151..<152, timeline: timeline).isEmpty)
        XCTAssertTrue(timeline.speakers.values.allSatisfy { $0.finalizedSegments.isEmpty })
    }

    func testConcreteTimelineOverlapAndLowConfidenceRemainUnassigned() throws {
        let timeline = try DiarizerTimeline(allPredictions: [0.1, 0.9, 0.8, 0.1, 0.2, 0.3],
            config: .init(numSpeakers: 3, frameDurationSeconds: 0.1, storeSegments: false))
        let regions = LSEENDMeetingSpeakerStream.regions(in: 0..<0.2, timeline: timeline)
        XCTAssertNil(MeetingSpeakerAlignment.index(in: 0..<0.09, regions: regions))
        XCTAssertNil(MeetingSpeakerAlignment.index(in: 0.11..<0.19, regions: regions))
        XCTAssertNil(MeetingSpeakerAlignment.index(in: 0..<1,
            regions: [.init(index: 1, start: 0, end: 0.2)]))
    }

    func testSpeakerModelFailurePreservesTranscriptAndReportsUnassignedSource() async throws {
        let (store, meeting) = try recording(seconds: 3, state: .saved)
        let engine = MeetingLiveTranscriber(modelDirectory: directory, speakerModelURL: directory.appendingPathComponent("unused-model"),
            speakerFactory: { _ in throw MeetingStoreError.invalidData },
            recognize: { _ in [.init(text: "Generated", start: 2.2, end: 2.5)] })
        let result = try await engine.process(chunk: meeting.chunks[0], meeting: meeting, store: store)
        XCTAssertEqual(result.map(\.text), ["Generated"])
        XCTAssertEqual(result.map(\.speaker), ["system"])
        let failed = await engine.speakerLabelsFailed
        XCTAssertTrue(failed)
    }

    func testMicrophoneAndRemoteUseIndependentSpeakerSessions() async throws {
        let (store, original) = try recording(seconds: 6)
        try MeetingCapture.writeFixture([Float](repeating: 0.125, count: 96_000),
            track: .microphone, store: store, meetingID: original.id)
        let meeting = try store.load(original.id)
        let engine = MeetingLiveTranscriber(modelDirectory: directory, speakerModelURL: directory.appendingPathComponent("unused-model"),
            speakerFactory: { _ in DelayedSpeakerFixture() },
            recognize: { _ in [.init(text: "Generated", start: 2.2, end: 2.5)] })
        for track in [MeetingTrack.microphone, .system] {
            let chunk = try XCTUnwrap(meeting.chunks.filter { $0.track == track }.min { $0.start < $1.start })
            let result = try await engine.process(chunk: chunk, meeting: meeting, store: store)
            XCTAssertEqual(result.map(\.speaker), [track.rawValue + "-1"])
        }
    }

    func testPausedTailIsNotPaddedAgainOnRetry() async throws {
        let (store, meeting) = try recording(seconds: 3, state: .paused)
        let stream = DelayedSpeakerFixture()
        let recognition = RecognitionRetryFixture()
        let engine = engine(stream, words: { _ in try recognition.words() })
        do { _ = try await engine.process(chunk: meeting.chunks[0], meeting: meeting, store: store); XCTFail("Expected a retry") }
        catch MeetingStoreError.changed {}
        let result = try await engine.process(chunk: meeting.chunks[0], meeting: meeting, store: store)
        XCTAssertEqual(result.map(\.speaker), ["system-1"])
        XCTAssertEqual(stream.inputSizes, [48_000, 16_000])
        XCTAssertEqual(stream.finishCount, 0)
    }
}
