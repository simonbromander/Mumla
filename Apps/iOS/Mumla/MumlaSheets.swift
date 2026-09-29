import MumlaCore
import MumlaUI
import SwiftUI

struct MumlaSettingsSheet: View {
    @AppStorage("mumla.hapticsEnabled") private var hapticsEnabled = true
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showLicenses = false

    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Inställningar", "Settings"), closeLabel: mText("Klart", "Done")) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sectionTitle(mText("Diktering", "Dictation"))
                    Toggle(mText("Haptisk återkoppling", "Haptic feedback"), isOn: $hapticsEnabled)
                        .toggleStyle(MumlaSwitchStyle())
                    Divider()
                    readout(mText("Språk", "Language"), value: "Svenska")
                    readout(mText("Språkmodell", "Language model"), value: session.modelReady ? mText("Installerad", "Installed") : mText("Inte hämtad", "Not downloaded"))
                    if !session.modelReady {
                        action(mText("Hämta svenska", "Download Swedish"), symbol: "arrow.down") { Task { await session.install() } }
                            .disabled(session.isInstalling)
                        if session.isInstalling { MumlaDownloadGauge(fraction: session.progress.fraction) }
                    }
                    action(mText("Mikrofonbehörighet", "Microphone permission"), symbol: "mic") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    Divider().padding(.vertical, 4)
                    sectionTitle(mText("Om Mumla", "About Mumla"))
                    readout("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                    action(mText("Licenser", "Licenses"), symbol: "doc.text") { showLicenses = true }
                }.padding(24)
            }
        }
        .background { MumlaBackdrop() }
        .tint(MumlaStyle.accent).preferredColorScheme(.dark)
        .presentationBackground(MumlaStyle.background)
        .sheet(isPresented: $showLicenses) { MumlaLicensesSheet() }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased()).font(.system(.caption, design: .monospaced).weight(.medium))
            .foregroundStyle(MumlaStyle.secondary).accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private func readout(_ title: String, value: String) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) { Text(title); MumlaReadout(value) }
        } else {
            HStack(spacing: 16) { Text(title); Spacer(); MumlaReadout(value) }
        }
    }

    private func action(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }.buttonStyle(MumlaKeyStyle())
    }
}

private struct MumlaLicensesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Licenser", "Licenses"), closeLabel: mText("Tillbaka", "Back")) { dismiss() }
            ScrollView {
                Text("Pianissimo by KlangAI. CC BY 4.0. CoreML conversion and quantization by markstrom.\n\nFluidAudio by Fluid Inference. Apache 2.0.")
                    .font(.body).lineSpacing(6).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
        }.background { MumlaBackdrop() }.presentationBackground(MumlaStyle.background)
    }
}

struct TranscriptSheet: View {
    var record: DictationRecord
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    private var currentRecord: DictationRecord { session.history.first(where: { $0.id == record.id }) ?? record }

    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Diktering", "Dictation"), closeLabel: mText("Klart", "Done")) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                    CorrectableTranscript(record: currentRecord, session: session)
                        .padding(20).mumlaRecess(radius: 8)
                }.padding(24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 16) {
                Text(session.copiedID == record.id ? mText("Kopierat", "Copied") : "")
                    .font(.caption).foregroundStyle(MumlaStyle.accent)
                Spacer()
                ShareLink(item: currentRecord.text) {
                    Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                }.buttonStyle(MumlaKeyStyle()).accessibilityLabel(mText("Dela transkript", "Share transcript"))
                Button { session.copy(currentRecord) } label: {
                    Image(systemName: session.copiedID == record.id ? "checkmark" : "doc.on.doc").frame(width: 44, height: 44)
                }.buttonStyle(MumlaKeyStyle(feedback: false)).accessibilityLabel(mText("Kopiera transkript", "Copy transcript"))
            }.padding(24).background(MumlaStyle.background).overlay(alignment: .top) { Divider() }
        }
        .background { MumlaBackdrop() }.tint(MumlaStyle.accent)
        .presentationBackground(MumlaStyle.background)
    }
}

struct AddWordSheet: View {
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    @State private var original = ""
    @State private var replacement = ""

    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Nytt ord", "New word"), closeLabel: mText("Avbryt", "Cancel")) { dismiss() }
            ScrollView {
                VStack(spacing: 24) {
                    MumlaTextField(mText("Ersätt", "Replace"), text: $original)
                    MumlaTextField(mText("Med", "With"), text: $replacement)
                }.padding(24)
            }.autocorrectionDisabled().textInputAutocapitalization(.never)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                if session.addWord(original: original, replacement: replacement) { dismiss() }
            } label: {
                Label(mText("Spara", "Save"), systemImage: "checkmark")
                    .frame(maxWidth: .infinity).padding(16)
            }
            .buttonStyle(MumlaKeyStyle(feedback: false))
            .disabled(original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(24).background(MumlaStyle.background)
        }
        .background { MumlaBackdrop() }.tint(MumlaStyle.accent)
        .presentationBackground(MumlaStyle.background)
    }
}
