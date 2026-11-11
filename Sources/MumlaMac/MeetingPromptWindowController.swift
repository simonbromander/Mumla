import AppKit
import Combine
import MumlaUI
import SwiftUI

struct MeetingSuggestionView: View {
    let suggestion: MeetingSuggestion
    let start: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Label(mText("Transkribera?", "Transcribe?"), systemImage: "person.2.wave.2")
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                Spacer(minLength: 0)
                Button(action: dismiss) { Image(systemName: "xmark").frame(width: 32, height: 32) }
                    .buttonStyle(MumlaKeyStyle(radius: 6)).help(mText("Inte nu", "Not now"))
                    .accessibilityLabel(mText("Inte nu", "Not now")).accessibilityIdentifier("meeting.suggestion.close")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(suggestion.candidate.app.kind.name + " · " + mText("mikrofon aktiv", "microphone active"))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                if let title = suggestion.title {
                    Text(title).font(.system(size: 14, weight: .medium, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Label(mText("Bara på den här Macen", "Only on this Mac"), systemImage: "lock.fill")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Button(action: dismiss) {
                    Label(mText("Inte nu", "Not now"), systemImage: "xmark").frame(maxWidth: .infinity, minHeight: 44)
                }.accessibilityIdentifier("meeting.suggestion.dismiss")
                Button(action: start) {
                    Label(mText("Starta", "Start"), systemImage: "record.circle")
                        .foregroundStyle(MumlaStyle.accent).frame(maxWidth: .infinity, minHeight: 44)
                }.accessibilityIdentifier("meeting.suggestion.start")
            }.buttonStyle(MumlaKeyStyle(radius: 8))
        }.padding(20).frame(width: 380).fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(MumlaStyle.ink).background { MumlaBackdrop() }.mumlaAppearance()
    }
}

@MainActor
final class MeetingPromptWindowController {
    private let detection: MeetingDetectionCoordinator
    private let window: NSPanel
    private var observation: AnyCancellable?

    init(detection: MeetingDetectionCoordinator) {
        self.detection = detection
        window = MeetingSuggestionPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.title = "Mumla - Transcribe?"
        window.isFloatingPanel = true; window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.backgroundColor = .clear; window.isOpaque = false; window.hasShadow = true; window.hidesOnDeactivate = false
        observation = detection.$suggestion.sink { [weak self] suggestion in
            guard let self else { return }
            if let suggestion { self.show(suggestion) } else { self.hide() }
        }
    }

    func hide() { window.orderOut(nil) }

    #if DEBUG
    func focusForUITesting() { window.makeKeyAndOrderFront(nil) }
    #endif

    private func show(_ suggestion: MeetingSuggestion) {
        let view = NSHostingView(rootView: MeetingSuggestionView(suggestion: suggestion, start: { [weak detection] in
            Task { await detection?.start(suggestion.id) }
        }, dismiss: { [weak detection] in detection?.dismiss(suggestion.id) }))
        view.wantsLayer = true; view.layer?.cornerRadius = 12; view.layer?.masksToBounds = true
        window.contentView = view
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        let size = view.fittingSize
        window.setFrame(NSRect(x: screen.visibleFrame.maxX - size.width - 20, y: screen.visibleFrame.minY + 20,
                               width: size.width, height: size.height), display: true)
        window.orderFrontRegardless()
    }
}

private final class MeetingSuggestionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
