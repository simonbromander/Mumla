import AppKit
import Foundation
import MumlaAudio
import MumlaCore

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var pillState: PillState = .hidden
    @Published var history: [DictationRecord] = []
    @Published var dictionaryEntries: [DictionaryEntry] = []
    @Published var languageMode: LanguageMode = .automatic
    @Published var modelDirectory: URL?
    @Published var statusText: String = "Ready"

    var showPill: (() -> Void)?
    var hidePill: (() -> Void)?
    var showMainWindow: (() -> Void)?
    var quit: (() -> Void)?

    private let recorder: MicrophoneRecorder
    private let transcriber: LocalPianissimoTranscriber?
    private let historyStore: DictationHistoryStore
    private let inserter = ClipboardTextInserter()
    private let normalizer = TranscriptNormalizer()

    private var activeMode: RecordingMode?
    private var recordingStartedAt: Date?
    private var elapsedTimer: Timer?

    init(
        recorder: MicrophoneRecorder,
        transcriber: LocalPianissimoTranscriber?,
        historyStore: DictationHistoryStore,
        modelDirectory: URL?
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.historyStore = historyStore
        self.modelDirectory = modelDirectory
    }

    func bootstrap() {
        history = (try? historyStore.load()) ?? []
        statusText = modelDirectory == nil ? "Model missing" : "Ready"
    }

    func requestMicrophonePermission() async {
        let granted = await recorder.microphonePermissionGranted()
        statusText = granted ? "Microphone ready" : "Microphone permission needed"
    }

    func requestAccessibilityPermission() {
        AccessibilityPermission.request()
        statusText = AccessibilityPermission.isTrusted ? "Accessibility ready" : "Accessibility permission needed"
    }

    func startQuickDictation() async {
        await startDictation(mode: .quick)
    }

    func toggleHandsFreeDictation() async {
        if activeMode == .handsFree {
            await finishDictation()
        } else if activeMode == nil {
            await startDictation(mode: .handsFree)
        }
    }

    func controlTapped() async {
        if activeMode == .handsFree {
            await finishDictation()
        }
    }

    func finishDictation() async {
        guard activeMode != nil else { return }
        elapsedTimer?.invalidate()
        elapsedTimer = nil

        let audioURL: URL
        do {
            audioURL = try recorder.stop()
        } catch {
            showError(error.localizedDescription)
            return
        }

        let durationMilliseconds = recordingStartedAt.map { Date().timeIntervalSince($0) * 1000 }
        activeMode = nil
        pillState = .transcribing
        showPill?()

        do {
            let rawText: String
            if let transcriber {
                let result = try await transcriber.transcribe(audioURL: audioURL, language: selectedLanguage)
                rawText = result.text
            } else {
                rawText = "Mumla is ready, but no local model is staged yet."
            }

            let text = normalizer.normalize(rawText, language: selectedLanguage)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                pillState = .message("Didn't catch that")
                scheduleHidePill()
                return
            }

            let record = DictationRecord(
                text: text,
                language: selectedLanguage,
                durationMilliseconds: durationMilliseconds
            )
            history = try historyStore.append(record)

            let insertion = inserter.insert(text)
            switch insertion {
            case .inserted:
                pillState = .message("Inserted")
            case .copied:
                pillState = .message("Copied - Command-V to paste")
            }
            statusText = "Last dictation ready"
            scheduleHidePill()
        } catch {
            showError(error.localizedDescription)
        }
    }

    func cancelDictation() {
        guard activeMode != nil else { return }
        recorder.cancel()
        activeMode = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        pillState = .message("Cancelled")
        scheduleHidePill()
    }

    func pasteRecord(_ record: DictationRecord) {
        _ = inserter.insert(record.text)
    }

    func openSettings() {
        showMainWindow?()
    }

    func setLanguageMode(_ mode: LanguageMode) {
        languageMode = mode
    }

    private var selectedLanguage: MumlaLanguage {
        switch languageMode {
        case .automatic, .swedish:
            return .swedish
        case .english:
            return .english
        }
    }

    private func startDictation(mode: RecordingMode) async {
        guard activeMode == nil else { return }

        guard await recorder.microphonePermissionGranted() else {
            pillState = .message("Microphone permission needed")
            showPill?()
            scheduleHidePill()
            return
        }

        do {
            _ = try recorder.start()
            activeMode = mode
            recordingStartedAt = Date()
            pillState = mode == .quick ? .listening(elapsedSeconds: 0) : .handsFree(elapsedSeconds: 0)
            showPill?()
            startElapsedTimer(mode: mode)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func startElapsedTimer(mode: RecordingMode) {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.activeMode == mode, let startedAt = self.recordingStartedAt else { return }
                let elapsed = Date().timeIntervalSince(startedAt)
                self.pillState = mode == .quick ? .listening(elapsedSeconds: elapsed) : .handsFree(elapsedSeconds: elapsed)
            }
        }
    }

    private func showError(_ message: String) {
        activeMode = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        pillState = .message(message)
        statusText = message
        showPill?()
        scheduleHidePill()
    }

    private func scheduleHidePill() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if self.activeMode == nil {
                self.pillState = .hidden
                self.hidePill?()
            }
        }
    }
}

enum RecordingMode {
    case quick
    case handsFree
}

enum PillState: Equatable {
    case hidden
    case listening(elapsedSeconds: TimeInterval)
    case handsFree(elapsedSeconds: TimeInterval)
    case transcribing
    case message(String)
}
