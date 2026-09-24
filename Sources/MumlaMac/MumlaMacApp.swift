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
        let historyStore = DictationHistoryStore.defaultStore()
        let modelDirectory = ModelPathResolver.resolveCompiledPianissimoModel()
        let transcriber = modelDirectory.map(LocalPianissimoTranscriber.init(modelDirectory:))

        coordinator = AppCoordinator(
            recorder: MicrophoneRecorder(),
            transcriber: transcriber,
            historyStore: historyStore,
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
    }
}
