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
    @Published var settings: AppSettings = .default
    @Published var isOnboardingVisible = false
    @Published var onboardingStep: OnboardingStep = .value
    @Published var launchAtLoginStatus: LaunchAtLoginStatus = .disabled
    @Published var modelDirectory: URL?
    @Published var modelInstallProgress: ModelInstallProgress = .idle
    @Published var statusText: String = "Ready"

    var showPill: (() -> Void)?
    var hidePill: (() -> Void)?
    var showMainWindow: (() -> Void)?
    var quit: (() -> Void)?

    private let recorder: MicrophoneRecorder
    private var transcriber: LocalPianissimoTranscriber?
    private let modelInstaller: ModelInstaller
    private let historyStore: DictationHistoryStore
    private let dictionaryStore: DictionaryStore
    private let settingsStore: AppSettingsStore
    private let inserter = ClipboardTextInserter()

    private var activeMode: RecordingMode?
    private var recordingStartedAt: Date?
    private var elapsedTimer: Timer?
    private var modelInstallTask: Task<Void, Never>?

    init(
        recorder: MicrophoneRecorder,
        transcriber: LocalPianissimoTranscriber?,
        modelInstaller: ModelInstaller = ModelInstaller(),
        historyStore: DictationHistoryStore,
        dictionaryStore: DictionaryStore,
        settingsStore: AppSettingsStore,
        modelDirectory: URL?
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.modelInstaller = modelInstaller
        self.historyStore = historyStore
        self.dictionaryStore = dictionaryStore
        self.settingsStore = settingsStore
        self.modelDirectory = modelDirectory
    }

    func bootstrap() {
        settings = (try? settingsStore.load()) ?? .default
        languageMode = settings.languageMode
        refreshLaunchAtLoginStatus()
        history = (try? historyStore.load()) ?? []
        dictionaryEntries = (try? dictionaryStore.load()) ?? []
        statusText = modelDirectory == nil ? "Model missing" : "Ready"

        if !settings.onboardingCompleted {
            isOnboardingVisible = true
            onboardingStep = .value
            showMainWindow?()
        }
    }

    var isInstallingModel: Bool {
        modelInstallTask != nil
    }

    var isLaunchAtLoginRequested: Bool {
        launchAtLoginStatus.isRequested
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
                showError("Download model first")
                return
            }

            let text = currentNormalizer.normalize(rawText, language: selectedLanguage)
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
                statusText = "Last dictation ready"
            case .copied:
                pillState = .message("Copied - Command-V to paste")
                statusText = "Copied to clipboard"
            case .blockedSecureField:
                pillState = .message("Secure field")
                statusText = "Secure field blocked"
            }
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
        settings.languageMode = mode
        persistSettings()
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            launchAtLoginStatus = try LaunchAtLoginController.setEnabled(isEnabled)
            settings.launchAtLogin = launchAtLoginStatus.isRequested
            persistSettings()
            statusText = launchAtLoginStatus == .requiresApproval ? "Approve in System Settings" : "Launch at login \(launchAtLoginStatus.title.lowercased())"
        } catch {
            refreshLaunchAtLoginStatus()
            statusText = error.localizedDescription
        }
    }

    func addDictionaryEntry(original: String, replacement: String) {
        do {
            dictionaryEntries = try dictionaryStore.add(original: original, replacement: replacement)
            statusText = "Dictionary updated"
        } catch {
            showError(error.localizedDescription)
        }
    }

    func deleteDictionaryEntry(_ entry: DictionaryEntry) {
        do {
            dictionaryEntries = try dictionaryStore.delete(id: entry.id)
            statusText = "Dictionary updated"
        } catch {
            showError(error.localizedDescription)
        }
    }

    func showOnboarding() {
        onboardingStep = .value
        isOnboardingVisible = true
        showMainWindow?()
    }

    func advanceOnboarding() {
        guard let next = onboardingStep.next else {
            completeOnboarding()
            return
        }
        onboardingStep = next
    }

    func retreatOnboarding() {
        if let previous = onboardingStep.previous {
            onboardingStep = previous
        }
    }

    func completeOnboarding() {
        settings.onboardingCompleted = true
        persistSettings()
        isOnboardingVisible = false
        statusText = modelDirectory == nil ? "Model missing" : "Ready"
    }

    func showPracticePill() {
        pillState = .message("Hold Ctrl to dictate")
        showPill?()
        scheduleHidePill()
    }

    func installModel() {
        guard modelInstallTask == nil else { return }

        modelInstallTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.modelInstallProgress = ModelInstallProgress(
                    phase: .downloading,
                    fraction: 0,
                    detail: "Starting download"
                )
                self.statusText = "Downloading model"
                self.pillState = .preparing(progress: 0)
                self.showPill?()
            }

            do {
                let directory = try await self.modelInstaller.install { [weak self] progress in
                    await MainActor.run {
                        guard let self else { return }
                        self.modelInstallProgress = progress
                        self.statusText = progress.statusTitle
                        if progress.phase == .downloading || progress.phase == .compiling {
                            self.pillState = .preparing(progress: progress.fraction)
                            self.showPill?()
                        }
                    }
                }

                await MainActor.run {
                    self.modelDirectory = directory
                    self.transcriber = LocalPianissimoTranscriber(modelDirectory: directory)
                    self.statusText = "Ready"
                    self.pillState = .message("Model ready")
                    self.showPill?()
                    self.scheduleHidePill()
                    self.modelInstallTask = nil
                }
            } catch {
                await MainActor.run {
                    self.modelInstallProgress = ModelInstallProgress(
                        phase: .failed,
                        fraction: self.modelInstallProgress.fraction,
                        detail: error.localizedDescription
                    )
                    self.statusText = "Model install failed"
                    self.pillState = .message("Model install failed")
                    self.showPill?()
                    self.scheduleHidePill()
                    self.modelInstallTask = nil
                }
            }
        }
    }

    private var selectedLanguage: MumlaLanguage {
        switch languageMode {
        case .automatic, .swedish:
            return .swedish
        case .english:
            return .english
        }
    }

    private var currentNormalizer: TranscriptNormalizer {
        TranscriptNormalizer(dictionaryEntries: dictionaryEntries)
    }

    private func persistSettings() {
        do {
            try settingsStore.save(settings)
        } catch {
            statusText = "Settings save failed"
        }
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = LaunchAtLoginController.currentStatus()
        if settings.launchAtLogin != launchAtLoginStatus.isRequested {
            settings.launchAtLogin = launchAtLoginStatus.isRequested
            persistSettings()
        }
    }

    private func startDictation(mode: RecordingMode) async {
        guard activeMode == nil else { return }

        if FocusedTextTargetInspector.inspect() == .secureText {
            statusText = "Secure input active"
            return
        }

        guard transcriber != nil else {
            if isInstallingModel {
                pillState = .preparing(progress: modelInstallProgress.fraction)
            } else {
                pillState = .message("Download model first")
                showMainWindow?()
            }
            showPill?()
            scheduleHidePill()
            return
        }

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
    case preparing(progress: Double)
    case listening(elapsedSeconds: TimeInterval)
    case handsFree(elapsedSeconds: TimeInterval)
    case transcribing
    case message(String)
}

enum OnboardingStep: Int, CaseIterable {
    case value
    case microphone
    case accessibility
    case practice
    case done

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

private extension ModelInstallProgress {
    var statusTitle: String {
        switch phase {
        case .idle:
            return "Model missing"
        case .downloading:
            return "Downloading model \(Int((fraction * 100).rounded()))%"
        case .verifying:
            return "Verifying model"
        case .compiling:
            return "Preparing model \(Int((fraction * 100).rounded()))%"
        case .installed:
            return "Ready"
        case .failed:
            return "Model install failed"
        }
    }
}
