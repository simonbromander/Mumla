import MumlaCore
import MumlaUI
import SwiftUI

enum MeetingDialog: Identifiable {
    case correction(meetingID: UUID, segment: MeetingSegment, speaker: String)
    case deletion(meeting: MeetingRecord, audioOnly: Bool)

    var id: String {
        switch self {
        case .correction(let meetingID, let segment, _): "edit-\(meetingID)-\(segment.id)"
        case .deletion(let meeting, let audioOnly): "delete-\(meeting.id)-\(audioOnly)"
        }
    }
}

struct MeetingPopover<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(size: 15, weight: .semibold, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            content
        }.padding(20).frame(width: 360)
            .font(.system(.body, design: .monospaced)).foregroundStyle(MumlaStyle.ink)
            .background { MumlaBackdrop() }.tint(MumlaStyle.accent).mumlaAppearance()
    }
}

struct MeetingCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var speaker: String
    @State private var error: String?
    private let save: (String, String) throws -> Void

    init(segment: MeetingSegment, speaker: String, save: @escaping (String, String) throws -> Void) {
        _text = State(initialValue: segment.text); _speaker = State(initialValue: speaker); self.save = save
    }

    static func canSave(text: String, speaker: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= 20_000 && speaker.count <= 100
    }

    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Rätta transkript", "Correct transcript"), closeLabel: mText("Avbryt", "Cancel"), closeIdentifier: "meeting.edit.close") { dismiss() }
            VStack(alignment: .leading, spacing: 16) {
                MumlaTextField(mText("Talare", "Speaker"), text: $speaker).accessibilityIdentifier("meeting.edit.speaker")
                Text(mText("Transkript", "Transcript")).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                TextEditor(text: $text).font(.system(size: 14, design: .monospaced)).scrollContentBackground(.hidden)
                    .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity).mumlaRecess(radius: 8)
                    .accessibilityLabel(mText("Transkript", "Transcript")).accessibilityIdentifier("meeting.edit.text")
                if let error { MeetingPanelError(message: error) }
            }.padding(24)
            Divider()
            HStack(spacing: 12) {
                Button { dismiss() } label: { Label(mText("Avbryt", "Cancel"), systemImage: "xmark").padding(.horizontal, 16).frame(minHeight: 44) }
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier("meeting.edit.cancel")
                Spacer(minLength: 0)
                Button {
                    do { try save(text, speaker); dismiss() } catch { self.error = error.localizedDescription }
                } label: { Label(mText("Spara", "Save"), systemImage: "checkmark").padding(.horizontal, 16).frame(minHeight: 44) }
                    .disabled(!Self.canSave(text: text, speaker: speaker)).keyboardShortcut(.return, modifiers: .command)
                    .accessibilityIdentifier("meeting.edit.save")
            }.buttonStyle(MumlaKeyStyle(radius: 8)).padding(24)
        }.frame(width: 520, height: 480).font(.system(.body, design: .monospaced)).foregroundStyle(MumlaStyle.ink)
            .background { MumlaBackdrop() }.tint(MumlaStyle.accent).mumlaAppearance()
    }
}

struct MeetingDeletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let meeting: MeetingRecord
    let audioOnly: Bool
    let delete: () -> String?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(audioOnly ? mText("Radera ljud?", "Delete audio?") : mText("Radera möte?", "Delete meeting?"),
                             closeLabel: mText("Avbryt", "Cancel"), closeIdentifier: "meeting.delete.close") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label(audioOnly ? mText("Endast inspelningen", "Recording only") : mText("Inspelning och transkript", "Recording and transcript"),
                          systemImage: audioOnly ? "waveform.slash" : "trash")
                        .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(MumlaStyle.recording)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(meeting.title).font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    Text(audioOnly ? mText("Transkriptet finns kvar. Ljudet kan inte återställas.", "The transcript stays. The audio cannot be restored.")
                         : mText("Mötet, transkriptet och allt sparat ljud raderas från den här Macen. Det går inte att ångra.", "The meeting, transcript and all saved audio will be deleted from this Mac. This cannot be undone."))
                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let error { MeetingPanelError(message: error) }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack(spacing: 12) {
                Button { dismiss() } label: { Label(mText("Avbryt", "Cancel"), systemImage: "xmark").padding(.horizontal, 16).frame(minHeight: 44) }
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier("meeting.delete.cancel")
                Spacer(minLength: 0)
                Button {
                    if let message = delete() { error = message } else { dismiss() }
                } label: {
                    Label(audioOnly ? mText("Radera ljud", "Delete audio") : mText("Radera möte", "Delete meeting"), systemImage: "trash")
                        .foregroundStyle(MumlaStyle.recording).padding(.horizontal, 16).frame(minHeight: 44)
                }.accessibilityIdentifier("meeting.delete.confirm")
            }.buttonStyle(MumlaKeyStyle(radius: 8)).padding(24)
        }.frame(width: 520, height: 400).font(.system(.body, design: .monospaced)).foregroundStyle(MumlaStyle.ink)
            .background { MumlaBackdrop() }.tint(MumlaStyle.accent).mumlaAppearance()
    }
}

private struct MeetingPanelError: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle").font(.system(size: 12, design: .monospaced))
            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("meeting.dialog.error")
    }
}

struct MeetingRecordingReadout: View {
    let paused: Bool
    let elapsed: TimeInterval
    let microphone: Double
    let system: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                MumlaRecordingLight(recording: !paused)
                Text(paused ? "PAUSE" : "REC").font(.system(size: 12, weight: .semibold, design: .monospaced))
                Spacer()
                Text(MeetingRecord.timestamp(elapsed)).font(.system(size: 28, weight: .light, design: .monospaced)).monospacedDigit()
            }
            meter("MIC", label: mText("Mikrofon", "Microphone"), level: microphone)
            if let system { meter("SYS", label: mText("Datorljud", "Computer audio"), level: system) }
        }.foregroundStyle(MumlaStyle.lcdInk).padding(16)
            .background(RoundedRectangle(cornerRadius: 7).fill(LinearGradient(colors: [MumlaStyle.lcd, MumlaStyle.lcdEnd], startPoint: .top, endPoint: .bottom)))
            .mumlaDisplayLens().padding(6).mumlaRecess(radius: 8)
            .accessibilityElement(children: .combine)
    }

    private func meter(_ title: String, label: String, level: Double) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 11, design: .monospaced)).frame(width: 30, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(0..<28) { index in
                    Rectangle().fill(!paused && Double(index) / 28 < level ? MumlaStyle.lcdInk : MumlaStyle.lcdInk.opacity(0.16))
                }
            }.frame(height: 8).accessibilityHidden(true)
        }.accessibilityElement(children: .ignore).accessibilityLabel(label)
            .accessibilityValue("\(Int(max(0, min(1, level)) * 100)) %")
    }
}

enum MeetingExitReason {
    case recording, transcribing
}

struct MeetingExitSheet: View {
    let reason: MeetingExitReason
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Avsluta Mumla?", "Quit Mumla?"), closeLabel: mText("Avbryt", "Cancel")) { cancel() }
            VStack(alignment: .leading, spacing: 18) {
                Label(reason == .recording ? mText("Ett möte spelas in", "A meeting is recording") : mText("Transkribering pågår", "Transcription in progress"),
                      systemImage: reason == .recording ? "record.circle" : "waveform")
                    .font(.system(size: 16, weight: .medium, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
                Text(reason == .recording
                     ? mText("Inspelningen stoppas och sparas på den här Macen innan Mumla avslutas.", "The recording will be stopped and saved on this Mac before Mumla quits.")
                     : mText("Ljudet är sparat. Du kan fortsätta transkribera nästa gång du öppnar Mumla.", "The audio is saved. You can resume transcription next time you open Mumla."))
                    .font(.system(size: 13, design: .monospaced)).foregroundStyle(MumlaStyle.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            HStack(spacing: 12) {
                Button(action: cancel) { Label(mText("Avbryt", "Cancel"), systemImage: "xmark").padding(.horizontal, 16).frame(minHeight: 44) }
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier("meeting.quit.cancel")
                Spacer(minLength: 0)
                Button(action: confirm) {
                    Label(reason == .recording ? mText("Spara och avsluta", "Save and quit") : mText("Pausa och avsluta", "Pause and quit"), systemImage: "power")
                        .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 16).frame(minHeight: 44)
                }.accessibilityIdentifier("meeting.quit.confirm")
            }.buttonStyle(MumlaKeyStyle(radius: 8)).padding(24)
        }.frame(width: 520, height: 340).font(.system(.body, design: .monospaced)).foregroundStyle(MumlaStyle.ink)
            .background { MumlaBackdrop() }.tint(MumlaStyle.accent).mumlaAppearance()
    }
}
