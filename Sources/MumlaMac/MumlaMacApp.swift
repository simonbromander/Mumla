import AppKit
import Foundation
import MumlaAudio
import MumlaCore
import MumlaFormatting
import MumlaUI
import SwiftUI

@main
@MainActor
final class MumlaMacApp: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator!
    private var statusController: StatusMenuController!
    private var mainWindowController: MainWindowController!
    private var pillWindowController: PillWindowController!
    private var meetingPromptController: MeetingPromptWindowController?
    private var hotkeyMonitor: ControlHotkeyMonitor!
    private var djiMicMonitor: DJIMicButtonMonitor!
    private var updater: MacUpdateController!
    private var hotkeyIsSuspended = false
    private var quitConfirmationIsShowing = false

    static func main() {
        let app = NSApplication.shared
        let delegate = MumlaMacApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if CommandLine.arguments.contains("--meeting-ui-testing") {
            launchMeetingUITests()
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--design-snapshot"),
           CommandLine.arguments.indices.contains(index + 1) {
            captureDesign(at: CommandLine.arguments[index + 1])
            NSApp.terminate(nil)
            return
        }
        if Bundle.main.bundleIdentifier == "com.mumla.app.mac.uitesthost" {
            NSApp.terminate(nil)
            return
        }
        #endif
        let storageDirectory = MacStorageDirectory.resolve()
        let compiledDirectory = storageDirectory.appendingPathComponent("Models/markstrom-pianissimo-sv-coreml-compiled", isDirectory: true)
        let historyStore = DictationHistoryStore(directory: storageDirectory)
        let modelDirectory = ModelPathResolver.isCompiledPianissimoModel(at: compiledDirectory)
            ? compiledDirectory : ModelPathResolver.resolveCompiledPianissimoModel()
        let transcriber = modelDirectory.map(LocalPianissimoTranscriber.init(modelDirectory:))

        coordinator = AppCoordinator(
            recorder: MicrophoneRecorder(),
            transcriber: transcriber,
            modelInstaller: ModelInstaller(
                downloadDirectory: storageDirectory.appendingPathComponent("Downloads/markstrom-pianissimo-sv-coreml", isDirectory: true),
                compiledDirectory: compiledDirectory
            ),
            historyStore: historyStore,
            dictionaryStore: DictionaryStore(directory: storageDirectory),
            settingsStore: AppSettingsStore(directory: storageDirectory),
            modelDirectory: modelDirectory,
            textModel: QwenTextModel(directory: storageDirectory.appendingPathComponent(
                "Models/Qwen3.5-4B/\(QwenModelArtifact.revision)", isDirectory: true))
        )
        pillWindowController = PillWindowController(coordinator: coordinator)
        meetingPromptController = MeetingPromptWindowController(detection: coordinator.meetingDetection)
        updater = MacUpdateController(coordinator: coordinator)
        mainWindowController = MainWindowController(coordinator: coordinator, updater: updater)
        statusController = StatusMenuController(coordinator: coordinator, updater: updater)
        hotkeyMonitor = ControlHotkeyMonitor()
        coordinator.triggerKeyChanged = { [weak hotkeyMonitor] key in hotkeyMonitor?.setTriggerKey(key) }
        coordinator.requestHotkeyAccess = { [weak hotkeyMonitor] in hotkeyMonitor?.requestPermission() }
        hotkeyMonitor.onStatusChanged = { [weak coordinator] status in coordinator?.updateHotkeyStatus(status) }
        hotkeyMonitor.onGestureStageChanged = { [weak coordinator] stage in coordinator?.hotkeyGestureStage = stage }
        djiMicMonitor = DJIMicButtonMonitor()
        coordinator.djiMicButtonEnabledChanged = { [weak djiMicMonitor] in djiMicMonitor?.setEnabled($0) }
        coordinator.requestDJIMicAccess = { [weak djiMicMonitor] in djiMicMonitor?.requestPermission() }
        coordinator.retryDJIMicButton = { [weak djiMicMonitor] in djiMicMonitor?.refresh(forceRestart: true) }
        coordinator.quitDJIMicHelper = {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: DJIMicButtonMonitor.legacyHelperBundleID) {
                _ = app.terminate()
            }
        }
        djiMicMonitor.onStatusChanged = { [weak coordinator] in coordinator?.updateDJIMicButtonStatus($0) }
        djiMicMonitor.onPress = { [weak coordinator] in await coordinator?.djiMicButtonPressed(receiverID: $0) }
        djiMicMonitor.onDisconnect = { [weak coordinator] in await coordinator?.djiMicReceiverDisconnected($0) }

        coordinator.showPill = { [weak pillWindowController] in
            pillWindowController?.show()
        }
        coordinator.hidePill = { [weak pillWindowController] in
            pillWindowController?.hide()
        }
        coordinator.showMainWindow = { [weak mainWindowController] in
            mainWindowController?.show()
        }
        coordinator.quit = {
            NSApplication.shared.terminate(nil)
        }

        hotkeyMonitor.onHoldStarted = { [weak coordinator] in
            Task { @MainActor in
                await coordinator?.startQuickDictation()
            }
        }
        hotkeyMonitor.onHoldEnded = { [weak coordinator] in
            Task { @MainActor in
                await coordinator?.finishDictation()
            }
        }
        hotkeyMonitor.onTap = { [weak coordinator] in
            Task { @MainActor in
                await coordinator?.controlTapped()
            }
        }
        hotkeyMonitor.onDoubleTap = { [weak coordinator] in
            Task { @MainActor in
                await coordinator?.toggleHandsFreeDictation()
            }
        }
        hotkeyMonitor.onSecureInputBlocked = { [weak coordinator] in
            coordinator?.showSecureInputWarning()
        }
        hotkeyMonitor.onCancel = { [weak coordinator] in
            Task { @MainActor in
                coordinator?.cancelDictation()
            }
        }
        hotkeyMonitor.start()

        coordinator.bootstrap()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(retryHotkeyMonitor(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(refreshDJIMicMonitor(_:)), name: name, object: nil
            )
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(resumeHotkeyMonitor(_:)), name: name, object: nil
            )
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(suspendHotkeyMonitor(_:)), name: name, object: nil
            )
        }
        if CommandLine.arguments.contains("--show-window") {
            coordinator.openSettings()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !hotkeyIsSuspended else { return }
        hotkeyMonitor?.start()
        djiMicMonitor?.refresh()
        coordinator?.meetingDetection.refresh()
    }

    @objc private func retryHotkeyMonitor(_ notification: Notification) {
        guard !hotkeyIsSuspended else { return }
        hotkeyMonitor?.start()
        djiMicMonitor?.refresh()
    }

    @objc private func refreshDJIMicMonitor(_ notification: Notification) { djiMicMonitor?.refresh() }

    @objc private func suspendHotkeyMonitor(_ notification: Notification) {
        if notification.name == NSWorkspace.willSleepNotification { coordinator?.meetings.stop(interrupted: true) }
        hotkeyIsSuspended = true
        hotkeyMonitor?.stop()
        djiMicMonitor?.suspend()
        coordinator?.cancelDictation()
        coordinator?.meetingDetection.suspend()
    }

    @objc private func resumeHotkeyMonitor(_ notification: Notification) {
        hotkeyIsSuspended = false
        hotkeyMonitor?.start(forceRestart: true)
        djiMicMonitor?.resume()
        coordinator?.meetingDetection.resume()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hotkeyMonitor?.stop()
        djiMicMonitor?.stop()
        coordinator?.meetingDetection.stop()
        meetingPromptController?.hide()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let recording = coordinator?.meetings.isCapturing == true
        let processing = coordinator?.meetings.isProcessing == true && coordinator?.hasNonMeetingActivity == false
        if recording || processing {
            guard !quitConfirmationIsShowing else { return .terminateLater }
            guard let mainWindowController else { return .terminateCancel }
            quitConfirmationIsShowing = true
            mainWindowController.confirmMeetingExit(recording ? .recording : .transcribing) { [weak self] confirmed in
                guard let self else { return }
                if confirmed {
                    self.coordinator.meetings.stop()
                    self.coordinator.meetings.suspendProcessing()
                }
                self.quitConfirmationIsShowing = false
                NSApp.reply(toApplicationShouldTerminate: confirmed)
            }
            return .terminateLater
        }
        guard coordinator?.isBusyForAppUpdate != true else { return .terminateCancel }
        return .terminateNow
    }

    #if DEBUG
    private func launchMeetingUITests() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MumlaMeetingUITests", isDirectory: true)
        if CommandLine.arguments.contains("--reset-ui-data") { try? FileManager.default.removeItem(at: directory) }
        coordinator = AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
            historyStore: DictationHistoryStore(directory: directory), dictionaryStore: DictionaryStore(directory: directory),
            settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil)
        coordinator.meetings = MeetingCoordinator(directory: directory, modelDirectory: { nil }, capture: MeetingUICapture(), permission: { true },
            processor: { _, _, _ in [] })
        if CommandLine.arguments.contains("--seed-meeting") { _ = try? MeetingDesignFixtures.seed(coordinator.meetings, long: CommandLine.arguments.contains("--long-meeting")) }
        else { coordinator.meetings.reload(); coordinator.meetings.selectedID = coordinator.meetings.records.first?.id }
        updater = MacUpdateController()
        mainWindowController = MainWindowController(coordinator: coordinator, updater: updater, initialSection: "meetings")
        if CommandLine.arguments.contains("--compact-window") { mainWindowController.setTestingSize(NSSize(width: 820, height: 560)) }
        if CommandLine.arguments.contains("--suggest-meeting") {
            coordinator.settings.suggestMeetingRecording = true
            coordinator.settings.useMeetingCalendar = true
            coordinator.meetingDetection = MeetingDesignFixtures.detection { [weak coordinator] app, title in
                guard let coordinator else { return }
                coordinator.meetings.sourcePID = app.id; coordinator.meetings.title = title ?? ""
                await coordinator.meetings.start()
            }
            meetingPromptController = MeetingPromptWindowController(detection: coordinator.meetingDetection)
        }
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        let quit = NSMenuItem(title: "Quit Mumla", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp; applicationMenu.addItem(quit)
        applicationItem.submenu = applicationMenu; menu.addItem(applicationItem); NSApp.mainMenu = menu
        mainWindowController.show()
        if CommandLine.arguments.contains("--focus-meeting-suggestion") { meetingPromptController?.focusForUITesting() }
    }

    private func captureDesign(at path: String) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MumlaDesignSnapshot-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshotCoordinator = AppCoordinator(
            recorder: MicrophoneRecorder(), transcriber: nil,
            historyStore: DictationHistoryStore(directory: directory),
            dictionaryStore: DictionaryStore(directory: directory),
            settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil
        )
        let sectionIndex = CommandLine.arguments.firstIndex(of: "--snapshot-section")
        let section = sectionIndex.flatMap { CommandLine.arguments.indices.contains($0 + 1) ? CommandLine.arguments[$0 + 1] : nil } ?? "dictate"
        let isPill = section.hasPrefix("pill-")
        var fixture: MeetingRecord?
        if section.hasPrefix("meetings-") {
            fixture = try? MeetingDesignFixtures.seed(snapshotCoordinator.meetings, long: CommandLine.arguments.contains("--snapshot-long"))
            guard fixture != nil else { return }
            if let fixture, section == "meetings-live" || section == "meetings-paused" {
                snapshotCoordinator.meetings.prepareRecordingDesignSnapshot(fixture.id, paused: section == "meetings-paused")
            }
            if section == "meetings-error" { snapshotCoordinator.meetings.error = "The selected input device is unavailable. Your meeting recording has been saved on this Mac." }
        }
        if CommandLine.arguments.contains("--snapshot-apple-text") { snapshotCoordinator.settings.textModelProvider = .appleIntelligence }
        if CommandLine.arguments.contains("--snapshot-meeting-detection") {
            snapshotCoordinator.settings.suggestMeetingRecording = true
            snapshotCoordinator.settings.useMeetingCalendar = true
            snapshotCoordinator.meetingDetection = MeetingDesignFixtures.detection { _, _ in }
        }
        if CommandLine.arguments.contains("--snapshot-minimal") { snapshotCoordinator.settings.dictationOverlayStyle = .minimal }
        if section == "pill-recording" { snapshotCoordinator.prepareRecordingSnapshot() }
        if section == "pill-preparing" { snapshotCoordinator.pillState = .preparing(progress: 0.45) }
        if section == "pill-transcribing" { snapshotCoordinator.pillState = .transcribing }
        if section == "pill-message" { snapshotCoordinator.pillState = .message("Microphone permission needed") }
        if section == "pill-transcript" {
            snapshotCoordinator.pillState = .transcript(DictationRecord(
                text: "Vi ses klockan nio. Jag tar med anteckningarna från mötet så att vi kan gå igenom nästa steg tillsammans.", language: .swedish
            ), copied: true)
        }
        let compact = CommandLine.arguments.contains("--snapshot-compact")
        let light = CommandLine.arguments.contains("--snapshot-light")
        var size = section == "meetings-quit" ? NSSize(width: 520, height: 340)
            : section == "meetings-correction" ? NSSize(width: 520, height: 480)
            : section.hasPrefix("meetings-delete") ? NSSize(width: 520, height: 400)
            : section == "text-model" ? NSSize(width: compact ? 320 : 480, height: 320)
            : section == "about" ? NSSize(width: 580, height: 520) : isPill ? PillView.size(for: snapshotCoordinator.pillState, style: snapshotCoordinator.settings.dictationOverlayStyle)
            : CommandLine.arguments.contains("--snapshot-wide") ? NSSize(width: 1280, height: 860)
            : NSSize(width: compact ? 820 : 960, height: compact ? 560 : 760)
        let view: NSView
        let window: NSWindow
        if isPill {
            let controller = PillWindowController(coordinator: snapshotCoordinator)
            window = controller.window
            window.setContentSize(size)
            view = window.contentView!
        } else {
            let root = section == "meetings-suggestion" ? AnyView(MeetingSuggestionView(suggestion: MeetingDesignFixtures.suggestion(long: CommandLine.arguments.contains("--snapshot-long")), start: {}, dismiss: {}))
                : section == "meetings-quit" ? AnyView(MeetingExitSheet(reason: .recording, confirm: {}, cancel: {}))
                : section == "meetings-correction" ? AnyView(MeetingCorrectionSheet(segment: fixture!.segments[1], speaker: fixture!.speakerName("system-0"), save: { _, _ in }))
                : section.hasPrefix("meetings-delete") ? AnyView(MeetingDeletionSheet(meeting: fixture!, audioOnly: section == "meetings-delete-audio", delete: { nil }))
                : section == "about" ? AnyView(MumlaAboutView())
                : section == "text-model" ? AnyView(QwenTextModelControls(model: snapshotCoordinator.textModel)
                    .padding(24).frame(width: size.width, height: size.height, alignment: .topLeading)
                    .buttonStyle(MumlaKeyStyle()).background(MumlaStyle.background))
                : AnyView(MainView(coordinator: snapshotCoordinator, initialSection: section.hasPrefix("meetings") ? "meetings" : section))
            view = NSHostingView(rootView: root.environment(\.colorScheme, light ? .light : .dark))
            if section == "meetings-suggestion" { size = view.fittingSize }
            window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = view
        }
        window.appearance = NSAppearance(named: light ? .aqua : .darkAqua)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }
    }
    #endif
}
