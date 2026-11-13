import MumlaCore
import MumlaUI
import MumlaFormatting
import SwiftUI

struct DictationTextSettingsView: View {
    @MumlaTheme private var palette
    @ObservedObject var coordinator: AppCoordinator
    var customize: () -> Void
    @State private var modelExpanded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "text.badge.star").frame(width: 22).foregroundStyle(palette.secondary)
                Text(mText("Formatera före inklistring", "Format before pasting"))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Toggle(mText("Formatera före inklistring", "Format before pasting"), isOn: Binding(
                    get: { coordinator.settings.formatDictationBeforePasting },
                    set: { coordinator.setFormatDictationBeforePasting($0) }
                ))
                .toggleStyle(MumlaSwitchStyle(showsLabel: false))
                .accessibilityIdentifier("settings.format-before-pasting")
                .help(mText("Lokala skiljetecken, stycken och listor. Orden bevaras. Tar extra tid.",
                            "Local punctuation, paragraphs and lists. Preserves words. Adds processing time."))
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
                    .mumlaFont(size: 11).foregroundStyle(palette.secondary)
                    .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.dictation-formatting-status")
            }
            Label(mText("Textmodell", "Text model"), systemImage: "cpu")
                .mumlaFont(size: 12)
            HStack(spacing: 4) {
                ForEach(TextModelProvider.allCases, id: \.self) { provider in
                    Button { coordinator.setTextModelProvider(provider) } label: {
                        Text(provider.displayName)
                            .mumlaFont(size: 11, weight: .semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MumlaStereoKeyStyle(isLatched: coordinator.settings.textModelProvider == provider, height: 44))
                    .accessibilityAddTraits(coordinator.settings.textModelProvider == provider ? .isSelected : [])
                    .accessibilityIdentifier("settings.text-model.\(provider.rawValue)")
                }
            }
            if coordinator.settings.textModelProvider == .qwen {
                DisclosureGroup(isExpanded: $modelExpanded) {
                    QwenTextModelControls(model: coordinator.textModel, isInUse: coordinator.isFormattingDictation)
                        .padding(.top, 12)
                } label: {
                    Label("Qwen3.5 4B", systemImage: "internaldrive")
                        .mumlaFont(size: 12)
                }
                .accessibilityIdentifier("settings.text-model")
            } else {
                HStack(spacing: 12) {
                    Label(coordinator.appleTextModelAvailability.textModelStatus,
                          systemImage: coordinator.appleTextModelAvailability == .available ? "checkmark.circle" : "exclamationmark.circle")
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { coordinator.refreshAppleTextModelAvailability() } label: {
                        Image(systemName: "arrow.clockwise").frame(width: 32, height: 32)
                    }
                    .buttonStyle(MumlaKeyStyle())
                    .help(mText("Kontrollera modellstatus", "Check model status"))
                    .accessibilityLabel(mText("Kontrollera modellstatus", "Check model status"))
                }
                    .mumlaFont(size: 12)
                    .foregroundStyle(palette.secondary)
                    .accessibilityIdentifier("settings.apple-text-model-status")
            }
        }
        .padding(.vertical, 16)
        .onAppear { coordinator.refreshAppleTextModelAvailability() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { coordinator.refreshAppleTextModelAvailability() }
        }
        .onChange(of: coordinator.settings.languageMode) { _, _ in coordinator.refreshAppleTextModelAvailability() }
        .onChange(of: coordinator.settings.lastLanguage) { _, _ in coordinator.refreshAppleTextModelAvailability() }
    }
}
