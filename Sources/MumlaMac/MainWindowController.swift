import AppKit
import Combine
import MumlaUI
import SwiftUI

@MainActor
final class MainWindowController {
    private let window: NSWindow
    private var meetingExitPanel: NSWindow?
    private var skinObserver: AnyCancellable?

    init(coordinator: AppCoordinator, updater: MacUpdateController, initialSection: String = "dictate") {
        let contentView = MainView(coordinator: coordinator, updater: updater, initialSection: initialSection)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // The controller owns the window and reopens it, so closing must not free it.
        window.isReleasedWhenClosed = false
        window.title = "Mumla"
        window.contentView = NSHostingView(rootView: contentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.center()
        self.window = window
        applySkin(MumlaSkin.stored())
        skinObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: UserDefaults.standard)
            .receive(on: RunLoop.main)
            .map { _ in MumlaSkin.stored() }.removeDuplicates()
            .sink { [weak self] style in self?.applySkin(style) }
    }

    private func applySkin(_ style: MumlaSkin) {
        window.titleVisibility = style == .classic ? .hidden : .visible
        window.isMovableByWindowBackground = style == .classic
        if style == .classic {
            window.toolbar = nil
            window.title = "Mumla"
        }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func confirmMeetingExit(_ reason: MeetingExitReason, completion: @escaping (Bool) -> Void) {
        guard meetingExitPanel == nil else { return }
        show()
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        var parent = window
        while let sheet = parent.attachedSheet { parent = sheet }
        let finish: (Bool) -> Void = { [weak self, weak panel, weak parent] approved in
            guard let self, let panel, let parent else { return }
            parent.endSheet(panel); self.meetingExitPanel = nil
            completion(approved)
        }
        panel.contentView = NSHostingView(rootView: MeetingExitSheet(reason: reason, confirm: { finish(true) }, cancel: { finish(false) }))
        meetingExitPanel = panel
        parent.beginSheet(panel)
    }

    #if DEBUG
    func setTestingSize(_ size: NSSize) { window.setContentSize(size) }
    #endif
}
