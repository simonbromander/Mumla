import AVFoundation
import MumlaAudio
import MumlaCore
import MumlaUI
import SwiftUI

@MainActor
final class DictationSession: ObservableObject {
    enum State: Equatable { case idle, requestingPermission, recording, transcribing }
    @Published private(set) var state: State = .idle
    @Published private(set) var history: [DictationRecord] = []
    @Published private(set) var dictionary: [DictionaryEntry] = []
    @Published private(set) var modelReady = false
    @Published private(set) var isInstalling = false
    @Published private(set) var progress: ModelInstallProgress = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var samples = Array(repeating: 0.0, count: 43)
    @Published private(set) var hasPendingAudio = false
    @Published var error: String?
    @Published var selectedRecord: DictationRecord?
    @Published var copiedID: UUID?
    private let historyStore: DictationHistoryStore
    private let dictionaryStore: DictionaryStore
    private let installer = ModelInstaller()
    private let recorder = MicrophoneRecorder()
    private let pendingURL = ModelPathResolver.appSupportDirectory().appendingPathComponent("pending-dictation.wav")
    private var transcriber: LocalPianissimoTranscriber?
    private var meterTask: Task<Void, Never>?
    private var unloadTask: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--ui-testing") {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MumlaUITests", isDirectory: true)
            if CommandLine.arguments.contains("--reset-ui-data") { try? FileManager.default.removeItem(at: directory) }
            historyStore = DictationHistoryStore(directory: directory)
            dictionaryStore = DictionaryStore(directory: directory)
            if CommandLine.arguments.contains("--seed-transcript") {
                try? historyStore.clear()
                try? historyStore.append(DictationRecord(text: "An older transcript.", language: .english))
                try? historyStore.append(DictationRecord(
                    createdAt: Date(timeIntervalSince1970: 1_790_602_260),
                    text: "Vi bestämde att börja med den svenska versionen och samla in återkoppling efter första veckan. Nästa steg är att prova diktering i vardagen, justera ordlistan och gå igenom hur texten fungerar i olika appar. Alla anteckningar stannar på enheten. Vi bokar en kort avstämning på fredag för att jämföra resultaten och planera nästa steg tillsammans.",
                    language: .swedish,
                    durationMilliseconds: 17_000
                ))
            }
            if CommandLine.arguments.contains("--seed-correction") {
                try? historyStore.append(DictationRecord(text: "Kubernetis fungerar. Vi använder Kubernetis varje dag.", language: .swedish))
            }
        } else {
            historyStore = .defaultStore()
            dictionaryStore = .defaultStore()
        }
        #else
        historyStore = .defaultStore()
        dictionaryStore = .defaultStore()
        #endif
        do {
            history = try historyStore.load()
            dictionary = try dictionaryStore.load()
        } catch { self.error = error.localizedDescription }
        modelReady = ModelPathResolver.resolveCompiledPianissimoModel() != nil
        hasPendingAudio = FileManager.default.fileExists(atPath: pendingURL.path)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor [weak self] in
                if self?.state == .recording { await self?.finish() }
            }
        }
    }

    var downloadSize: String {
        let bytes = MumlaModelArtifacts.communityPianissimoCoreML.files.reduce(Int64(0)) { $0 + ($1.byteCount ?? 0) }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func install() async {
        guard !isInstalling else { return }
        isInstalling = true
        error = nil
        defer { isInstalling = false }
        do {
            _ = try await installer.install { [weak self] update in
                await MainActor.run { self?.progress = update }
            }
            modelReady = true
        } catch { self.error = error.localizedDescription }
    }

    func record() async {
        guard state == .idle, modelReady, !hasPendingAudio else { return }
        state = .requestingPermission
        guard await recorder.microphonePermissionGranted() else {
            state = .idle
            error = mText("Tillåt mikrofonen i Inställningar för att spela in.", "Allow microphone access in Settings to record.")
            return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            MumlaFeedback.recordStart()
            try audio.setCategory(.record, mode: .measurement)
            try audio.setActive(true)
            _ = try recorder.start()
            elapsed = 0
            samples = Array(repeating: 0, count: 43)
            state = .recording
            let start = Date()
            meterTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self, self.state == .recording else { return }
                    self.elapsed = Date().timeIntervalSince(start)
                    self.samples.removeFirst()
                    self.samples.append(self.recorder.inputLevel())
                    if self.elapsed >= 600 {
                        Task { await self.finish() }
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        } catch {
            state = .idle
            deactivateAudio()
            self.error = error.localizedDescription
        }
    }

    func finish() async {
        guard state == .recording else { return }
        meterTask?.cancel()
        meterTask = nil
        state = .transcribing
        do {
            let audio = try recorder.stop()
            deactivateAudio()
            MumlaFeedback.recordStop()
            try FileManager.default.createDirectory(at: pendingURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: audio, to: pendingURL)
            hasPendingAudio = true
            await transcribePending()
        } catch {
            state = .idle
            deactivateAudio()
            self.error = error.localizedDescription
        }
    }

    func transcribePending() async {
        guard hasPendingAudio else { return }
        state = .transcribing
        unloadTask?.cancel()
        defer { state = .idle; scheduleUnload() }
        do {
            if transcriber == nil, let directory = ModelPathResolver.resolveCompiledPianissimoModel() {
                transcriber = LocalPianissimoTranscriber(modelDirectory: directory)
            }
            guard let transcriber else {
                error = mText("Hämta språkmodellen först.", "Download the language model first.")
                return
            }
            let result = try await transcriber.transcribe(audioURL: pendingURL)
            let text = TranscriptNormalizer(dictionaryEntries: dictionary).normalize(result.text, language: .swedish)
            guard !text.isEmpty else {
                error = mText("Inget tal hördes. Försök igen.", "No speech detected. Try again.")
                discardPending()
                return
            }
            let record = DictationRecord(text: text, language: .swedish, durationMilliseconds: result.durationSeconds * 1000)
            history = try historyStore.append(record)
            MumlaFeedback.success()
            discardPending()
        } catch { self.error = error.localizedDescription }
    }

    func cancel() {
        guard state == .recording else { return }
        meterTask?.cancel()
        meterTask = nil
        recorder.cancel()
        deactivateAudio()
        MumlaFeedback.press()
        state = .idle
        elapsed = 0
        samples = Array(repeating: 0, count: 43)
    }

    func copy(_ record: DictationRecord) {
        UIPasteboard.general.string = record.text
        copiedID = record.id
        MumlaFeedback.success()
    }
    func addWord(original: String, replacement: String) -> Bool {
        do {
            dictionary = try dictionaryStore.add(original: original, replacement: replacement)
            MumlaFeedback.success()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
    func correctWord(_ selection: TranscriptWordSelection, replacement: String) throws {
        do {
            let result = try historyStore.correctWord(selection, replacement: replacement, dictionary: dictionaryStore)
            history = result.history
            dictionary = result.dictionary
            copiedID = nil
            MumlaFeedback.success()
        } catch {
            // Reflect persisted state even if a compensating write could not finish.
            if let records = try? historyStore.load() { history = records }
            if let entries = try? dictionaryStore.load() { dictionary = entries }
            throw error
        }
    }

    func deleteWord(_ entry: DictionaryEntry) {
        do { dictionary = try dictionaryStore.delete(id: entry.id) }
        catch { self.error = error.localizedDescription }
    }
    private func deactivateAudio() { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    private func discardPending() { try? FileManager.default.removeItem(at: pendingURL); hasPendingAudio = false }
    private func scheduleUnload() {
        unloadTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(600)) } catch { return }
            self?.transcriber = nil
        }
    }
}
