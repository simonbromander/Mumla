import AppKit
import AVFoundation
import CoreAudio
import MumlaCore
import XCTest
@testable import MumlaAudio
@testable import MumlaMac

private final class FixtureMeetingCapture: MeetingCapturing {
    var store: MeetingStore?
    var id: UUID?
    var callback: (@Sendable () -> Void)?
    var failure: (@Sendable (String) -> Void)?
    var stopped = false
    var source: MeetingAudioSource?
    var microphoneUID: String?
    var starts = 0
    func start(store: MeetingStore, meetingID: UUID, microphoneUID: String?, source: MeetingAudioSource?,
               offset: TimeInterval, onChunk: @escaping @Sendable () -> Void, onFailure: @escaping @Sendable (String) -> Void) throws {
        self.store = store; id = meetingID; callback = onChunk; failure = onFailure; stopped = false
        self.source = source; self.microphoneUID = microphoneUID; starts += 1
    }
    func stop() { stopped = true }
    func level(_ track: MeetingTrack) -> Double { 0.2 }
    func emit(_ start: Double, track: MeetingTrack = .microphone) throws {
        let chunk = MeetingAudioChunk(id: "fixture-" + UUID().uuidString, track: track, start: start, duration: 3)
        let store = try XCTUnwrap(store); let id = try XCTUnwrap(id)
        try Data([1]).write(to: store.audioURL(chunk, meetingID: id))
        try store.appendChunk(chunk, meetingID: id); callback?()
    }
}

@MainActor
final class MeetingTests: XCTestCase {
    nonisolated(unsafe) private var directory: URL!
    override func setUp() { directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    override func tearDown() { try? FileManager.default.removeItem(at: directory) }
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Meeting state did not settle")
    }
    private func make(_ capture: FixtureMeetingCapture, granted: Bool = true) -> MeetingCoordinator {
        MeetingCoordinator(directory: directory, modelDirectory: { nil }, capture: capture, permission: { granted },
            processor: { chunk, _, _ in
                [MeetingSegment(id: chunk.id + "-0", chunkID: chunk.id, track: chunk.track,
                    start: chunk.start, end: chunk.start + 2, speaker: chunk.track.rawValue, text: "Live transcript")]
            })
    }

    func testDefaultCapturesSystemAudioAndSelectedMicrophoneAndDoesNotMonitorASystemPID() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture)
        model.microphoneUID = { "fixture-microphone" }
        XCTAssertEqual(model.audioSource, .systemAudio)
        await model.start()
        defer { model.stop() }
        let id = try XCTUnwrap(model.activeID)
        XCTAssertEqual(capture.source, .systemAudio)
        XCTAssertEqual(capture.microphoneUID, "fixture-microphone")
        XCTAssertFalse(try model.store.load(id).microphoneOnly)
        XCTAssertEqual(try model.store.load(id).sourceName, model.sourceName)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(model.activeID, id)
        XCTAssertFalse(capture.stopped)
    }

    func testMicrophoneOnlyRemainsAnExplicitChoice() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture)
        model.sourcePID = 0
        await model.start()
        defer { model.stop() }
        let id = try XCTUnwrap(model.activeID)
        XCTAssertNil(capture.source)
        XCTAssertTrue(try model.store.load(id).microphoneOnly)
    }

    func testResumeKeepsOriginalSystemSourceEvenIfSetupSelectionChanges() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture)
        await model.start()
        defer { model.stop() }
        _ = try XCTUnwrap(model.activeID)
        model.togglePause(); model.sourcePID = 0; model.togglePause()
        XCTAssertEqual(capture.starts, 2)
        XCTAssertEqual(capture.source, .systemAudio)
        XCTAssertFalse(model.isPaused)
    }

    func testSuggestedMeetingUsesSystemAudioWithoutStartingAutomatically() {
        let capture = FixtureMeetingCapture(); let model = make(capture)
        model.sourcePID = 123
        model.prepareSuggestedMeeting(title: "Synthetic meeting")
        XCTAssertEqual(model.audioSource, .systemAudio)
        XCTAssertEqual(model.title, "Synthetic meeting")
        XCTAssertNil(model.activeID)
        XCTAssertEqual(capture.starts, 0)
    }

    func testMissingApplicationDoesNotSilentlyBroadenCaptureToSystemAudio() async {
        let capture = FixtureMeetingCapture(); let model = make(capture)
        model.sourcePID = .max
        await model.start()
        XCTAssertNil(model.activeID)
        XCTAssertEqual(capture.starts, 0)
        XCTAssertTrue(model.records.isEmpty)
        XCTAssertNotNil(model.error)
    }

    func testSystemAndMicrophoneChunksBothReachTheLiveTranscript() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture)
        await model.start()
        defer { model.stop() }
        _ = try XCTUnwrap(model.activeID)
        for track in [MeetingTrack.microphone, .system] {
            try capture.emit(0, track: track); try capture.emit(3, track: track)
        }
        model.stop()
        try await waitUntil { model.selected?.processing == .ready }
        let record = try XCTUnwrap(model.selected)
        XCTAssertEqual(record.segments.filter { $0.track == .microphone }.count, 2)
        XCTAssertEqual(record.segments.filter { $0.track == .system }.count, 2)
        XCTAssertEqual(record.speakerName(MeetingTrack.microphone.rawValue), "Me")
        XCTAssertEqual(record.speakerName(MeetingTrack.system.rawValue), "Them")
    }

    func testSystemTapCapturesAllOutputExceptMumlaWithoutMutingPlayback() throws {
        guard #available(macOS 14.2, *) else { throw XCTSkip("System taps require macOS 14.2") }
        let description = try MeetingCapture.tapDescription(for: .systemAudio, processObjectIDs: [42])
        XCTAssertTrue(description.isExclusive)
        XCTAssertTrue(description.isMixdown)
        XCTAssertFalse(description.isMono)
        XCTAssertTrue(description.isPrivate)
        XCTAssertEqual(description.processes, [42])
        XCTAssertEqual(description.muteBehavior, .unmuted)
        let idleDescription = try MeetingCapture.tapDescription(for: .systemAudio, processObjectIDs: [])
        XCTAssertTrue(idleDescription.isExclusive)
        XCTAssertTrue(idleDescription.processes.isEmpty)
    }

    func testApplicationTapRemainsLimitedToSelectedProcessesWithoutGlobalFallback() throws {
        guard #available(macOS 14.2, *) else { throw XCTSkip("System taps require macOS 14.2") }
        let source = MeetingAudioSource(id: 7, name: "Meeting app", bundleID: "app.mumla.fixture.meeting")
        let description = try MeetingCapture.tapDescription(for: source, processObjectIDs: [11, 12])
        XCTAssertFalse(description.isExclusive)
        XCTAssertEqual(description.processes, [11, 12])
        XCTAssertThrowsError(try MeetingCapture.tapDescription(for: source, processObjectIDs: [])) {
            guard case MeetingCaptureError.sourceUnavailable = $0 else { return XCTFail("Must not broaden a missing app to global capture") }
        }
    }

    func testPlaybackCannotStartDuringCaptureEvenOutsideTheUI() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture)
        await model.start()
        defer { model.stop() }
        let record = try XCTUnwrap(model.selected)
        let segment = MeetingSegment(id: "fixture", chunkID: "missing", track: .system,
                                     start: 0, end: 1, speaker: "system", text: "Fixture")
        model.play(segment, meeting: record)
        XCTAssertNil(model.playingSegmentID)
        XCTAssertNil(model.error)
    }

    func testLiveTranscriptArrivesBeforeStopAndFinishesTailAfterStop() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture)
        await model.start(); let id = try XCTUnwrap(model.activeID)
        defer { model.stop() }
        try capture.emit(0); try capture.emit(3)
        try await waitUntil { model.selected?.segments.count == 1 }
        XCTAssertEqual(model.activeID, id); XCTAssertFalse(capture.stopped)
        XCTAssertEqual(model.selected?.processing, .live)
        model.stop()
        try await waitUntil { model.selected?.processing == .ready }
        XCTAssertEqual(model.selected?.segments.count, 2)
        XCTAssertEqual(try model.store.load(id).capture, .saved)
        XCTAssertFalse(model.isCapturing)
    }

    func testRecordNowTranscribeLaterAndRetryAreDurable() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture); model.liveTranscription = false
        await model.start(); try capture.emit(0); try capture.emit(3); model.stop()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(model.selected?.segments.count, 0)
        let id = try XCTUnwrap(model.selectedID); model.transcribe(id)
        try await waitUntil { model.selected?.processing == .ready }
        model.transcribe(id)
        try await waitUntil { !model.isProcessing }
        XCTAssertEqual(try model.store.load(id).segments.count, 2)
    }

    func testPermissionDeniedDoesNotCreateOrStartRecording() async {
        let capture = FixtureMeetingCapture(); let model = make(capture, granted: false)
        await model.start()
        XCTAssertNil(model.activeID); XCTAssertNil(capture.id); XCTAssertFalse(model.isStarting)
        XCTAssertTrue(model.records.isEmpty); XCTAssertNotNil(model.error)
    }

    func testCancelledTranscriptionKeepsRecordingAndLateResultCannotResurrectDeletion() async throws {
        let capture = FixtureMeetingCapture()
        let model = MeetingCoordinator(directory: directory, modelDirectory: { nil }, capture: capture, permission: { true },
            processor: { chunk, _, _ in
                try await Task.sleep(for: .milliseconds(80))
                return [MeetingSegment(id: chunk.id, chunkID: chunk.id, track: .microphone, start: 0, end: 1, speaker: "microphone", text: "Test")]
            })
        await model.start(); try capture.emit(0); try capture.emit(3)
        let id = try XCTUnwrap(model.activeID)
        try await waitUntil { model.isProcessing }
        model.stop(); model.delete(id)
        try await waitUntil { !model.isProcessing }
        XCTAssertThrowsError(try model.store.load(id)); XCTAssertTrue(model.records.isEmpty)
    }

    func testUpdateSuspensionCheckpointsAndResumesQueue() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture); model.liveTranscription = false
        await model.start(); try capture.emit(0); try capture.emit(3); model.stop()
        let id = try XCTUnwrap(model.selectedID)
        model.suspendProcessing(); model.transcribe(id)
        XCTAssertFalse(model.isProcessing)
        model.resumeProcessing()
        try await waitUntil { model.selected?.processing == .ready }
        XCTAssertEqual(model.selected?.segments.count, 2)
    }

    func testAudioCanBeDeletedOnlyAfterTranscriptReadyWhenRetentionIsOff() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture); model.keepAudio = false
        await model.start(); try capture.emit(0); try capture.emit(3)
        let id = try XCTUnwrap(model.activeID)
        try await waitUntil { model.selected?.segments.count == 1 }
        XCTAssertFalse(try model.store.load(id).audioDeleted)
        model.stop()
        try await waitUntil { model.selected?.audioDeleted == true }
        XCTAssertEqual(model.selected?.segments.count, 2)
    }

    func testCaptureFailureStopsAndKeepsSavedChunks() async throws {
        let capture = FixtureMeetingCapture(); let model = make(capture); model.liveTranscription = false
        await model.start(); try capture.emit(0); let id = try XCTUnwrap(model.activeID)
        capture.failure?("Device disconnected")
        try await waitUntil { model.activeID == nil }
        XCTAssertEqual(try model.store.load(id).capture, .interrupted)
        XCTAssertEqual(try model.store.load(id).chunks.count, 1); XCTAssertTrue(capture.stopped)
    }

    func testRealWriterProducesBoundedRecoverablePCMChunks() throws {
        let store = MeetingStore(directory: directory)
        let meeting = try store.create(.init(title: "Fixture", sourceName: "Synthetic", microphoneOnly: true))
        let samples = (0..<112_000).map { Float(sin(Double($0) * 0.1)) * 0.1 }
        try MeetingCapture.writeFixture(samples, track: .microphone, store: store, meetingID: meeting.id)
        let record = try store.load(meeting.id)
        XCTAssertEqual(record.chunks.count, 3)
        XCTAssertEqual(record.chunks.reduce(0) { $0 + $1.duration }, 7, accuracy: 0.001)
        for chunk in record.chunks {
            let file = try AVAudioFile(forReading: store.audioURL(chunk, meetingID: record.id))
            XCTAssertEqual(file.processingFormat.sampleRate, 16_000)
            XCTAssertEqual(file.processingFormat.channelCount, 1)
            XCTAssertLessThanOrEqual(file.length, 48_000)
        }
        try store.recover()
        XCTAssertEqual(try store.load(meeting.id).capture, .interrupted)
    }

    func testMeetingDoesNotLetDictationHotkeyCancelOrReplaceItsPill() async throws {
        let app = AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
            historyStore: DictationHistoryStore(directory: directory), dictionaryStore: DictionaryStore(directory: directory),
            settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil)
        app.meetings.onActivityChanged?(true, false)
        app.pillState = .handsFree(elapsedSeconds: 5)
        app.cancelDictation(); await app.startQuickDictation(); await app.controlTapped()
        XCTAssertEqual(app.pillState, .handsFree(elapsedSeconds: 5))
        XCTAssertFalse(app.canPasteFromHistory); XCTAssertTrue(app.isBusyForAppUpdate)
        app.meetings.onActivityChanged?(false, false)
        XCTAssertFalse(app.isBusyForAppUpdate)
    }

    func testWriterConvertsCommonHardwareRatesAndStereoWithoutLosingDuration() throws {
        let store = MeetingStore(directory: directory)
        for rate in [44_100.0, 48_000.0] {
            let record = try store.create(.init(title: "Hardware format fixture", sourceName: "Synthetic", microphoneOnly: false))
            let samples = (0..<Int(rate * 7)).map { Float(sin(Double($0) * 0.1)) * 0.1 }
            try MeetingCapture.writeFixture(samples, track: .system, store: store, meetingID: record.id, sampleRate: rate, channels: 2)
            let chunks = try store.load(record.id).chunks
            XCTAssertEqual(chunks.reduce(0) { $0 + $1.duration }, 7, accuracy: 0.01)
            XCTAssertEqual(chunks.count, 3)
            for chunk in chunks {
                let file = try AVAudioFile(forReading: store.audioURL(chunk, meetingID: record.id))
                XCTAssertEqual(file.processingFormat.sampleRate, 16_000)
                XCTAssertEqual(file.processingFormat.channelCount, 1)
            }
        }
    }

    func testMeetingOverlayIsOnlyPresentedForRecordingStateChanges() {
        let app = AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
            historyStore: DictationHistoryStore(directory: directory), dictionaryStore: DictionaryStore(directory: directory),
            settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil)
        var presentations = 0
        app.showPill = { presentations += 1 }
        app.meetings.onRecordingUpdate?(1, 0.2, false)
        app.meetings.onRecordingUpdate?(2, 0.3, false)
        XCTAssertEqual(presentations, 1)
        XCTAssertEqual(app.pillState, .handsFree(elapsedSeconds: 2))
        app.meetings.onRecordingUpdate?(3, 0, true)
        app.meetings.onRecordingUpdate?(4, 0, true)
        XCTAssertEqual(presentations, 2)
        app.meetings.onRecordingUpdate?(5, 0.3, false)
        XCTAssertEqual(presentations, 3)
        app.meetings.onRecordingEnded?()
        XCTAssertEqual(app.pillState, .hidden)
    }

    func testRealLocalModelsOnExplicitSyntheticSpeechFixture() async throws {
        guard let path = ProcessInfo.processInfo.environment["MUMLA_MEETING_TEST_AUDIO"],
              let modelDirectory = ModelPathResolver.resolveCompiledPianissimoModel() else {
            throw XCTSkip("Opt in with MUMLA_MEETING_TEST_AUDIO and an installed local speech model")
        }
        let store = MeetingStore(directory: directory)
        let meeting = try store.create(.init(title: "Synthetic speech", sourceName: "Generated fixture", microphoneOnly: true))
        let samples = try MeetingLiveTranscriber.read(URL(fileURLWithPath: path))
        try MeetingCapture.writeFixture(samples, track: .microphone, store: store, meetingID: meeting.id)
        let speakerModel = MeetingSpeakerModel(directory: directory)
        try await speakerModel.install(progress: { _ in })
        let engine = MeetingLiveTranscriber(modelDirectory: modelDirectory, speakerModelURL: speakerModel.modelURL)
        for chunk in try store.load(meeting.id).chunks {
            let result = try await engine.process(chunk: chunk, meeting: store.load(meeting.id), store: store)
            try store.commitTranscript(result, chunkID: chunk.id, meetingID: meeting.id)
        }
        let result = try store.load(meeting.id)
        if let report = ProcessInfo.processInfo.environment["MUMLA_MEETING_TEST_REPORT"] {
            try result.exportJSON().write(to: URL(fileURLWithPath: report), options: .atomic)
            try JSONEncoder().encode(result).write(to: URL(fileURLWithPath: report + ".internal.json"), options: .atomic)
        }
        XCTAssertFalse(result.segments.isEmpty)
        XCTAssertTrue(result.transcript(timestamps: false).localizedCaseInsensitiveContains("möte"), result.transcript(timestamps: false))
        XCTAssertFalse(result.transcript(timestamps: false).contains("Vi Vi"))
        XCTAssertFalse(result.transcript(timestamps: false).contains("alla alla"))
        XCTAssertTrue(result.segments.contains { $0.speaker.hasPrefix("microphone-") })
        XCTAssertTrue(result.segments.allSatisfy { $0.start >= 0 && $0.end <= result.duration + 0.1 })
    }

    func testBothMacVariantsDeclareSystemAudioUsage() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for filename in ["Info.plist", "Info-Direct.plist"] {
            let data = try Data(contentsOf: root.appendingPathComponent("Apps/macOS/Mumla/" + filename))
            let dictionary = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
            XCTAssertFalse(try XCTUnwrap(dictionary["NSAudioCaptureUsageDescription"] as? String).isEmpty)
        }
    }

    func testTwoHourTwoTrackWriterOnExplicitOptIn() throws {
        guard ProcessInfo.processInfo.environment["MUMLA_MEETING_LONG_TEST"] == "1" else { throw XCTSkip("Opt-in two-hour disk-backed writer acceptance") }
        let store = MeetingStore(directory: directory)
        let record = try store.create(.init(title: "Two-hour fixture", sourceName: "Synthetic", microphoneOnly: false))
        let minute = [Float](repeating: 0, count: 60 * 16_000)
        for index in 0..<120 {
            for track in MeetingTrack.allCases {
                try MeetingCapture.writeFixture(minute, track: track, store: store, meetingID: record.id, offset: Double(index) * 60)
            }
        }
        let result = try store.load(record.id)
        XCTAssertEqual(result.chunks.count, 4800)
        XCTAssertEqual(result.chunks.filter { $0.track == .microphone }.reduce(0) { $0 + $1.duration }, 7200, accuracy: 0.1)
        XCTAssertEqual(result.chunks.filter { $0.track == .system }.reduce(0) { $0 + $1.duration }, 7200, accuracy: 0.1)
        XCTAssertTrue(result.chunks.allSatisfy { $0.duration <= 3.01 })
        try store.recover(); XCTAssertEqual(try store.load(record.id).capture, .interrupted)
    }
}
