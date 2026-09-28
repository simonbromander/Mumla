import MumlaCore
import MumlaUI
import SwiftUI

struct PillView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: recording ? "record.circle.fill" : "waveform")
                    .foregroundStyle(recording ? MumlaStyle.recording : MumlaStyle.lcdInk)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(1)
                    if let subtitle { Text(subtitle).font(.system(size: 10, design: .monospaced)).monospacedDigit() }
                }
                Spacer(minLength: 0)
                Text(language).font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(MumlaStyle.lcdInk)
            .padding(.horizontal, 12).frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 5).fill(MumlaStyle.lcd.shadow(.inner(color: .black.opacity(0.5), radius: 3, y: 2))))
            if recording {
                Button { Task { await coordinator.finishDictation() } } label: {
                    Image(systemName: "stop.fill").frame(width: 34, height: 38)
                }.buttonStyle(MumlaKeyStyle()).help(mText("Stoppa", "Stop")).accessibilityLabel(mText("Stoppa", "Stop"))
                Button { coordinator.cancelDictation() } label: {
                    Image(systemName: "xmark").frame(width: 34, height: 38)
                }.buttonStyle(MumlaKeyStyle()).help(mText("Avbryt", "Cancel")).accessibilityLabel(mText("Avbryt", "Cancel"))
            }
        }
        .padding(8).frame(width: 482, height: 62).mumlaSurface(radius: 11)
        .preferredColorScheme(.dark).accessibilityElement(children: .contain)
    }

    private var recording: Bool {
        switch coordinator.pillState { case .listening, .handsFree: true; default: false }
    }
    private var title: String {
        switch coordinator.pillState {
        case .preparing: mText("FÖRBEREDER", "PREPARING")
        case .listening, .handsFree: "REC"
        case .transcribing: mText("TRANSKRIBERAR", "TRANSCRIBING")
        case let .message(message): message
        case .hidden: "MUMla"
        }
    }
    private var subtitle: String? {
        switch coordinator.pillState {
        case let .preparing(progress): "\(Int(progress * 100)) %"
        case let .listening(elapsed), let .handsFree(elapsed): String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60)
        case .transcribing: mText("På den här Macen", "On this Mac")
        case .message, .hidden: nil
        }
    }
    private var language: String {
        switch coordinator.languageMode { case .automatic: "AUTO"; case .swedish: "SV"; case .english: "EN" }
    }
}
