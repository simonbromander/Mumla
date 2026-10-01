import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class PillWindowController {
    let window: NSPanel
    private let coordinator: AppCoordinator
    private var presentationID = UUID()

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        let panel = DictationPanel(
            contentRect: NSRect(x: 0, y: 0, width: PillView.width, height: PillView.height(for: .hidden)),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        let contentView = PillHostingView(rootView: PillView(coordinator: coordinator))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.cornerRadius = PillView.cornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
        panel.contentView = contentView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        self.window = panel
    }

    func show() {
        presentationID = UUID()
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen else { return }
        let size = NSSize(width: PillView.width, height: PillView.height(for: coordinator.pillState))
        let frame = NSRect(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.minY + 20, width: size.width, height: size.height)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !window.isVisible {
            window.setFrame(frame.offsetBy(dx: 0, dy: reduceMotion ? 0 : -20), display: true)
            window.alphaValue = reduceMotion ? 1 : 0
            window.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(frame, display: true)
            window.animator().alphaValue = 1
        }
    }

    func hide() {
        let id = UUID()
        presentationID = id
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : 0.16
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.presentationID == id else { return }
                self.window.orderOut(nil)
            }
        }
    }
}

private final class PillHostingView: NSHostingView<PillView> {
    override var isOpaque: Bool { false }
}

private final class DictationPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
