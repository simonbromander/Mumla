import MumlaUI
import MumlaFormatting
import SwiftUI

struct DictationTextSettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    var customize: () -> Void
    @State private var modelExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "text.badge.star").frame(width: 22).foregroundStyle(MumlaStyle.secondary)
                Text(mText("Formatera före inklistring", "Format before pasting"))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Toggle(mText("Formatera före inklistring", "Format before pasting"), isOn: Binding(
                    get: { coordinator.settings.formatDictationBeforePasting },
                    set: { coordinator.setFormatDictationBeforePasting($0) }
                ))
                .toggleStyle(MumlaSwitchStyle(showsLabel: false))
                .accessibilityIdentifier("settings.format-before-pasting")
                .help(mText("Lokal formatering av skiljetecken och stycken. Originalet sparas. Tar extra tid.",
                            "Local punctuation and paragraph formatting. Keeps the original. Adds processing time."))
            }
            HStack(alignment: .center, spacing: 16) {
                Button(action: customize) {
                    Label(mText("Textpreferenser", "Text preferences"), systemImage: "slider.horizontal.3")
                        .padding(12)
                }
                .buttonStyle(MumlaKeyStyle())
                .accessibilityIdentifier("settings.text-preferences")
                Spacer(minLength: 0)
                Text(coordinator.isFormattingDictation ? mText("Formaterar…", "Formatting…")
                     : coordinator.dictationFormattingStatus ?? (coordinator.settings.formatDictationBeforePasting
                       ? mText("På · lokal modell", "On · local model") : mText("Av · direkt diktering", "Off · direct dictation")))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                    .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.dictation-formatting-status")
            }
            DisclosureGroup(isExpanded: $modelExpanded) {
                QwenTextModelControls(model: coordinator.textModel, isInUse: coordinator.isFormattingDictation)
                    .padding(.top, 12)
            } label: {
                Label(mText("Textmodell", "Text model") + " · Qwen3.5 4B", systemImage: "cpu")
                    .font(.system(size: 12, design: .monospaced))
            }
            .accessibilityIdentifier("settings.text-model")
        }
        .padding(.vertical, 16)
    }
}
