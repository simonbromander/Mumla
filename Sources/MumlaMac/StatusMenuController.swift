import AppKit
import Combine
import MumlaCore
import MumlaUI

@MainActor
final class StatusMenuController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let coordinator: AppCoordinator
    private let updater: MacUpdateController
    private var cancellables: Set<AnyCancellable> = []

    init(coordinator: AppCoordinator, updater: MacUpdateController) {
        self.coordinator = coordinator
        self.updater = updater
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Mumla")
            button.imagePosition = .imageOnly
        }
        rebuildMenu()
        coordinator.$history
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.$languageMode
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.$statusText
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.$hotkeyMonitorStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        updater.$canCheckForUpdates
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        updater.$isWaitingForIdle
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(title: coordinator.statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if coordinator.hotkeyMonitorStatus != .active {
            menu.addItem(menuItem(coordinator.hotkeyStatusText, action: #selector(requestHotkeyAccess)))
        }
        menu.addItem(.separator())

        if coordinator.modelDirectory == nil {
            menu.addItem(menuItem(coordinator.isInstallingModel ? "Downloading Model..." : "Download Model", action: #selector(downloadModel)))
            menu.addItem(.separator())
        }

        menu.addItem(menuItem("Start Hands-free", action: #selector(startHandsFree)))
        menu.addItem(menuItem("Cancel Dictation", action: #selector(cancelDictation)))
        menu.addItem(.separator())

        let languageMenu = NSMenu()
        for mode in LanguageMode.allCases {
            let item = menuItem(mode.menuTitle, action: #selector(selectLanguage(_:)))
            item.representedObject = mode.rawValue
            item.state = coordinator.languageMode == mode ? .on : .off
            languageMenu.addItem(item)
        }
        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        let historyMenu = NSMenu()
        for record in coordinator.history.prefix(10) {
            let title = record.text.replacingOccurrences(of: "\n", with: " ")
            let item = menuItem(String(title.prefix(64)), action: #selector(pasteHistory(_:)))
            item.representedObject = record.id.uuidString
            historyMenu.addItem(item)
        }
        if coordinator.history.isEmpty {
            let empty = NSMenuItem(title: "No recent dictations", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            historyMenu.addItem(empty)
        }
        let historyItem = NSMenuItem(title: "Recent Dictations", action: nil, keyEquivalent: "")
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)

        menu.addItem(.separator())
        menu.addItem(menuItem("Open Mumla", action: #selector(openMainWindow)))
        if updater.isAvailable {
            let item = menuItem(mText("Sök uppdateringar...", "Check for Updates..."), action: #selector(checkForUpdates))
            item.isEnabled = updater.canCheckForUpdates
            item.toolTip = updater.isWaitingForIdle ? mText("Väntar på att dikteringen avslutas", "Waiting for dictation to finish") : nil
            menu.addItem(item)
        }
        menu.addItem(menuItem("Quit", action: #selector(quit)))
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func startHandsFree() {
        Task { @MainActor in
            await coordinator.toggleHandsFreeDictation()
        }
    }

    @objc private func requestHotkeyAccess() {
        coordinator.requestHotkeyPermission()
    }

    @objc private func downloadModel() {
        coordinator.installModel()
    }

    @objc private func cancelDictation() {
        coordinator.cancelDictation()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = LanguageMode(rawValue: rawValue)
        else { return }
        coordinator.setLanguageMode(mode)
    }

    @objc private func pasteHistory(_ sender: NSMenuItem) {
        guard
            let rawID = sender.representedObject as? String,
            let id = UUID(uuidString: rawID),
            let record = coordinator.history.first(where: { $0.id == id })
        else { return }
        coordinator.pasteRecord(record)
    }

    @objc private func openMainWindow() {
        coordinator.openSettings()
    }

    @objc private func quit() {
        coordinator.quit?()
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates()
    }
}

private extension LanguageMode {
    var menuTitle: String {
        switch self {
        case .automatic:
            return "Auto"
        case .swedish:
            return "Svenska"
        case .english:
            return "English"
        }
    }
}
