import MumlaCore
import MumlaUI
import SwiftUI

struct PillView: View {
    @ObservedObject var coordinator: AppCoordinator
    static let width: CGFloat = 380
    static let cornerRadius: CGFloat = 14
    static func height(for state: PillState) -> CGFloat {
        if case .transcript = state { return 208 }
        return 92
    }
    static func size(for state: PillState, style: DictationOverlayStyle) -> NSSize {
        if style == .minimal, case .transcript = state { return NSSize(width: width, height: height(for: state)) }
        return style == .minimal ? NSSize(width: 256, height: 56) : NSSize(width: width, height: height(for: state))
    }
    static func cornerRadius(for state: PillState, style: DictationOverlayStyle) -> CGFloat {
        size(for: state, style: style).height == 56 ? 28 : cornerRadius
    }

    var body: some View {
        Group {
            if case let .transcript(record, copied) = coordinator.pillState {
                transcript(record, copied: copied)
            } else if coordinator.settings.dictationOverlayStyle == .minimal {
                minimalRecorder
            } else {
                recorder
            }
        }
        .padding(8)
        .frame(width: Self.size(for: coordinator.pillState, style: coordinator.settings.dictationOverlayStyle).width,
               height: Self.size(for: coordinator.pillState, style: coordinator.settings.dictationOverlayStyle).height)
        .mumlaSurface(radius: Self.cornerRadius(for: coordinator.pillState, style: coordinator.settings.dictationOverlayStyle), opacity: 0.88)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius(for: coordinator.pillState, style: coordinator.settings.dictationOverlayStyle), style: .continuous))
        .mumlaAppearance()
        .font(.system(.body, design: .monospaced)).fontDesign(.monospaced)
        .accessibilityElement(children: .contain)
    }

    private var minimalRecorder: some View {
        HStack(spacing: 8) {
            MumlaRecordingLight(recording: recording)
            if recording {
                Text("REC").font(.system(size: 10, weight: .semibold, design: .monospaced))
                MumlaWaveform(samples: coordinator.waveformSamples, active: true, ink: MumlaStyle.accent)
                    .frame(width: 44, height: 16).accessibilityHidden(true)
                Text(elapsed).font(.system(size: 12, design: .monospaced)).monospacedDigit()
                    .accessibilityLabel(mText("Inspelningstid", "Recording time") + " " + elapsed)
            } else {
                Text(title).font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if recording {
                compactButton("stop.fill", label: mText("Stoppa", "Stop")) { Task { await coordinator.finishDictation() } }
                compactButton("xmark", label: mText("Avbryt", "Cancel")) { coordinator.cancelDictation() }
            } else if coordinator.isFormattingDictation {
                compactButton("xmark", label: mText("Avbryt formatering", "Cancel formatting")) { coordinator.cancelDictation() }
            } else if coordinator.pillState != .transcribing {
                compactButton("xmark", label: mText("Stäng", "Close")) { coordinator.dismissPill() }
            }
        }
        .foregroundStyle(MumlaStyle.ink)
        .padding(.horizontal, 8)
        .accessibilityIdentifier("dictation.minimal-overlay")
    }

    private func compactButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 28, height: 32)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label).help(label)
    }

    private var recorder: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
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
                        .frame(height: 18)
                } else if case let .preparing(progress) = coordinator.pillState {
                    MumlaDownloadGauge(fraction: progress)
                } else {
                    Text(coordinator.pillState == .transcribing ? mText("PÅ DEN HÄR MACEN", "ON THIS MAC") : "16 kHz / MONO")
                        .font(.system(size: 10, design: .monospaced))
                }
            }
            .foregroundStyle(MumlaStyle.lcdInk)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 7).fill(
                LinearGradient(colors: [MumlaStyle.lcd, MumlaStyle.lcdEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .shadow(.inner(color: .black.opacity(0.45), radius: 4, y: 2))
            ))
            .mumlaDisplayLens()
            HStack(spacing: 6) {
                if recording {
                    MumlaIconButton("stop.fill", label: mText("Stoppa", "Stop")) { Task { await coordinator.finishDictation() } }
                    MumlaIconButton("xmark", label: mText("Avbryt", "Cancel")) { coordinator.cancelDictation() }
                } else if coordinator.isFormattingDictation {
                    MumlaIconButton("xmark", label: mText("Avbryt formatering", "Cancel formatting")) { coordinator.cancelDictation() }
                        .accessibilityIdentifier("dictation.cancel-formatting")
                } else if coordinator.pillState != .transcribing {
                    MumlaIconButton("xmark", label: mText("Stäng", "Close")) { coordinator.dismissPill() }
                }
            }
        }
    }

    private func transcript(_ record: DictationRecord, copied: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
        case .transcribing: coordinator.isFormattingDictation ? mText("FORMATERAR", "FORMATTING") : mText("TRANSKRIBERAR", "TRANSCRIBING")
        case let .message(message): message
        case .transcript: mText("TEXTEN ÄR KLAR", "TRANSCRIPT READY")
        case .hidden: "MUMla"
        }
    }
    private var language: String {
        switch coordinator.languageMode { case .automatic: "AUTO"; case .swedish: "SV"; case .english: "EN" }
    }
}
