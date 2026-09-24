import AppKit
import SwiftUI

@MainActor
final class PillWindowController {
    private let window: NSPanel

    init(coordinator: AppCoordinator) {
        let hostingView = NSHostingView(rootView: PillView(coordinator: coordinator))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 510, height: 82),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        self.window = panel
    }

    func show() {
        position()
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    private func position() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let size = window.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 28
        )
        window.setFrameOrigin(origin)
    }
}
