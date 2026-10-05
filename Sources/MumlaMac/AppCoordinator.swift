import AppKit
import Foundation
import MumlaAudio
import MumlaCore
import MumlaUI

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var pillState: PillState = .hidden
    @Published private(set) var inputLevel: Double = 0
    @Published private(set) var waveformSamples = Array(repeating: 0.0, count: 43)
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
    @Published private(set) var hotkeyMonitorStatus: HotkeyMonitorStatus = .stopped

    var showPill: (() -> Void)?
    var hidePill: (() -> Void)?
    var showMainWindow: (() -> Void)?
    var quit: (() -> Void)?
    var triggerKeyChanged: ((DictationTriggerKey) -> Void)?
    var requestHotkeyAccess: (() -> Void)?

    private let recorder: MicrophoneRecorder
    private var transcriber: LocalPianissimoTranscriber?
    private let modelInstaller: ModelInstaller
    private let historyStore: DictationHistoryStore
    private let dictionaryStore: DictionaryStore
    private let settingsStore: AppSettingsStore
    private let pasteboard: NSPasteboard
    private let inserter: ClipboardTextInserter
    private let correctionLearner = CorrectionLearner()
    private let editObserver = FocusedFieldEditObserver()

    private var activeMode: RecordingMode?
    private var recordingStartedAt: Date?
    private var elapsedTimer: Timer?
    private var modelInstallTask: Task<Void, Never>?
    private var hidePillTask: Task<Void, Never>?
    private var pendingStartID: UUID?
    private var insertionTarget: FocusedTextTargetSnapshot?

    init(
        recorder: MicrophoneRecorder,
        transcriber: LocalPianissimoTranscriber?,
        modelInstaller: ModelInstaller = ModelInstaller(),
        historyStore: DictationHistoryStore,
        dictionaryStore: DictionaryStore,
        settingsStore: AppSettingsStore,
        modelDirectory: URL?,
        pasteboard: NSPasteboard = .general
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.modelInstaller = modelInstaller
        self.historyStore = historyStore
        self.dictionaryStore = dictionaryStore
        self.settingsStore = settingsStore
        self.modelDirectory = modelDirectory
        self.pasteboard = pasteboard
        self.inserter = ClipboardTextInserter(pasteboard: pasteboard)
    }

    func bootstrap() {
        settings = (try? settingsStore.load()) ?? .default
        languageMode = settings.languageMode
        triggerKeyChanged?(settings.triggerKey)
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

    func updateHotkeyStatus(_ status: HotkeyMonitorStatus) {
        hotkeyMonitorStatus = status
    }

    func requestHotkeyPermission() {
        requestHotkeyAccess?()
    }

    var hotkeyStatusText: String {
        switch hotkeyMonitorStatus {
        case .active: settings.triggerKey.displayName + " " + mText("redo", "ready")
        case .stopped: mText("Dikteringstangent inaktiv", "Hotkey inactive")
        case .inputMonitoringRequired: mText("Tillåt inmatningsövervakning", "Allow Input Monitoring")
        case .unavailable: mText("Anslut dikteringstangenten igen", "Reconnect hotkey")
        }
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
        guard activeMode != nil else { pendingStartID = nil; return }
        hidePillTask?.cancel()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        inputLevel = 0

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
            let durationSeconds = durationMilliseconds.map { $0 / 1000 }
            let initialLanguage = initialTranscriptionLanguage(durationSeconds: durationSeconds)
            let rawText: String
            if let transcriber {
                let result = try await transcriber.transcribe(audioURL: audioURL, language: initialLanguage)
                rawText = result.text
            } else {
                showError("Download model first")
                return
            }

            let resolvedLanguage = resolvedLanguage(
                for: rawText,
                initialLanguage: initialLanguage,
                durationSeconds: durationSeconds
            )
            let text = currentNormalizer.normalize(rawText, language: resolvedLanguage)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                pillState = .message("Didn't catch that")
                scheduleHidePill()
                return
            }

            let record = DictationRecord(
                text: text,
                language: resolvedLanguage,
                durationMilliseconds: durationMilliseconds
            )
            history = try historyStore.append(record)
            updateLastLanguage(resolvedLanguage)

            let insertion = await inserter.insert(text, target: insertionTarget)
            presentInsertion(insertion, record: record)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func cancelDictation() {
        pendingStartID = nil
        guard activeMode != nil else { dismissPill(); return }
        recorder.cancel()
        activeMode = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        inputLevel = 0
        pillState = .message("Cancelled")
        scheduleHidePill()
    }

    func pasteRecord(_ record: DictationRecord) {
        guard activeMode == nil, pendingStartID == nil, pillState != .transcribing else { return }
        editObserver.cancel()
        let target = FocusedTextTargetInspector.captureEditableTarget()
        hidePillTask?.cancel()
        pillState = .transcribing
        showPill?()
        Task { presentInsertion(await inserter.insert(record.text, target: target), record: record) }
    }

    func copyPillTranscript() {
        guard case let .transcript(record, _) = pillState else { return }
        pasteboard.clearContents()
        let copied = pasteboard.setString(record.text, forType: .string)
        pillState = .transcript(record, copied: copied)
    }

    func dismissPill() {
        guard activeMode == nil, pillState != .transcribing else { return }
        hidePillTask?.cancel()
        pillState = .hidden
        hidePill?()
    }

    func presentInsertion(_ result: ClipboardInsertionResult, record: DictationRecord) {
        switch result {
        case .inserted:
            hidePillTask?.cancel()
            pillState = .hidden
            hidePill?()
            statusText = "Last dictation ready"
            watchForCorrectionLearning()
            return
        case let .needsCopy(copied):
            hidePillTask?.cancel()
            pillState = .transcript(record, copied: copied)
            statusText = "Transcript ready"
        case .blockedSecureField:
            hidePillTask?.cancel()
            pillState = .transcript(record, copied: false)
            statusText = "Secure field blocked"
        }
        showPill?()
    }

    func openSettings() {
        showMainWindow?()
    }

    func setLanguageMode(_ mode: LanguageMode) {
        languageMode = mode
        settings.languageMode = mode
        persistSettings()
    }

    func setTriggerKey(_ key: DictationTriggerKey) {
        guard key != settings.triggerKey else { return }
        var updated = settings
        updated.triggerKey = key
        do {
            try settingsStore.save(updated)
            cancelDictation()
            settings = updated
            triggerKeyChanged?(key)
        } catch { showError(error.localizedDescription) }
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
        pillState = .message(mText("Håll", "Hold") + " \(settings.triggerKey.displayName) " + mText("för att diktera", "to dictate"))
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

    private func initialTranscriptionLanguage(durationSeconds: Double?) -> MumlaLanguage {
        switch languageMode {
        case .swedish:
            return .swedish
        case .english:
            return .english
        case .automatic:
            if let durationSeconds, durationSeconds < 2 {
                return settings.lastLanguage
            }
            return .swedish
        }
    }

    private func resolvedLanguage(
        for transcript: String,
        initialLanguage: MumlaLanguage,
        durationSeconds: Double?
    ) -> MumlaLanguage {
        switch languageMode {
        case .swedish:
            return .swedish
        case .english:
            return .english
        case .automatic:
            let decision = LanguageRouter.route(
                LanguageRoutingInput(
                    durationSeconds: durationSeconds ?? 0,
                    mode: .automatic,
                    lastLanguage: settings.lastLanguage,
                    appleDetection: AppleTextLanguageRecognizer.detect(transcript)
                )
            )
            if decision.reason == .fallbackToLastLanguage {
                return initialLanguage
            }
            return decision.language
        }
    }

    private func updateLastLanguage(_ language: MumlaLanguage) {
        guard settings.lastLanguage != language else { return }
        settings.lastLanguage = language
        persistSettings()
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

    private func watchForCorrectionLearning() {
        editObserver.start(learner: correctionLearner) { [weak self] entry in
            guard let self else { return }
            do {
                self.dictionaryEntries = try self.dictionaryStore.add(
                    original: entry.original,
                    replacement: entry.replacement
                )
                self.statusText = "Learned \(entry.replacement)"
                self.pillState = .message("Learned \(entry.replacement)")
                self.showPill?()
                self.scheduleHidePill()
            } catch {
                self.statusText = "Dictionary update failed"
            }
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
        guard activeMode == nil, pendingStartID == nil, pillState != .transcribing else { return }
        hidePillTask?.cancel()
        editObserver.cancel()

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

        let startID = UUID()
        pendingStartID = startID
        insertionTarget = FocusedTextTargetInspector.captureEditableTarget()
        let permission = await recorder.microphonePermissionGranted()
        guard pendingStartID == startID else { return }
        pendingStartID = nil
        guard permission else {
            pillState = .message("Microphone permission needed")
            showPill?()
            scheduleHidePill()
            return
        }

        do {
            _ = try recorder.start()
            activeMode = mode
            recordingStartedAt = Date()
            waveformSamples = Array(repeating: 0, count: 43)
            pillState = mode == .quick ? .listening(elapsedSeconds: 0) : .handsFree(elapsedSeconds: 0)
            showPill?()
            startElapsedTimer(mode: mode)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func startElapsedTimer(mode: RecordingMode) {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.activeMode == mode, let startedAt = self.recordingStartedAt else { return }
                let elapsed = Date().timeIntervalSince(startedAt)
                self.inputLevel = self.recorder.inputLevel()
                self.waveformSamples.removeFirst()
                self.waveformSamples.append(min(1, self.inputLevel * 4))
                self.pillState = mode == .quick ? .listening(elapsedSeconds: elapsed) : .handsFree(elapsedSeconds: elapsed)
                if elapsed >= 600 { await self.finishDictation() }
            }
        }
    }

    private func showError(_ message: String) {
        recorder.cancel()
        pendingStartID = nil
        activeMode = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        inputLevel = 0
        pillState = .message(message)
        statusText = message
        showPill?()
        scheduleHidePill()
    }

    private func scheduleHidePill() {
        hidePillTask?.cancel()
        hidePillTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(1400)) } catch { return }
            guard let self, self.activeMode == nil, self.pendingStartID == nil,
                  case .message = self.pillState else { return }
            self.pillState = .hidden
            self.hidePill?()
        }
    }

    #if DEBUG
    func prepareRecordingSnapshot() {
        pillState = .listening(elapsedSeconds: 17)
        waveformSamples = (0..<43).map { 0.12 + abs(sin(Double($0) * 0.7)) * 0.75 }
    }
    #endif
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
    case transcript(DictationRecord, copied: Bool)
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
