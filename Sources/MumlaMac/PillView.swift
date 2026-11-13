import MumlaCore
import MumlaUI
import SwiftUI

struct PillView: View {
    @MumlaTheme private var palette
    @ObservedObject var coordinator: AppCoordinator
    static let width: CGFloat = 380
    static let cornerRadius: CGFloat = 14
    static func height(for state: PillState) -> CGFloat {
        if case .transcript = state { return 208 }
        return 92
    }
    static func size(for state: PillState, style: DictationOverlayStyle) -> NSSize {
        guard usesMinimalLayout(for: state, style: style) else { return NSSize(width: width, height: height(for: state)) }
        switch state {
        case .message: return NSSize(width: 256, height: 56)
        case .preparing, .transcribing: return NSSize(width: 156, height: 30)
        default: return NSSize(width: 104, height: 30)
        }
    }
    static func usesMinimalLayout(for state: PillState, style: DictationOverlayStyle) -> Bool {
        guard style == .minimal else { return false }
        if case .transcript = state { return false }
        return true
    }
    static func cornerRadius(for state: PillState, style: DictationOverlayStyle) -> CGFloat {
        usesMinimalLayout(for: state, style: style) ? size(for: state, style: style).height / 2 : cornerRadius
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
        .padding(isMinimalOverlay ? 4 : 8)
        .frame(width: Self.size(for: coordinator.pillState, style: coordinator.settings.dictationOverlayStyle).width,
               height: Self.size(for: coordinator.pillState, style: coordinator.settings.dictationOverlayStyle).height)
        .mumlaSurface(radius: Self.cornerRadius(for: coordinator.pillState, style: coordinator.settings.dictationOverlayStyle), opacity: isMinimalOverlay ? 0.72 : 0.88)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius(for: coordinator.pillState, style: coordinator.settings.dictationOverlayStyle), style: .continuous))
        .mumlaAppearance()
        .mumlaFont(.body)
        .accessibilityElement(children: .contain)
    }

    private var minimalRecorder: some View {
        HStack(spacing: 6) {
            MumlaRecordingLight(recording: recording)
            if recording {
                Text("REC").mumlaFont(size: 9, weight: .semibold)
                Text(elapsed).mumlaFont(size: 12).monospacedDigit()
                    .fixedSize()
            } else {
                Text(title).mumlaFont(size: 10, weight: .medium)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(palette.ink)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recording ? mText("Spelar in", "Recording") : title)
        .accessibilityValue(recording ? elapsed : "")
        .accessibilityIdentifier("dictation.minimal-overlay")
    }

    private var isMinimalOverlay: Bool {
        Self.usesMinimalLayout(for: coordinator.pillState, style: coordinator.settings.dictationOverlayStyle)
    }

    private var recorder: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    MumlaRecordingLight(recording: recording)
                    Text(title).mumlaFont(size: 12, weight: .semibold).lineLimit(2)
                    Spacer(minLength: 6)
                    if recording {
                        Text(elapsed).mumlaFont(size: 20, weight: .light).monospacedDigit()
                    }
                    Text(language).mumlaFont(size: 10, weight: .medium)
                }
                if recording {
                    MumlaWaveform(samples: coordinator.waveformSamples, active: true, ink: palette.lcdInk)
                        .frame(height: 18)
                } else if case let .preparing(progress) = coordinator.pillState {
                    MumlaDownloadGauge(fraction: progress)
                } else {
                    Text(coordinator.pillState == .transcribing ? mText("PÅ DEN HÄR MACEN", "ON THIS MAC") : "16 kHz / MONO")
                        .mumlaFont(size: 10)
                }
            }
            .foregroundStyle(palette.lcdInk)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 7).fill(
                LinearGradient(colors: [palette.lcd, palette.lcdEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .shadow(.inner(color: .black.opacity(palette.skin == .classic ? 0.45 : 0), radius: 4, y: 2))
            ))
            .mumlaDisplayLens()
            HStack(spacing: 6) {
                if coordinator.isMeetingActive {
                    MumlaIconButton(coordinator.meetings.isPaused ? "play.fill" : "pause.fill",
                        label: coordinator.meetings.isPaused ? mText("Fortsätt möte", "Resume meeting") : mText("Pausa möte", "Pause meeting")) { coordinator.meetings.togglePause() }
                    MumlaIconButton("stop.fill", label: mText("Stoppa och spara möte", "Stop and save meeting")) { coordinator.meetings.stop() }
                } else if recording {
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
                    .mumlaFont(size: 12, weight: .medium).foregroundStyle(palette.accent)
                Spacer()
                MumlaIconButton("xmark", label: mText("Stäng", "Close")) { coordinator.dismissPill() }
            }
            ScrollView {
                Text(record.text).mumlaFont(size: 15).lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).mumlaRecess(radius: 7)
            HStack {
                Text(copied ? mText("Kopierat", "Copied") : mText("Sparat i historiken", "Saved in History"))
                    .mumlaFont(size: 11).foregroundStyle(palette.secondary)
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
        if coordinator.isMeetingActive { return "SV" }
        return switch coordinator.languageMode { case .automatic: "AUTO"; case .swedish: "SV"; case .english: "EN" }
    }
}
