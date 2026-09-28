import MumlaCore
import MumlaUI
import SwiftUI

struct MumlaSettingsSheet: View {
    @AppStorage("mumla.hapticsEnabled") private var hapticsEnabled = true
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section(mText("Diktering", "Dictation")) {
                    Toggle(mText("Haptisk återkoppling", "Haptic feedback"), isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { _, enabled in if enabled { MumlaFeedback.press() } }
                    LabeledContent(mText("Språk", "Language"), value: "Svenska")
                    LabeledContent(mText("Språkmodell", "Language model"), value: session.modelReady ? mText("Installerad", "Installed") : mText("Inte hämtad", "Not downloaded"))
                    if !session.modelReady {
                        Button(mText("Hämta svenska", "Download Swedish")) { Task { await session.install() } }
                            .disabled(session.isInstalling)
                    }
                    Button(mText("Mikrofonbehörighet", "Microphone permission")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Section(mText("Om Mumla", "About Mumla")) {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                    NavigationLink(mText("Licenser", "Licenses")) {
                        ScrollView {
                            Text("Pianissimo by KlangAI. CC BY 4.0. CoreML conversion and quantization by markstrom.\n\nFluidAudio by Fluid Inference. Apache 2.0.")
                                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        }.navigationTitle(mText("Licenser", "Licenses"))
                    }
                }
            }
            .navigationTitle(mText("Inställningar", "Settings"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(mText("Klart", "Done")) { dismiss() } } }
        }.tint(MumlaStyle.accent).preferredColorScheme(.dark)
    }
}

struct TranscriptSheet: View {
    var record: DictationRecord
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    private var currentRecord: DictationRecord { session.history.first(where: { $0.id == record.id }) ?? record }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(MumlaStyle.secondary)
                    CorrectableTranscript(record: currentRecord, session: session)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            .navigationTitle(mText("Diktering", "Dictation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(mText("Klart", "Done")) { dismiss() } }
                ToolbarItemGroup(placement: .bottomBar) {
                    ShareLink(item: currentRecord.text) { Image(systemName: "square.and.arrow.up") }
                    Spacer()
                    Button { session.copy(currentRecord) } label: {
                        Label(session.copiedID == record.id ? mText("Kopierat", "Copied") : mText("Kopiera", "Copy"), systemImage: session.copiedID == record.id ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }.tint(MumlaStyle.accent)
    }
}

struct AddWordSheet: View {
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    @State private var original = ""
    @State private var replacement = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField(mText("Ersätt", "Replace"), text: $original)
                TextField(mText("Med", "With"), text: $replacement)
            }
            .autocorrectionDisabled()
            .navigationTitle(mText("Nytt ord", "New word"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(mText("Avbryt", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mText("Spara", "Save")) {
                        if session.addWord(original: original, replacement: replacement) { dismiss() }
                    }
                    .disabled(original.trimmingCharacters(in: .whitespaces).isEmpty || replacement.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }.presentationDetents([.medium, .large]).tint(MumlaStyle.accent)
    }
}
