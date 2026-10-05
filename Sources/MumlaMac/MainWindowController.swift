import AppKit
import SwiftUI

@MainActor
final class MainWindowController {
    private let window: NSWindow

    init(coordinator: AppCoordinator, updater: MacUpdateController) {
        let contentView = MainView(coordinator: coordinator, updater: updater)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Mumla"
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: contentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.center()
        self.window = window
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
