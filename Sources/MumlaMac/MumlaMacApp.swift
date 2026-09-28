import AppKit
import Foundation
import MumlaAudio
import MumlaCore
import SwiftUI

@main
@MainActor
final class MumlaMacApp: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator!
    private var statusController: StatusMenuController!
    private var mainWindowController: MainWindowController!
    private var pillWindowController: PillWindowController!
    private var hotkeyMonitor: ControlHotkeyMonitor!

    static func main() {
        let app = NSApplication.shared
        let delegate = MumlaMacApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
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
        let historyStore = DictationHistoryStore.defaultStore()
        let modelDirectory = ModelPathResolver.resolveCompiledPianissimoModel()
        let transcriber = modelDirectory.map(LocalPianissimoTranscriber.init(modelDirectory:))

        coordinator = AppCoordinator(
            recorder: MicrophoneRecorder(),
            transcriber: transcriber,
            modelInstaller: ModelInstaller(),
            historyStore: historyStore,
            dictionaryStore: .defaultStore(),
            settingsStore: .defaultStore(),
            modelDirectory: modelDirectory
        )
        pillWindowController = PillWindowController(coordinator: coordinator)
        mainWindowController = MainWindowController(coordinator: coordinator)
        statusController = StatusMenuController(coordinator: coordinator)
        hotkeyMonitor = ControlHotkeyMonitor()

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
        if CommandLine.arguments.contains("--show-window") {
            coordinator.openSettings()
        }
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
        let view = NSHostingView(rootView: MainView(coordinator: snapshotCoordinator).environment(\.colorScheme, .dark))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 760), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = view
        view.frame = NSRect(x: 0, y: 0, width: 960, height: 760)
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
