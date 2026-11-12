import AppKit
import AVFoundation
import Combine
import Foundation
import MumlaAudio
import MumlaCore
import MumlaUI

@MainActor
final class MeetingCoordinator: ObservableObject {
    typealias Processor = @Sendable (MeetingAudioChunk, MeetingRecord, MeetingStore) async throws -> [MeetingSegment]
    @Published private(set) var records: [MeetingRecord] = []
    @Published var selectedID: UUID?
    @Published private(set) var activeID: UUID?
    @Published private(set) var isStarting = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var microphoneLevel = 0.0
    @Published private(set) var systemLevel = 0.0
    @Published var error: String?
    @Published private(set) var isProcessing = false
    @Published private(set) var speakerDownload: Double?
    @Published private(set) var speakersInstalled = false
    @Published private(set) var sources: [MeetingAudioSource] = []
    @Published var sourcePID: Int32 = MeetingAudioSource.systemAudio.id
    @Published var title = ""
    @Published var liveTranscription = true
    @Published var keepAudio = true
    let store: MeetingStore
    let speakerModel: MeetingSpeakerModel
    var microphoneUID: () -> String? = { nil }
    var canStart: () -> Bool = { true }
    var canProcess: () -> Bool = { true }
    var onActivityChanged: ((Bool, Bool) -> Void)?
    var onRecordingUpdate: ((TimeInterval, Double, Bool) -> Void)?
    var onRecordingEnded: (() -> Void)?
    private let capture: any MeetingCapturing
    private let modelDirectory: () -> URL?
    private let permission: () async -> Bool
    private let injectedProcessor: Processor?
    private var engine: MeetingLiveTranscriber?
    private var work: Task<Void, Never>?
    private var download: Task<Void, Never>?
    private var timer: Timer?
    private var retentionTimer: Timer?
    private var retentionDeadline: Date?
    private var startedAt: TimeInterval = 0
    private var selectedSource: MeetingAudioSource?
    private var queuedIDs: [UUID] = []
    private var liveIDs: Set<UUID> = []
    private var startGeneration = UUID()
    private var captureGeneration = UUID()
    private var processingSuspended = false
    private var player: AVAudioPlayer?
    @Published private(set) var playingSegmentID: String?

    init(directory: URL, modelDirectory: @escaping () -> URL?, capture: any MeetingCapturing = MeetingCapture(),
         permission: @escaping () async -> Bool = {
             if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized { return true }
             return await AVCaptureDevice.requestAccess(for: .audio)
         }, processor: Processor? = nil) {
        store = MeetingStore(directory: directory); speakerModel = MeetingSpeakerModel(directory: directory)
        self.modelDirectory = modelDirectory; self.capture = capture
        self.permission = permission; self.injectedProcessor = processor
        speakersInstalled = speakerModel.isInstalled
    }

    var isCapturing: Bool { activeID != nil || isStarting }
    var selected: MeetingRecord? { records.first { $0.id == selectedID } }
    var audioSource: MeetingAudioSource? {
        sourcePID == MeetingAudioSource.systemAudio.id ? .systemAudio : sources.first { $0.id == sourcePID }
    }
    var sourceName: String {
        if sourcePID == 0 { return mText("Endast mikrofon", "Microphone only") }
        if audioSource == .systemAudio { return mText("Systemljud + mikrofon", "System audio + microphone") }
        return audioSource?.name ?? mText("Appen är inte tillgänglig", "App unavailable")
    }
    var availabilityMessage: String? {
        #if !arch(arm64)
        return mText("Möten kräver Apple Silicon i den här betan.", "Meetings require Apple Silicon in this beta.")
        #else
        guard #available(macOS 14.2, *) else { return "Meeting capture requires macOS 14.2 or later." }
        if Bundle.main.object(forInfoDictionaryKey: "MumlaDistribution") as? String == "app-store" {
            return mText("Möten kräver direktversionen av Mumla för Mac.", "Meetings require the direct-download Mac build.")
        }
        return nil
        #endif
    }

    func bootstrap() {
        do { try store.recover(); try store.pruneAudio(); reload() } catch { self.error = error.localizedDescription }
        refreshSources()
    }

    func refreshSources() {
        #if DEBUG
        if CommandLine.arguments.contains("--meeting-ui-testing") || CommandLine.arguments.contains("--design-snapshot") {
            sources = [.init(id: ProcessInfo.processInfo.processIdentifier, name: "Meeting app", bundleID: "app.mumla.fixture.meeting")]
            return
        }
        #endif
        sources = NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  let name = app.localizedName, let bundle = app.bundleIdentifier else { return nil }
            return MeetingAudioSource(id: app.processIdentifier, name: name, bundleID: bundle)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func prepareSuggestedMeeting(title: String?) {
        sourcePID = MeetingAudioSource.systemAudio.id
        self.title = title ?? ""
    }

    #if DEBUG
    func prepareRecordingDesignSnapshot(_ id: UUID, paused: Bool) {
        activeID = id; selectedID = id; isPaused = paused; elapsed = 1485
        microphoneLevel = 0.5; systemLevel = 0.3
        _ = try? store.update(id) { $0.capture = paused ? .paused : .recording; $0.processing = .live }
        reload()
    }
    #endif

    func reload() {
        do { records = try store.list(); scheduleRetention() } catch { self.error = error.localizedDescription }
    }

    private func scheduleRetention() {
        let next = records.filter { !$0.audioDeleted && $0.capture != .recording && $0.capture != .paused }
            .compactMap { $0.completedAt?.addingTimeInterval(7 * 86400) }.min()
        guard next != retentionDeadline else { return }
        retentionTimer?.invalidate(); retentionDeadline = next
        guard let next else { return }
        retentionTimer = Timer.scheduledTimer(withTimeInterval: max(1, next.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.retentionDeadline = nil
                if !self.isProcessing {
                    self.stopPlayback()
                    do { try self.store.pruneAudio() } catch { self.error = error.localizedDescription }
                    self.reload()
                } else {
                    // Retry when the active worker finishes; never delete beneath its reader.
                    self.retentionDeadline = next
                }
            }
        }
    }

    func start() async {
        if let availabilityMessage { error = availabilityMessage; return }
        guard !isCapturing, canStart() else { error = mText("Avsluta dikteringen först.", "Finish dictation first."); return }
        guard #available(macOS 14.2, *) else { error = "Meeting capture requires macOS 14.2 or later."; return }
        let generation = UUID(); startGeneration = generation; isStarting = true; error = nil; publishActivity()
        defer { if startGeneration == generation { isStarting = false; publishActivity() } }
        guard await permission() else { error = mText("Tillåt mikrofonen i Systeminställningar.", "Allow microphone access in System Settings."); return }
        guard startGeneration == generation else { return }
        refreshSources()
        let source = audioSource
        guard sourcePID == 0 || source != nil else { error = "The selected meeting app is no longer available."; return }
        let record = MeetingRecord(title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? mText("Möte", "Meeting") + " " + Date().formatted(date: .abbreviated, time: .shortened) : String(title.prefix(200)),
            sourceName: sourceName, microphoneOnly: source == nil)
        do {
            try store.create(record)
            _ = try store.update(record.id) { $0.deleteAudioWhenReady = !keepAudio }
            stopPlayback()
            selectedID = record.id; selectedSource = source; activeID = record.id
            startedAt = ProcessInfo.processInfo.systemUptime; elapsed = 0; isPaused = false
            if liveTranscription { liveIDs.insert(record.id) }
            try beginCapture(record.id)
            if liveTranscription, let directory = modelDirectory(), injectedProcessor == nil {
                let prepared = MeetingLiveTranscriber(modelDirectory: directory,
                    speakerModelURL: speakersInstalled ? speakerModel.modelURL : nil)
                engine = prepared
                Task { try? await prepared.prepare() }
            }
            reload(); startTimer(); publishActivity()
        } catch {
            capture.stop(); activeID = nil
            _ = try? store.update(record.id) { $0.capture = .interrupted }
            reload(); self.error = error.localizedDescription; onRecordingEnded?()
        }
    }

    private func beginCapture(_ id: UUID) throws {
        let generation = UUID(); captureGeneration = generation
        try capture.start(store: store, meetingID: id, microphoneUID: microphoneUID(), source: selectedSource,
            offset: elapsed, onChunk: { [weak self] in
                Task { @MainActor in self?.reload(); self?.enqueue(id) }
            }, onFailure: { [weak self] message in
                Task { @MainActor in
                    guard let self, self.activeID == id, self.captureGeneration == generation else { return }
                    self.stop(interrupted: true); self.error = message
                }
            })
    }

    func togglePause() {
        guard let id = activeID else { return }
        if isPaused {
            elapsed = ProcessInfo.processInfo.systemUptime - startedAt
            do { try beginCapture(id); isPaused = false; _ = try store.update(id) { $0.capture = .recording } }
            catch { self.error = error.localizedDescription }
        } else {
            captureGeneration = UUID()
            capture.stop(); isPaused = true
            _ = try? store.update(id) { $0.capture = .paused; $0.duration = max($0.duration, elapsed) }
        }
        reload(); tick()
    }

    func stop(interrupted: Bool = false) {
        startGeneration = UUID(); isStarting = false
        guard let id = activeID else { publishActivity(); return }
        captureGeneration = UUID()
        capture.stop(); timer?.invalidate(); timer = nil
        elapsed = max(elapsed, ProcessInfo.processInfo.systemUptime - startedAt)
        do { _ = try store.update(id) { $0.capture = interrupted ? .interrupted : .saved; $0.duration = max($0.duration, elapsed) } }
        catch { self.error = mText("Ljudet finns på disken men mötet kunde inte uppdateras.", "Audio is on disk but meeting metadata could not be updated.") }
        activeID = nil; isPaused = false; microphoneLevel = 0; systemLevel = 0
        reload(); publishActivity(); onRecordingEnded?()
        if liveIDs.contains(id) { enqueue(id) }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func tick() {
        guard activeID != nil else { return }
        elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        microphoneLevel = capture.level(.microphone); systemLevel = capture.level(.system)
        onRecordingUpdate?(elapsed, microphoneLevel, isPaused)
        if case .application(let pid, _, _) = selectedSource,
           NSRunningApplication(processIdentifier: pid)?.isTerminated != false {
            stop(interrupted: true); error = mText("Mötesappen stängdes. Inspelningen är sparad.", "Meeting app closed. Recording saved.")
        }
    }

    func transcribe(_ id: UUID) {
        liveIDs.insert(id); error = nil
        _ = try? store.update(id) { $0.processing = .pending }
        enqueue(id)
    }

    func modelBecameAvailable() {
        for id in liveIDs { enqueue(id) }
    }

    private func enqueue(_ id: UUID) {
        guard liveIDs.contains(id) else { return }
        if !queuedIDs.contains(id) { queuedIDs.append(id) }
        guard work == nil, !processingSuspended else { return }
        work = Task { [weak self] in
            guard let self else { return }
            self.isProcessing = true; self.publishActivity()
            defer {
                self.work = nil; self.isProcessing = false; self.publishActivity()
                try? self.store.pruneAudio(); self.retentionDeadline = nil; self.reload()
                if self.activeID == nil { self.engine = nil }
                if !self.processingSuspended, let next = self.queuedIDs.first,
                   self.activeID == nil || self.queuedIDs.contains(self.activeID!) { self.enqueue(next) }
            }
            while !self.queuedIDs.isEmpty, !Task.isCancelled {
                if let activeID = self.activeID {
                    guard let index = self.queuedIDs.firstIndex(of: activeID) else { break }
                    self.queuedIDs.swapAt(0, index)
                }
                let meetingID = self.queuedIDs.removeFirst()
                guard self.liveIDs.contains(meetingID), let meeting = try? self.store.load(meetingID), !meeting.audioDeleted else { continue }
                let chunks = meeting.chunks.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
                let pending = chunks.filter { !meeting.processedChunkIDs.contains($0.id) }
                guard let chunk = pending.first(where: { chunk in
                    meeting.capture != .recording || chunks.contains { $0.track == chunk.track && $0.start > chunk.start }
                }) else {
                    if pending.isEmpty && meeting.capture != .recording && meeting.capture != .paused {
                        _ = try? self.store.update(meetingID) { $0.processing = .ready; if $0.completedAt == nil { $0.completedAt = Date() } }
                        if meeting.deleteAudioWhenReady == true { try? self.store.deleteAudio(meetingID) }
                    }
                    continue
                }
                if !self.canProcess() {
                    self.queuedIDs.insert(meetingID, at: 0)
                    try? await Task.sleep(for: .milliseconds(250)); continue
                }
                guard self.injectedProcessor != nil || self.modelDirectory() != nil else {
                    self.error = mText("Inspelningen sparas. Hämta språkmodellen för att transkribera.", "Recording is saved. Download the language model to transcribe.")
                    continue
                }
                do {
                    _ = try self.store.update(meetingID) { $0.processing = self.activeID == meetingID ? .live : .processing }
                    let segments: [MeetingSegment]
                    if let processor = self.injectedProcessor { segments = try await processor(chunk, meeting, self.store) }
                    else {
                        if self.engine == nil, let directory = self.modelDirectory() {
                            self.engine = MeetingLiveTranscriber(modelDirectory: directory,
                                speakerModelURL: self.speakersInstalled ? self.speakerModel.modelURL : nil)
                        }
                        guard let engine = self.engine else { throw MeetingStoreError.invalidData }
                        segments = try await engine.process(chunk: chunk, meeting: meeting, store: self.store)
                        if await engine.speakerLabelsFailed {
                            _ = try self.store.update(meetingID) { $0.speakerLabelsUnavailable = true }
                        }
                    }
                    try Task.checkCancellation()
                    guard self.liveIDs.contains(meetingID) else { continue }
                    try self.store.commitTranscript(segments, chunkID: chunk.id, meetingID: meetingID)
                    self.reload()
                    if !self.queuedIDs.contains(meetingID) { self.queuedIDs.insert(meetingID, at: 0) }
                } catch is CancellationError { break }
                catch {
                    _ = try? self.store.update(meetingID) { $0.processing = .failed }
                    self.liveIDs.remove(meetingID); self.error = mText("Ljudet är sparat. Transkriberingen misslyckades. Försök igen.", "Audio is saved. Transcription failed. Try again.")
                }
            }
        }
    }

    func cancelProcessing(_ id: UUID) {
        liveIDs.remove(id); queuedIDs.removeAll { $0 == id }
        _ = try? store.update(id) { $0.processing = .pending }; reload()
    }

    func suspendProcessing() { processingSuspended = true; work?.cancel() }

    func resumeProcessing() {
        processingSuspended = false
        for id in liveIDs { enqueue(id) }
    }

    func installSpeakers() {
        guard download == nil, !isCapturing, !isProcessing else { return }
        speakerDownload = 0
        publishActivity()
        download = Task {
            defer { download = nil; speakerDownload = nil; publishActivity() }
            do {
                try await speakerModel.install { [weak self] fraction in Task { @MainActor in self?.speakerDownload = fraction } }
                speakersInstalled = true
                if !isCapturing && !isProcessing { engine = nil }
            } catch { self.error = error.localizedDescription }
        }
    }

    func renameSpeaker(_ speaker: String, name: String, meetingID: UUID) {
        do { _ = try store.update(meetingID) { $0.speakerNames[speaker] = String(name.prefix(100)) }; reload() }
        catch { self.error = error.localizedDescription }
    }

    func correct(_ segment: MeetingSegment, text: String, meetingID: UUID) {
        do { try store.correct(segment.id, meetingID: meetingID, expectedText: segment.text, text: text); reload() }
        catch { self.error = error.localizedDescription }
    }

    func applyCorrection(_ segment: MeetingSegment, text: String, speakerName: String, meetingID: UUID) throws {
        _ = try store.update(meetingID) { record in
            guard let index = record.segments.firstIndex(where: { $0.id == segment.id }),
                  record.segments[index].text == segment.text, text.count <= 20_000 else { throw MeetingStoreError.changed }
            record.segments[index].text = text
            record.speakerNames[segment.speaker] = String(speakerName.prefix(100))
        }
        reload()
    }

    func delete(_ id: UUID) {
        guard activeID != id else { return }
        cancelProcessing(id); stopPlayback()
        do { try store.delete(id); if selectedID == id { selectedID = nil }; reload() }
        catch { self.error = error.localizedDescription }
    }

    func deleteAudio(_ id: UUID) {
        guard activeID != id else { return }
        cancelProcessing(id); stopPlayback()
        do { try store.deleteAudio(id); reload() } catch { self.error = error.localizedDescription }
    }

    func play(_ segment: MeetingSegment, meeting: MeetingRecord) {
        guard !isCapturing else { return }
        if playingSegmentID == segment.id { stopPlayback(); return }
        do {
            guard !meeting.audioDeleted, let chunk = meeting.chunks.first(where: { $0.id == segment.chunkID }) else { throw MeetingStoreError.audioUnavailable }
            player = try AVAudioPlayer(contentsOf: store.audioURL(chunk, meetingID: meeting.id))
            player?.currentTime = max(0, segment.start - chunk.start); player?.play(); playingSegmentID = segment.id
            let currentPlayer = player
            let remaining = max(0, (player?.duration ?? 0) - (player?.currentTime ?? 0))
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(remaining))
                if self?.player === currentPlayer { self?.stopPlayback() }
            }
        } catch { self.error = error.localizedDescription }
    }

    func stopPlayback() { player?.stop(); player = nil; playingSegmentID = nil }
    private func publishActivity() { onActivityChanged?(isCapturing, isProcessing || speakerDownload != nil) }
}
