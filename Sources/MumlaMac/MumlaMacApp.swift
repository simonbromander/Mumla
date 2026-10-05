import AppKit
import Foundation
import MumlaAudio
import MumlaCore
import MumlaUI
import SwiftUI

@main
@MainActor
final class MumlaMacApp: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator!
    private var statusController: StatusMenuController!
    private var mainWindowController: MainWindowController!
    private var pillWindowController: PillWindowController!
    private var hotkeyMonitor: ControlHotkeyMonitor!
    private var updater: MacUpdateController!

    static func main() {
        let app = NSApplication.shared
        let delegate = MumlaMacApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--design-snapshot"),
           CommandLine.arguments.indices.contains(index + 1) {
            captureDesign(at: CommandLine.arguments[index + 1])
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
            modelDirectory: modelDirectory
        )
        pillWindowController = PillWindowController(coordinator: coordinator)
        updater = MacUpdateController(coordinator: coordinator)
        mainWindowController = MainWindowController(coordinator: coordinator, updater: updater)
        statusController = StatusMenuController(coordinator: coordinator, updater: updater)
        hotkeyMonitor = ControlHotkeyMonitor()
        coordinator.triggerKeyChanged = { [weak hotkeyMonitor] key in hotkeyMonitor?.setTriggerKey(key) }
        coordinator.requestHotkeyAccess = { [weak hotkeyMonitor] in hotkeyMonitor?.requestPermission() }
        hotkeyMonitor.onStatusChanged = { [weak coordinator] status in coordinator?.updateHotkeyStatus(status) }
        hotkeyMonitor.onGestureStageChanged = { [weak coordinator] stage in coordinator?.hotkeyGestureStage = stage }

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
        if CommandLine.arguments.contains("--show-window") {
            coordinator.openSettings()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        hotkeyMonitor?.start()
    }

    @objc private func retryHotkeyMonitor(_ notification: Notification) {
        hotkeyMonitor?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hotkeyMonitor?.stop()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard coordinator?.isBusyForAppUpdate != true else { return .terminateCancel }
        return .terminateNow
    }

    #if DEBUG
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
        if section == "pill-recording" { snapshotCoordinator.prepareRecordingSnapshot() }
        if section == "pill-transcript" {
            snapshotCoordinator.pillState = .transcript(DictationRecord(
                text: "Vi ses klockan nio. Jag tar med anteckningarna från mötet så att vi kan gå igenom nästa steg tillsammans.", language: .swedish
            ), copied: true)
        }
        let compact = CommandLine.arguments.contains("--snapshot-compact")
        let light = CommandLine.arguments.contains("--snapshot-light")
        let size = section == "about" ? NSSize(width: 580, height: 520) : isPill ? NSSize(width: PillView.width, height: PillView.height(for: snapshotCoordinator.pillState))
            : NSSize(width: compact ? 820 : 960, height: compact ? 560 : 760)
        let view: NSView
        let window: NSWindow
        if isPill {
            let controller = PillWindowController(coordinator: snapshotCoordinator)
            window = controller.window
            window.setContentSize(size)
            view = window.contentView!
        } else {
            let root = section == "about" ? AnyView(MumlaAboutView())
                : AnyView(MainView(coordinator: snapshotCoordinator, initialSection: section))
            view = NSHostingView(rootView: root.environment(\.colorScheme, light ? .light : .dark))
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
