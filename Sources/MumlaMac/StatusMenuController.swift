import AppKit
import Combine
import MumlaAudio
import MumlaCore
import MumlaUI
import SwiftUI

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let coordinator: AppCoordinator
    private let updater: MacUpdateController
    private var cancellables: Set<AnyCancellable> = []
    private var menuTarget: FocusedTextTargetSnapshot?
    private var sendResultPopover: NSPopover?
    private let captureTarget: @MainActor () -> FocusedTextTargetSnapshot?

    init(coordinator: AppCoordinator, updater: MacUpdateController, statusItem: NSStatusItem? = nil,
         captureTarget: @escaping @MainActor () -> FocusedTextTargetSnapshot? = {
             guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
             return FocusedTextTargetInspector.captureEditableTarget(processID: pid)
         }) {
        self.coordinator = coordinator
        self.updater = updater
        self.statusItem = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.captureTarget = captureTarget
        super.init()
        MumlaAppearance.stored().applyNativeAppearance()
        if let button = self.statusItem.button {
            button.image = Self.makeStatusImage()
            button.imagePosition = .imageOnly
        }
        rebuildMenu()
        coordinator.$history
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.transcriptDestination.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.$languageMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.$inputDevices
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.$settings
            .map(\.pinnedInputDevice)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.$statusText
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.$isBusyForAppUpdate
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.meetings.$activeID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
        coordinator.meetings.$isPaused
            .receive(on: RunLoop.main)
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
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: UserDefaults.standard)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    /// Use the app icon's waveform and record button as a monochrome menu bar mark.
    private static func makeStatusImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            let heights: [CGFloat] = [2.5, 5.25, 8, 5.25, 2.5]
            for (index, height) in heights.enumerated() {
                let bar = NSRect(x: 3 + CGFloat(index) * 2.5, y: 13.5 - height / 2, width: 2, height: height)
                NSBezierPath(roundedRect: bar, xRadius: 1, yRadius: 1).fill()
            }
            NSBezierPath(ovalIn: NSRect(x: 5, y: 0.5, width: 8, height: 8)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Mumla"
        return image
    }

    private func rebuildMenu() {
        let label = coordinator.isMeetingActive
            ? (coordinator.meetings.isPaused ? mText("Mumla · möte pausat", "Mumla · meeting paused") : mText("Mumla · spelar in möte", "Mumla · recording meeting"))
            : "Mumla"
        statusItem.button?.setAccessibilityLabel(label)
        statusItem.button?.toolTip = label
        let menu = NSMenu()
        menu.delegate = self

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

        let startDictation = menuItem("Start Hands-free", action: #selector(startHandsFree))
        startDictation.isEnabled = !coordinator.isMeetingActive
        menu.addItem(startDictation)
        let cancelDictation = menuItem("Cancel Dictation", action: #selector(cancelDictation))
        cancelDictation.isEnabled = !coordinator.isMeetingActive
        menu.addItem(cancelDictation)
        if coordinator.meetings.activeID != nil {
            let meetingStatus = NSMenuItem(title: "REC · " + MeetingRecord.timestamp(coordinator.meetings.elapsed), action: nil, keyEquivalent: "")
            meetingStatus.identifier = .init("meeting.status"); menu.addItem(meetingStatus)
            menu.addItem(menuItem(coordinator.meetings.isPaused ? mText("Fortsätt möte", "Resume meeting") : mText("Pausa möte", "Pause meeting"), action: #selector(pauseMeeting)))
            let stop = menuItem(mText("Stoppa och spara möte", "Stop and save meeting"), action: #selector(stopMeeting))
            stop.identifier = .init("meeting.stop"); menu.addItem(stop)
        }
        let meetings = menuItem(mText("Möten...", "Meetings..."), action: #selector(openMeetings))
        meetings.identifier = .init("meeting.open"); menu.addItem(meetings)
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

        let microphoneMenu = NSMenu()
        microphoneMenu.autoenablesItems = false
        let pinned = coordinator.settings.pinnedInputDevice
        let systemDefault = menuItem(mText("Systemets standard", "System Default"), action: #selector(selectMicrophone(_:)))
        systemDefault.state = pinned == nil ? .on : .off
        microphoneMenu.addItem(systemDefault)
        microphoneMenu.addItem(.separator())
        for device in coordinator.inputDevices {
            let item = menuItem(device.name, action: #selector(selectMicrophone(_:)))
            item.representedObject = device.uid
            item.state = coordinator.isPinnedInputDevice(device) ? .on : .off
            microphoneMenu.addItem(item)
        }
        if let pinned, !coordinator.isPinnedInputDeviceConnected {
            let item = NSMenuItem(title: pinned.name + " " + mText("(ej ansluten)", "(not connected)"), action: nil, keyEquivalent: "")
            item.state = .on
            item.isEnabled = false
            microphoneMenu.addItem(item)
        }
        let microphoneItem = NSMenuItem(title: mText("Mikrofon", "Microphone"), action: nil, keyEquivalent: "")
        microphoneItem.submenu = microphoneMenu
        menu.addItem(microphoneItem)

        let appearanceMenu = NSMenu()
        for appearance in MumlaAppearance.allCases {
            let item = menuItem(appearance.title, action: #selector(selectAppearance(_:)))
            item.representedObject = appearance.rawValue
            item.image = NSImage(systemSymbolName: appearance.symbol, accessibilityDescription: nil)
            item.state = MumlaAppearance.stored() == appearance ? .on : .off
            appearanceMenu.addItem(item)
        }
        let appearanceItem = NSMenuItem(title: mText("Utseende", "Appearance"), action: nil, keyEquivalent: "")
        appearanceItem.submenu = appearanceMenu
        menu.addItem(appearanceItem)

        let pasteLast = menuItem(mText("Klistra in senaste transkript", "Paste Last Transcript"), action: #selector(pasteLastTranscript))
        pasteLast.identifier = .init("history.pasteLast")
        pasteLast.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        pasteLast.isEnabled = !coordinator.history.isEmpty && coordinator.canPasteFromHistory
        menu.addItem(pasteLast)

        let historyMenu = NSMenu()
        historyMenu.autoenablesItems = false
        for record in coordinator.history.prefix(10) {
            let title = record.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            let item = menuItem(String(title.prefix(64)) + (title.count > 64 ? "…" : ""), action: #selector(pasteHistory(_:)))
            item.representedObject = record.id.uuidString
            item.isEnabled = coordinator.canPasteFromHistory
            historyMenu.addItem(item)
        }
        if coordinator.history.isEmpty {
            let empty = NSMenuItem(title: mText("Inga transkript än", "No recent transcripts"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            historyMenu.addItem(empty)
        }
        let historyItem = NSMenuItem(title: mText("Senaste transkript", "Recent Transcripts"), action: nil, keyEquivalent: "")
        historyItem.identifier = .init("history.recent")
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)

        if let destination = coordinator.transcriptDestination.destination {
            let sendMenu = NSMenu(); sendMenu.autoenablesItems = false
            for record in coordinator.history.prefix(10) {
                let item = menuItem(String(record.text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(64)), action: #selector(sendHistory(_:)))
                item.representedObject = record.id.uuidString
                item.isEnabled = !coordinator.transcriptDestination.isSending
                sendMenu.addItem(item)
            }
            let sendItem = NSMenuItem(title: mText("Skicka till ", "Send to ") + destination.name, action: nil, keyEquivalent: "")
            sendItem.submenu = sendMenu
            sendItem.isEnabled = !coordinator.history.isEmpty && !coordinator.transcriptDestination.isSending
            sendItem.identifier = .init("history.send")
            menu.addItem(sendItem)
        }

        menu.addItem(.separator())
        menu.addItem(menuItem("Open Mumla", action: #selector(openMainWindow)))
        menu.addItem(menuItem(mText("Inställningar...", "Settings..."), action: #selector(openSettings)))
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

    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else {
            coordinator.setPinnedInputDevice(nil)
            return
        }
        // Ignore a device that disconnected while the menu was open rather than resetting the choice.
        guard let device = coordinator.inputDevices.first(where: { $0.uid == uid }) else { return }
        coordinator.setPinnedInputDevice(device)
    }

    @objc private func pasteHistory(_ sender: NSMenuItem) {
        guard
            let rawID = sender.representedObject as? String,
            let id = UUID(uuidString: rawID),
            let record = coordinator.history.first(where: { $0.id == id })
        else { return }
        pasteAfterMenuCloses(record)
    }

    @objc private func sendHistory(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw),
              let record = coordinator.history.first(where: { $0.id == id }),
              let destination = coordinator.transcriptDestination.destination,
              let transcript = try? record.outgoingTranscript(version: TranscriptDestinationController.version) else { return }
        Task { @MainActor [weak self] in
            await withCheckedContinuation { continuation in
                RunLoop.main.perform(inModes: [.default]) { continuation.resume() }
            }
            guard let self, !coordinator.transcriptDestination.isSending else { return }
            if coordinator.transcriptDestination.wasSent(id, sentAt: record.sentAt) {
                let alert = NSAlert()
                alert.messageText = mText("Skicka igen till ", "Send again to ") + destination.name + "?"
                alert.informativeText = mText("Det här transkriptet har redan skickats. Ett nytt exemplar kan skapas.",
                                             "This transcript was already sent. Another item may be created.")
                alert.addButton(withTitle: mText("Avbryt", "Cancel"))
                alert.addButton(withTitle: mText("Skicka igen", "Send again"))
                guard alert.runModal() == .alertSecondButtonReturn else { return }
            }
            guard coordinator.history.contains(where: { $0.id == id && $0.text == record.text }) else { return }
            showSendResult(mText("Skickar till ", "Sending to ") + destination.name)
            _ = await coordinator.transcriptDestination.send(transcript, id: id, approvedDestination: destination) {
                try self.coordinator.markTranscriptSent(id, at: $0)
            }
            showSendResult(coordinator.transcriptDestination.results[id] ?? mText("Sändningen avbröts.", "Send cancelled."))
        }
    }

    private func showSendResult(_ message: String) {
        guard let button = statusItem.button else { return }
        sendResultPopover?.close()
        let popover = NSPopover(); popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView:
            Text(message).font(.system(.body, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true).padding(20).frame(width: 300)
                .background(MumlaStyle.background).mumlaAppearance())
        sendResultPopover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.items.first { $0.identifier?.rawValue == "meeting.status" }?.title = (coordinator.meetings.isPaused ? "PAUSE · " : "REC · ") + MeetingRecord.timestamp(coordinator.meetings.elapsed)
        menuTarget = captureTarget()
        // Publication is deferred to the run loop; opening must use the current busy state.
        menu.items.first { $0.identifier?.rawValue == "history.pasteLast" }?.isEnabled = !coordinator.history.isEmpty && coordinator.canPasteFromHistory
        menu.items.first { $0.identifier?.rawValue == "history.recent" }?.submenu?.items.forEach {
            $0.isEnabled = $0.representedObject != nil && coordinator.canPasteFromHistory
        }
    }

    @objc private func pasteLastTranscript() {
        guard let record = coordinator.history.first else { return }
        pasteAfterMenuCloses(record)
    }

    private func pasteAfterMenuCloses(_ record: DictationRecord) {
        let target = menuTarget
        Task { @MainActor [weak coordinator] in
            // Default-mode work waits until menu tracking has relinquished keyboard focus.
            await withCheckedContinuation { continuation in
                RunLoop.main.perform(inModes: [.default]) { continuation.resume() }
            }
            coordinator?.pasteRecord(record, target: target)
        }
    }

    @objc private func selectAppearance(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let appearance = MumlaAppearance(rawValue: value) else { return }
        appearance.save()
        rebuildMenu()
    }

    @objc private func openMainWindow() {
        coordinator.openMainWindow()
    }

    @objc private func openSettings() {
        coordinator.openSettings()
    }

    @objc private func openMeetings() { coordinator.openMeetings() }
    @objc private func pauseMeeting() { coordinator.meetings.togglePause() }
    @objc private func stopMeeting() { coordinator.meetings.stop() }

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
