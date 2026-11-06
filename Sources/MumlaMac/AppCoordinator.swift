import AppKit
import AVFoundation
import Carbon
import Foundation
import MumlaAudio
import MumlaCore
import MumlaFormatting
import MumlaUI

@MainActor
final class AppCoordinator: ObservableObject {
    let textModel: QwenTextModel
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
    @Published private(set) var djiMicButtonStatus: DJIMicButtonStatus = .off
    @Published var hotkeyGestureStage: HotkeyGestureStage = .waiting
    @Published private(set) var settingsOpenRequest: UUID?
    @Published private(set) var isBusyForAppUpdate = false
    @Published private(set) var inputDevices: [AudioInputDevice] = []
    @Published private(set) var isFormattingDictation = false
    @Published private(set) var dictationFormattingStatus: String?
    private(set) var lastRecordingStartupMilliseconds: Double?
    private(set) var isInstallingAppUpdate = false

    var showPill: (() -> Void)?
    var hidePill: (() -> Void)?
    var showMainWindow: (() -> Void)?
    var quit: (() -> Void)?
    var triggerKeyChanged: ((DictationTriggerKey) -> Void)?
    var requestHotkeyAccess: (() -> Void)?
    var djiMicButtonEnabledChanged: ((Bool) -> Void)?
    var requestDJIMicAccess: (() -> Void)?
    var retryDJIMicButton: (() -> Void)?
    var quitDJIMicHelper: (() -> Void)?

    private let recorder: MicrophoneRecorder
    private var transcriber: LocalPianissimoTranscriber?
    private let modelInstaller: ModelInstaller
    private let historyStore: DictationHistoryStore
    private let dictionaryStore: DictionaryStore
    private let settingsStore: AppSettingsStore
    private let pasteboard: NSPasteboard
    private let inserter: ClipboardTextInserter
    private let dictationFormatter: LocalTranscriptFormatter
    private let textPreferences: UserDefaults
    private var formattingTask: Task<FormattingResult, Never>?
    private let correctionLearner = CorrectionLearner()
    private let editObserver = FocusedFieldEditObserver()

    private var activeMode: RecordingMode? {
        didSet {
            if activeMode == nil { activeDJIMicReceiverID = nil }
            refreshUpdateActivity()
        }
    }
    private var activeDJIMicReceiverID: UInt64?
    private var pendingDJIMicStart: (id: UUID, receiverID: UInt64)?
    private var recordingStartedAt: Date?
    private var elapsedTimer: Timer?
    private var modelInstallTask: Task<Void, Never>? { didSet { refreshUpdateActivity() } }
    private var hidePillTask: Task<Void, Never>?
    private var pasteVerificationTask: Task<Void, Never>?
    private var pendingStartID: UUID? { didSet { refreshUpdateActivity() } }
    private var inFlightOperations = 0 { didSet { refreshUpdateActivity() } }
    private var insertionTarget: FocusedTextTargetSnapshot?
    private var inputDeviceObserver: AnyObject?

    init(
        recorder: MicrophoneRecorder,
        transcriber: LocalPianissimoTranscriber?,
        modelInstaller: ModelInstaller = ModelInstaller(),
        historyStore: DictationHistoryStore,
        dictionaryStore: DictionaryStore,
        settingsStore: AppSettingsStore,
        modelDirectory: URL?,
        pasteboard: NSPasteboard = .general,
        inserter: ClipboardTextInserter? = nil,
        textModel: QwenTextModel = QwenTextModel(),
        dictationFormatter: LocalTranscriptFormatter? = nil,
        textPreferences: UserDefaults = .standard
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.modelInstaller = modelInstaller
        self.historyStore = historyStore
        self.dictionaryStore = dictionaryStore
        self.settingsStore = settingsStore
        self.modelDirectory = modelDirectory
        self.pasteboard = pasteboard
        self.inserter = inserter ?? ClipboardTextInserter(pasteboard: pasteboard)
        self.textModel = textModel
        self.dictationFormatter = dictationFormatter ?? textModel.formatter
        self.textPreferences = textPreferences
    }

    func bootstrap() {
        settings = (try? settingsStore.load()) ?? .default
        languageMode = settings.languageMode
        triggerKeyChanged?(settings.triggerKey)
        djiMicButtonEnabledChanged?(settings.djiMicButtonEnabled)
        refreshLaunchAtLoginStatus()
        history = (try? historyStore.load()) ?? []
        dictionaryEntries = (try? dictionaryStore.load()) ?? []
        refreshInputDevices()
        inputDeviceObserver = AudioInputDevices.observeChanges { [weak self] in
            Task { @MainActor in self?.refreshInputDevices() }
        }
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

    func setAppUpdateInstallationInProgress(_ inProgress: Bool) {
        isInstallingAppUpdate = inProgress
    }

    private func refreshUpdateActivity() {
        let busy = activeMode != nil || pendingStartID != nil || inFlightOperations > 0 || modelInstallTask != nil
        if isBusyForAppUpdate != busy { isBusyForAppUpdate = busy }
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

    func updateDJIMicButtonStatus(_ status: DJIMicButtonStatus) { djiMicButtonStatus = status }

    var djiMicButtonStatusText: String {
        switch djiMicButtonStatus {
        case .off: mText("Av", "Off")
        case .paused: mText("Pausad", "Paused")
        case .permissionRequired: mText("Tillåt inmatningsövervakning", "Allow Input Monitoring")
        case .waitingForReceiver: mText("Anslut mottagaren via USB", "Connect the receiver by USB")
        case .ready: mText("Knappen är redo", "Button ready")
        case .receiverUnavailable: mText("Mottagaren är upptagen eller otillgänglig", "Receiver busy or unavailable")
        case .helperRunning: mText("Avsluta DJI Mic Mumla", "Quit DJI Mic Mumla")
        }
    }

    func setDJIMicButtonEnabled(_ enabled: Bool) {
        guard settings.djiMicButtonEnabled != enabled else { return }
        var updated = settings
        updated.djiMicButtonEnabled = enabled
        do {
            try settingsStore.save(updated)
            settings = updated
            if !enabled, pendingStartID == pendingDJIMicStart?.id { pendingStartID = nil; pendingDJIMicStart = nil }
            djiMicButtonEnabledChanged?(enabled)
            if enabled { requestDJIMicAccess?() }
        } catch { statusText = "Settings save failed" }
    }

    func djiMicButtonPressed(receiverID: UInt64) async {
        guard settings.djiMicButtonEnabled else { return }
        if pendingStartID != nil {
            pendingStartID = nil
            pendingDJIMicStart = nil
        } else if activeMode != nil {
            await finishDictation()
        } else if IsSecureEventInputEnabled() {
            showSecureInputWarning()
        } else {
            await startDictation(mode: .handsFree, djiReceiverID: receiverID)
        }
    }

    func djiMicReceiverDisconnected(_ receiverID: UInt64) async {
        if pendingDJIMicStart?.receiverID == receiverID, pendingDJIMicStart?.id == pendingStartID {
            pendingStartID = nil
            pendingDJIMicStart = nil
        }
        if activeDJIMicReceiverID == receiverID { await finishDictation() }
    }

    var hotkeyStatusText: String {
        switch hotkeyMonitorStatus {
        case .active: settings.triggerKey.displayName + " " + mText("redo", "ready")
        case .stopped: mText("Dikteringstangent inaktiv", "Hotkey inactive")
        case .inputMonitoringRequired: mText("Tillåt inmatningsövervakning", "Allow Input Monitoring")
        case .unavailable: mText("Anslut dikteringstangenten igen", "Reconnect hotkey")
        }
    }

    var hotkeyDiagnosticText: String {
        switch hotkeyGestureStage {
        case .waiting: mText("Ingen tangent mottagen", "No trigger received")
        case .pressed: mText("Tangent nedtryckt", "Trigger pressed")
        case .holdStarted: mText("Hålltryck mottaget", "Hold received")
        case .released: mText("Tangent släppt", "Trigger released")
        case .handsFree: mText("Dubbeltryck mottaget", "Double-tap received")
        case .cancelled: mText("Kortkommando avbröt", "Shortcut cancelled")
        case .secureInputBlocked: mText("Säker inmatning blockerar", "Secure Input blocks hotkey")
        }
    }

    func copyHotkeyDiagnostics() {
        let info = Bundle.main.infoDictionary ?? [:]
        let microphone = switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: "authorized"
        case .denied: "denied"
        case .restricted: "restricted"
        case .notDetermined: "not requested"
        @unknown default: "unknown"
        }
        let diagnostic = [
            "Mumla \(info["CFBundleShortVersionString"] ?? "dev") (\(info["CFBundleVersion"] ?? "dev"))",
            "Distribution: \(info["MumlaDistribution"] ?? "dev")",
            "Bundle: \(Bundle.main.bundleIdentifier ?? "unbundled")",
            "Trigger: \(settings.triggerKey.rawValue)",
            "Input Monitoring: \(CGPreflightListenEventAccess())",
            "Accessibility: \(AccessibilityPermission.isTrusted)",
            "Secure Input: \(IsSecureEventInputEnabled())",
            "Microphone: \(microphone)",
            "Listener: \(hotkeyMonitorStatus)",
            "DJI button: \(settings.djiMicButtonEnabled ? String(describing: djiMicButtonStatus) : "off")",
            "Gesture: \(hotkeyGestureStage.rawValue)",
            "Paste: \(inserter.lastOutcome.rawValue)",
            "Model installed: \(modelDirectory != nil)",
            "Recording startup: \(lastRecordingStartupMilliseconds.map { String(format: "%.0f ms (after gesture)", $0) } ?? "not measured")",
            "Working: \(isBusyForAppUpdate)"
        ].joined(separator: "\n")
        pasteboard.clearContents()
        _ = pasteboard.setString(diagnostic, forType: .string)
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
        inFlightOperations += 1
        defer { inFlightOperations -= 1 }
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

            try await completeDictation(DictationRecord(
                text: text,
                language: resolvedLanguage,
                durationMilliseconds: durationMilliseconds
            ), target: insertionTarget)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func completeDictation(_ original: DictationRecord, target: FocusedTextTargetSnapshot?) async throws {
        inFlightOperations += 1
        defer { inFlightOperations -= 1 }
        history = try historyStore.append(original)
        updateLastLanguage(original.language)
        dictationFormattingStatus = nil
        var record = original
        if settings.formatDictationBeforePasting {
            isFormattingDictation = true
            pillState = .transcribing
            showPill?()
            let formatter = dictationFormatter
            let prompt = textPreferences.string(forKey: LocalTextPreferences.formattingKey) ?? ""
            let task = Task {
                // A user-triggered dictation is explicit work even when another app owns focus.
                await formatter.format(original.text, language: original.language, foreground: true, stylePrompt: prompt)
            }
            formattingTask = task
            let result = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
            formattingTask = nil
            isFormattingDictation = false
            textModel.refresh()
            if result.status == .cancelled || Task.isCancelled {
                dictationFormattingStatus = mText("Avbrutet. Originalet finns i historiken.", "Cancelled. Original saved in History.")
                pillState = .message(mText("Avbrutet", "Cancelled"))
                scheduleHidePill()
                return
            }
            dictationFormattingStatus = formattingStatusText(result.status)
            if result.status == .formatted {
                do {
                    let updated = try historyStore.applyFormatting(recordID: original.id, expectedText: original.text, formattedText: result.text)
                    if let formatted = updated.first(where: { $0.id == original.id }) {
                        history = updated
                        record = formatted
                    }
                } catch {
                    dictationFormattingStatus = mText("Kunde inte spara formatering. Använder originalet.", "Couldn't save formatting. Using the original.")
                }
            }
        }
        guard !Task.isCancelled else { return }
        presentInsertion(await inserter.insert(record.text, target: target), record: record)
    }

    private func formattingStatusText(_ status: FormattingStatus) -> String {
        switch status {
        case .formatted: mText("Formaterat före inklistring", "Formatted before pasting")
        case .unchanged: mText("Inga formateringsändringar behövdes", "No formatting changes needed")
        case .unavailable: mText("Textmodellen är inte redo. Använder originalet.", "Text model not ready. Using the original.")
        case .unsafeOutput: mText("Förslaget ändrade ord. Använder originalet.", "Suggestion changed words. Using the original.")
        case .tooLong: mText("För långt för textmodellen. Använder originalet.", "Too long for the text model. Using the original.")
        default: mText("Formatering misslyckades. Använder originalet.", "Formatting failed. Using the original.")
        }
    }

    func cancelDictation() {
        pendingStartID = nil
        if let formattingTask { formattingTask.cancel(); return }
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
        guard canPasteFromHistory else { return }
        pasteRecord(record, target: FocusedTextTargetInspector.captureEditableTarget())
    }

    var canPasteFromHistory: Bool {
        !isInstallingAppUpdate && activeMode == nil && pendingStartID == nil && inFlightOperations == 0 && pillState != .transcribing
    }

    func pasteRecord(_ record: DictationRecord, target: FocusedTextTargetSnapshot?) {
        guard canPasteFromHistory else { return }
        pasteVerificationTask?.cancel()
        editObserver.cancel()
        hidePillTask?.cancel()
        pillState = .transcribing
        showPill?()
        inFlightOperations += 1
        Task {
            defer { inFlightOperations -= 1 }
            presentInsertion(await inserter.insert(record.text, target: target), record: record)
        }
    }

    func copyPillTranscript() {
        guard case let .transcript(record, _) = pillState else { return }
        pasteboard.clearContents()
        let copied = pasteboard.setString(record.text, forType: .string)
        pillState = .transcript(record, copied: copied)
    }

    func dismissPill() {
        guard activeMode == nil, pillState != .transcribing else { return }
        pasteVerificationTask?.cancel()
        hidePillTask?.cancel()
        pillState = .hidden
        hidePill?()
    }

    func presentInsertion(_ result: ClipboardInsertionResult, record: DictationRecord) {
        pasteVerificationTask?.cancel()
        switch result {
        case .inserted:
            hidePillTask?.cancel()
            pillState = .hidden
            hidePill?()
            statusText = "Last dictation ready"
            watchForCorrectionLearning()
            return
        case let .needsCopy(copied):
            if !settings.showPasteDialog {
                finishClipboardFallback(record, alreadyCopied: copied)
                return
            }
            hidePillTask?.cancel()
            pillState = .transcript(record, copied: copied)
            statusText = "Transcript ready"
            pasteVerificationTask = Task { [weak self] in
                guard let self, await self.inserter.confirmPendingInsertion(record.text), !Task.isCancelled,
                      case let .transcript(current, _) = self.pillState, current.id == record.id else { return }
                self.presentInsertion(.inserted, record: record)
            }
        case .blockedSecureField:
            if !settings.showPasteDialog {
                finishClipboardFallback(record)
                return
            }
            hidePillTask?.cancel()
            pillState = .transcript(record, copied: false)
            statusText = "Secure field blocked"
        }
        showPill?()
    }

    private func finishClipboardFallback(_ record: DictationRecord, alreadyCopied: Bool = false) {
        pasteVerificationTask?.cancel()
        hidePillTask?.cancel()
        let outcome = alreadyCopied ? .copied : inserter.copyFallbackTranscript(record.text)
        switch outcome {
        case .copied: statusText = mText("Kopierat till urklipp", "Copied to clipboard")
        case .clipboardChanged: statusText = mText("Urklipp har ändrats. Transkriptet finns i historiken.", "Clipboard changed. Transcript saved in history.")
        case .unavailable: statusText = mText("Kunde inte kopiera. Transkriptet finns i historiken.", "Couldn't copy. Transcript saved in history.")
        }
        pillState = .hidden
        hidePill?()
    }

    func setShowPasteDialog(_ enabled: Bool) {
        guard settings.showPasteDialog != enabled else { return }
        var updated = settings
        updated.showPasteDialog = enabled
        do {
            try settingsStore.save(updated)
            settings = updated
            if !enabled, case let .transcript(record, copied) = pillState {
                finishClipboardFallback(record, alreadyCopied: copied)
            }
        } catch {
            statusText = "Settings save failed"
        }
    }

    func setFormatDictationBeforePasting(_ enabled: Bool) {
        guard settings.formatDictationBeforePasting != enabled else { return }
        var updated = settings
        updated.formatDictationBeforePasting = enabled
        do {
            try settingsStore.save(updated)
            settings = updated
            dictationFormattingStatus = nil
        } catch { statusText = "Settings save failed" }
    }

    func setDictationOverlayStyle(_ style: DictationOverlayStyle) {
        guard settings.dictationOverlayStyle != style else { return }
        var updated = settings
        updated.dictationOverlayStyle = style
        do {
            try settingsStore.save(updated)
            settings = updated
            if pillState != .hidden { showPill?() }
        } catch { statusText = "Settings save failed" }
    }

    /// Pins dictation to `device`, or follows the system default input when `nil`.
    func setPinnedInputDevice(_ device: AudioInputDevice?) {
        let pinned = device.map { PinnedInputDevice(uid: $0.uid, name: $0.name) }
        guard settings.pinnedInputDevice != pinned else { return }
        var updated = settings
        updated.pinnedInputDevice = pinned
        do {
            try settingsStore.save(updated)
            settings = updated
        } catch {
            statusText = "Settings save failed"
        }
    }

    func isPinnedInputDevice(_ device: AudioInputDevice) -> Bool {
        guard let pinned = settings.pinnedInputDevice else { return false }
        return AudioInputDevices.match(pinned, in: inputDevices) == device
    }

    var isPinnedInputDeviceConnected: Bool {
        guard let pinned = settings.pinnedInputDevice else { return false }
        return AudioInputDevices.match(pinned, in: inputDevices) != nil
    }

    private func refreshInputDevices() {
        let devices = AudioInputDevices.available()
        if devices != inputDevices { inputDevices = devices }
    }

    /// UID of the remembered microphone if it's connected now, following it to a new UID if needed.
    private func connectedPinnedInputDeviceUID() -> String? {
        guard let pinned = settings.pinnedInputDevice else { return nil }
        // The device-list observer maintains this cache; the recorder revalidates the UID at start.
        guard let device = AudioInputDevices.match(pinned, in: inputDevices) else { return nil }
        if device.uid != pinned.uid || device.name != pinned.name {
            var updated = settings
            updated.pinnedInputDevice = PinnedInputDevice(uid: device.uid, name: device.name)
            if (try? settingsStore.save(updated)) != nil { settings = updated }
        }
        return device.uid
    }

    func openSettings() {
        settingsOpenRequest = UUID()
        isOnboardingVisible = false
        showMainWindow?()
    }

    func openMainWindow() {
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

    func applyFormatting(_ record: DictationRecord, text: String) throws {
        history = try historyStore.applyFormatting(recordID: record.id, expectedText: record.text, formattedText: text)
    }

    func applySummary(_ record: DictationRecord, text: String) throws {
        history = try historyStore.applySummary(recordID: record.id, expectedText: record.text, summary: text)
    }

    func restoreOriginal(_ record: DictationRecord) {
        do { history = try historyStore.restoreOriginal(recordID: record.id, expectedText: record.text) }
        catch { showError(error.localizedDescription) }
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
        guard !isInstallingAppUpdate, modelInstallTask == nil else { return }

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

    private func startDictation(mode: RecordingMode, djiReceiverID: UInt64? = nil) async {
        guard !isInstallingAppUpdate, activeMode == nil, pendingStartID == nil, inFlightOperations == 0, pillState != .transcribing else { return }
        let startup = ContinuousClock.now
        pasteVerificationTask?.cancel()
        hidePillTask?.cancel()
        editObserver.cancel()

        let focus = FocusedTextTargetInspector.captureForDictation()
        if focus.focus == .secureText {
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
        if let djiReceiverID { pendingDJIMicStart = (startID, djiReceiverID) }
        defer { if pendingDJIMicStart?.id == startID { pendingDJIMicStart = nil } }
        insertionTarget = focus.target
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
            _ = try recorder.start(inputDeviceUID: connectedPinnedInputDeviceUID())
            let elapsed = startup.duration(to: .now).components
            lastRecordingStartupMilliseconds = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
            activeDJIMicReceiverID = djiReceiverID
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

    /// Explains why the trigger key did nothing; dictation already in progress keeps its pill.
    /// macOS doesn't reliably report which app holds Secure Input, so the message names none.
    func showSecureInputWarning() {
        guard activeMode == nil, pendingStartID == nil else { return }
        switch pillState {
        case .hidden, .message: break
        default: return
        }
        pillState = .message(Self.secureInputWarning)
        showPill?()
        scheduleHidePill(after: .seconds(4))
    }

    static let secureInputWarning = mText(
        "Säker inmatning är på. Stäng lösenordshanterare och lösenordsfält.",
        "Secure Input is on. Close password managers and password fields."
    )

    private func scheduleHidePill(after delay: Duration = .milliseconds(1400)) {
        hidePillTask?.cancel()
        hidePillTask = Task { [weak self] in
            do { try await Task.sleep(for: delay) } catch { return }
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
