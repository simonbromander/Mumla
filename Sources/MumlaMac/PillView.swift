import MumlaCore
import MumlaUI
import SwiftUI

struct PillView: View {
    @ObservedObject var coordinator: AppCoordinator
    static let width: CGFloat = 480
    static func height(for state: PillState) -> CGFloat {
        if case .transcript = state { return 248 }
        return 124
    }

    var body: some View {
        Group {
            if case let .transcript(record, copied) = coordinator.pillState {
                transcript(record, copied: copied)
            } else {
                recorder
            }
        }
        .padding(12)
        .frame(width: Self.width, height: Self.height(for: coordinator.pillState))
        .mumlaSurface(radius: 14)
        .preferredColorScheme(.dark)
        .font(.system(.body, design: .monospaced)).fontDesign(.monospaced)
        .accessibilityElement(children: .contain)
    }

    private var recorder: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    MumlaRecordingLight(recording: recording)
                    Text(title).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(2)
                    Spacer(minLength: 6)
                    if recording {
                        Text(elapsed).font(.system(size: 20, weight: .light, design: .monospaced)).monospacedDigit()
                    }
                    Text(language).font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                if recording {
                    MumlaWaveform(samples: coordinator.waveformSamples, active: true, ink: MumlaStyle.lcdInk)
                        .frame(height: 26)
                } else if case let .preparing(progress) = coordinator.pillState {
                    MumlaDownloadGauge(fraction: progress)
                } else {
                    Text(coordinator.pillState == .transcribing ? mText("PÅ DEN HÄR MACEN", "ON THIS MAC") : "16 kHz / MONO")
                        .font(.system(size: 10, design: .monospaced))
                }
            }
            .foregroundStyle(MumlaStyle.lcdInk)
            .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 7).fill(
                LinearGradient(colors: [MumlaStyle.lcd, Color(red: 0.72, green: 0.83, blue: 0.67)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .shadow(.inner(color: .black.opacity(0.45), radius: 4, y: 2))
            ))
            VStack(spacing: 8) {
                if recording {
                    MumlaIconButton("stop.fill", label: mText("Stoppa", "Stop")) { Task { await coordinator.finishDictation() } }
                    MumlaIconButton("xmark", label: mText("Avbryt", "Cancel")) { coordinator.cancelDictation() }
                } else if coordinator.pillState != .transcribing {
                    MumlaIconButton("xmark", label: mText("Stäng", "Close")) { coordinator.dismissPill() }
                }
            }
        }
    }

    private func transcript(_ record: DictationRecord, copied: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Label(mText("Texten är klar", "Transcript ready"), systemImage: "text.alignleft")
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(MumlaStyle.accent)
                Spacer()
                MumlaIconButton("xmark", label: mText("Stäng", "Close")) { coordinator.dismissPill() }
            }
            ScrollView {
                Text(record.text).font(.system(size: 15, design: .monospaced)).lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).mumlaRecess(radius: 7)
            HStack {
                Text(copied ? mText("Kopierat", "Copied") : mText("Sparat i historiken", "Saved in History"))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                Spacer()
                Button { coordinator.copyPillTranscript() } label: {
                    Label(mText("Kopiera", "Copy"), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .padding(.horizontal, 16).frame(height: 44)
                }.buttonStyle(MumlaKeyStyle()).accessibilityLabel(mText("Kopiera transkript", "Copy transcript"))
            }
        }
    }

    private var recording: Bool {
        switch coordinator.pillState { case .listening, .handsFree: true; default: false }
    }
    private var elapsed: String {
        let seconds: TimeInterval
        switch coordinator.pillState {
        case let .listening(value), let .handsFree(value): seconds = value
        default: seconds = 0
        }
        return String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
    private var title: String {
        switch coordinator.pillState {
        case .preparing: mText("FÖRBEREDER", "PREPARING")
        case .listening, .handsFree: "REC"
        case .transcribing: mText("TRANSKRIBERAR", "TRANSCRIBING")
        case let .message(message): message
        case .transcript: mText("TEXTEN ÄR KLAR", "TRANSCRIPT READY")
        case .hidden: "MUMla"
        }
    }
    private var language: String {
        switch coordinator.languageMode { case .automatic: "AUTO"; case .swedish: "SV"; case .english: "EN" }
    }
}
