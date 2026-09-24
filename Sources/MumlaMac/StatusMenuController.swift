import AppKit
import Combine
import MumlaCore

@MainActor
final class StatusMenuController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let coordinator: AppCoordinator
    private var cancellables: Set<AnyCancellable> = []

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
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
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(title: coordinator.statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

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
        menu.addItem(menuItem("Quit", action: #selector(quit)))
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
