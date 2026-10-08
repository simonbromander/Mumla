import MumlaCore
import MumlaFormatting
import MumlaUI
import SwiftUI

struct MumlaSettingsSheet: View {
    @AppStorage("mumla.hapticsEnabled") private var hapticsEnabled = true
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showAbout = false
    @State private var showKeyboard = false
    @State private var showTextPreferences = false

    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Inställningar", "Settings"), closeLabel: mText("Klart", "Done")) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sectionTitle(mText("Utseende", "Appearance"))
                    MumlaAppearancePicker()
                    Divider()
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
                    action(mText("Mumla-tangentbord", "Mumla keyboard"), symbol: "keyboard") { showKeyboard = true }
                        .accessibilityIdentifier("settings.keyboard")
                    action(mText("Textpreferenser", "Text preferences"), symbol: "text.badge.star") { showTextPreferences = true }
                        .accessibilityIdentifier("settings.text-preferences")
                    Divider().padding(.vertical, 4)
                    sectionTitle(mText("Om Mumla", "About Mumla"))
                    readout("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                    action(mText("Om Mumla", "About Mumla"), symbol: "info.circle") { showAbout = true }
                        .accessibilityIdentifier("settings.about")
                }.padding(24)
            }
        }
        .background { MumlaBackdrop() }
        .tint(MumlaStyle.accent).mumlaAppearance()
        .presentationBackground(MumlaStyle.background)
        .font(.system(.body, design: .monospaced)).fontDesign(.monospaced)
        .sheet(isPresented: $showAbout) { MumlaAboutView() }
        .sheet(isPresented: $showKeyboard) { KeyboardSetupSheet(session: session) }
        .sheet(isPresented: $showTextPreferences) { LocalTextPreferencesView() }
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

struct TranscriptSheet: View {
    var record: DictationRecord
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    @State private var textRequest: TranscriptTextRequest?
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
                    if let summary = currentRecord.summary { SavedSummaryView(summary) }
                }.padding(24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 16) {
                if currentRecord.originalText != nil {
                    MumlaIconButton("arrow.uturn.backward", label: mText("Återställ original", "Restore original")) {
                        session.restoreOriginal(currentRecord)
                    }.accessibilityIdentifier("transcript.restore")
                }
                MumlaIconButton("text.badge.checkmark", label: mText("Formatera text", "Format text")) {
                    textRequest = TranscriptTextRequest(record: currentRecord, action: .format)
                }.accessibilityIdentifier("transcript.format")
                MumlaIconButton("text.alignleft", label: mText("Sammanfatta", "Summarize")) {
                    textRequest = TranscriptTextRequest(record: currentRecord, action: .summary)
                }.accessibilityIdentifier("transcript.summarize")
                Spacer()
                ShareLink(item: currentRecord.text) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium, design: .monospaced)).frame(width: 44, height: 44)
                }.buttonStyle(MumlaKeyStyle()).accessibilityLabel(mText("Dela transkript", "Share transcript")).accessibilityIdentifier("transcript.share")
                Button { session.copy(currentRecord) } label: {
                    Image(systemName: session.copiedID == record.id ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 18, weight: .medium, design: .monospaced)).frame(width: 44, height: 44)
                }.buttonStyle(MumlaKeyStyle(feedback: false)).accessibilityLabel(mText("Kopiera transkript", "Copy transcript")).accessibilityIdentifier("transcript.copy")
            }.padding(24).background(MumlaStyle.background).overlay(alignment: .top) { Divider() }
        }
        .background { MumlaBackdrop() }.tint(MumlaStyle.accent)
        .presentationBackground(MumlaStyle.background)
        .font(.system(.body, design: .monospaced)).fontDesign(.monospaced)
        .sheet(item: $textRequest) { request in
            TranscriptFormattingView(record: request.record, action: request.action, formatter: transcriptFormatter, summarizer: transcriptSummarizer) { text in
                if request.action == .format { try session.applyFormatting(request.record, text: text) }
                else { try session.applySummary(request.record, text: text) }
            }
        }
    }

    private var transcriptFormatter: LocalTranscriptFormatter {
        #if DEBUG
        if CommandLine.arguments.contains("--ui-testing") {
            if CommandLine.arguments.contains("--formatting-success-fixture") {
                return LocalTranscriptFormatter(availability: { _ in .available }, generate: { _, _, _ in
                    "Hej Simon. Vi ses klockan 14:30."
                })
            }
            return LocalTranscriptFormatter(availability: { _ in .intelligenceDisabled }, generate: { text, _, _ in text })
        }
        #endif
        return .apple
    }

    private var transcriptSummarizer: LocalTranscriptSummarizer {
        #if DEBUG
        if CommandLine.arguments.contains("--ui-testing") {
            if CommandLine.arguments.contains("--summary-success-fixture") {
                return LocalTranscriptSummarizer(availability: { _ in .available }, generate: { _, _, _ in "Vi ses klockan 14:30." })
            }
            return LocalTranscriptSummarizer(availability: { _ in .intelligenceDisabled }, generate: { _, _, _ in "" })
        }
        #endif
        return .apple
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
        .font(.system(.body, design: .monospaced)).fontDesign(.monospaced)
    }
}
