import AVFAudio
import Combine
import MumlaCore
import SwiftUI
import WatchKit

@MainActor
final class WatchRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var notes: [VoiceNote] = []
    @Published private(set) var recording = false
    @Published private(set) var busy = false
    @Published private(set) var installing = false
    @Published private(set) var progress = 0.0
    @Published private(set) var elapsed = 0.0
    @Published private(set) var modelReady = false
    @Published private(set) var hasRecovery = false
    @Published var error: String?
    @Published var language = "sv"
    private let store = VoiceNoteStore.defaultStore()
    private var connectivity: VoiceNoteConnectivity?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var operation: Task<Void, Never>?
    private let transcriber: WatchTranscriber
    private var capture: Capture?
    private var foreground = true
    private let captureURL: URL
    private let captureMetadata: URL

    private struct Capture: Codable {
        var id = UUID()
        var createdAt = Date()
        var language: String
    }

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mumla", isDirectory: true)
        captureURL = support.appendingPathComponent("Capture.wav")
        captureMetadata = support.appendingPathComponent("Capture.json")
        transcriber = WatchTranscriber(directory: support.appendingPathComponent("WhisperBase-v1", isDirectory: true))
        super.init()
        modelReady = transcriber.isInstalled
        connectivity = VoiceNoteConnectivity(store: store) { [weak self] message in
            Task { @MainActor in self?.refresh(message) }
        }
        refresh()
        recoverCapture()
        #if DEBUG
        if CommandLine.arguments.contains("--watch-preview") {
            modelReady = true
        }
        #endif
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop(transcribe: false) }
        }
    }

    func refresh(_ message: String? = nil) {
        do { notes = try store.load() } catch { self.error = error.localizedDescription }
        if let message { error = message }
    }

    func install() {
        guard !busy, !recording, !installing else { return }
        installing = true; error = nil
        operation = Task {
            do {
                try await transcriber.install { value in
                    await MainActor.run { self.progress = value }
                }
                modelReady = true
            } catch is CancellationError { }
            catch { self.error = "The speech model download failed. Try again with Wi-Fi."
            }
            installing = false
            operation = nil
        }
    }

    func cancelOperation() { operation?.cancel() }

    func start() async {
        guard !busy, !recording, !installing else { return }
        guard capture == nil else { error = "An interrupted recording remains. Retry saving it first."; return }
        busy = true; error = nil
        let permitted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard permitted else { error = "Allow microphone access in Settings to record voice notes."; busy = false; return }
        guard foreground else { busy = false; return }
        do {
            try FileManager.default.createDirectory(at: captureURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let draft = Capture(language: language)
            try JSONEncoder().encode(draft).write(to: captureMetadata, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            capture = draft
            hasRecovery = true
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            let recorder = try AVAudioRecorder(url: captureURL, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ])
            recorder.delegate = self
            guard recorder.record(forDuration: 60) else { throw VoiceNoteError.invalidAudio }
            self.recorder = recorder
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: captureURL.path)
            recording = true; elapsed = 0
            WKInterfaceDevice.current().play(.start)
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsed = self?.recorder?.currentTime ?? 0 }
            }
        } catch {
            self.error = "Recording could not start. Check microphone access and available storage."
            recorder?.stop(); recorder = nil; recording = false
            recoverCapture()
        }
        busy = false
    }

    func stop(transcribe: Bool = true) {
        guard recording else { return }
        recording = false
        timer?.invalidate(); timer = nil
        recorder?.stop(); recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        WKInterfaceDevice.current().play(.stop)
        if let id = persistCapture(), transcribe { retry(id) }
    }

    func retry(_ id: UUID) {
        guard !busy, !recording, !installing else { return }
        guard modelReady else { error = "Download the speech model first. Your recording is saved."; return }
        guard let note = notes.first(where: { $0.id == id }) else { return }
        busy = true; error = nil
        operation = Task {
            do {
                let text = try await transcriber.transcribe(audio: store.audioURL(for: id), language: note.language)
                try Task.checkCancellation()
                try store.setTranscript(text, for: id)
                connectivity?.sendPending()
            } catch is CancellationError { }
            catch {
                self.error = "Transcription could not finish. Your recording is saved. Retry while Mumla is open."
                if case WatchTranscriptionError.modelMissing = error { modelReady = false }
            }
            busy = false; operation = nil; refresh()
        }
    }

    func sendAgain() { connectivity?.sendPending() }
    func delete(_ id: UUID) {
        guard !busy, !recording else { return }
        do { try store.delete(id: id); refresh() } catch { self.error = error.localizedDescription }
    }
    func background() {
        foreground = false
        stop(transcribe: false)
        cancelOperation()
    }
    func activate() { foreground = true; refresh(); sendAgain() }
    func recoverCapture() {
        guard FileManager.default.fileExists(atPath: captureMetadata.path) else { return }
        hasRecovery = true
        do {
            capture = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: captureMetadata))
            _ = persistCapture()
        } catch { self.error = "An interrupted recording remains on this Watch. Retry saving it." }
    }

    func discardRecovery() {
        guard !recording, !busy, !installing else { return }
        do {
            if FileManager.default.fileExists(atPath: captureURL.path) { try FileManager.default.removeItem(at: captureURL) }
            try FileManager.default.removeItem(at: captureMetadata)
            capture = nil; hasRecovery = false; error = nil
        } catch { self.error = "The interrupted recording could not be deleted." }
    }

    private func persistCapture() -> UUID? {
        guard let capture else { return nil }
        do {
            let audio = try AVAudioFile(forReading: captureURL)
            let duration = Double(audio.length) / audio.fileFormat.sampleRate
            let note = try store.saveRecording(from: captureURL, id: capture.id, createdAt: capture.createdAt,
                                               duration: duration, language: capture.language)
            try FileManager.default.removeItem(at: captureMetadata)
            try? FileManager.default.removeItem(at: captureURL)
            self.capture = nil
            hasRecovery = false
            refresh()
            return note.id
        } catch {
            self.error = "The recording remains on this Watch. Retry saving it before recording another note."
            return nil
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in stop() }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in stop(transcribe: false) }
    }
}
