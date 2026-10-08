import MumlaCore
import MumlaUI
import SwiftUI

public struct LocalTextPreferencesView: View {
    @AppStorage(LocalTextPreferences.formattingKey) private var savedFormatting = ""
    @AppStorage(LocalTextPreferences.summaryKey) private var savedSummary = ""
    @Environment(\.dismiss) private var dismiss
    @State private var formatting = ""
    @State private var summary = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Textpreferenser", "Text preferences"), closeLabel: mText("Avbryt", "Cancel"), closeIdentifier: "text-preferences.cancel") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    editor(mText("Formatering", "Formatting"), text: $formatting, identifier: "text-preferences.formatting")
                    editor(mText("Sammanfattning", "Summary"), text: $summary, identifier: "text-preferences.summary")
                }.padding(24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                MumlaIconButton("arrow.counterclockwise", label: mText("Återställ standard", "Reset to default")) {
                    formatting = ""
                    summary = ""
                }.accessibilityIdentifier("text-preferences.reset")
                Spacer()
                MumlaIconButton("checkmark", label: mText("Spara", "Save")) {
                    savedFormatting = LocalTextPreferences.boundedPrompt(formatting)
                    savedSummary = LocalTextPreferences.boundedPrompt(summary)
                    dismiss()
                }.accessibilityIdentifier("text-preferences.save")
            }.padding(24).background(MumlaStyle.background).overlay(alignment: .top) { Divider() }
        }
        .background { MumlaBackdrop() }.tint(MumlaStyle.accent).mumlaAppearance()
        .presentationBackground(MumlaStyle.background)
        .font(.system(.body, design: .monospaced)).fontDesign(.monospaced)
        .onAppear {
            formatting = LocalTextPreferences.boundedPrompt(savedFormatting)
            summary = LocalTextPreferences.boundedPrompt(savedSummary)
        }
        #if os(macOS)
        .frame(width: 580, height: 540)
        #endif
    }

    private func editor(_ title: String, text: Binding<String>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(text.wrappedValue.count) / \(LocalTextPreferences.maximumPromptCharacters)")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
            }
            TextEditor(text: text).scrollContentBackground(.hidden)
                .font(.system(.body, design: .monospaced)).padding(12).frame(minHeight: 130)
                .mumlaRecess(radius: 8).accessibilityLabel(title).accessibilityIdentifier(identifier)
                .onChange(of: text.wrappedValue) { _, value in
                    if value.count > LocalTextPreferences.maximumPromptCharacters {
                        text.wrappedValue = String(value.prefix(LocalTextPreferences.maximumPromptCharacters))
                    }
                }
        }
    }
}
