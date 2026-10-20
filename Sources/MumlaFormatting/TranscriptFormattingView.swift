import MumlaCore
import MumlaUI
import SwiftUI

public enum TranscriptTextAction: String, Identifiable {
    case format, summary
    public var id: Self { self }
}

public struct TranscriptTextRequest: Identifiable {
    public let record: DictationRecord
    public let action: TranscriptTextAction
    public var id: UUID { record.id }
    public init(record: DictationRecord, action: TranscriptTextAction) {
        self.record = record
        self.action = action
    }
}

public struct TranscriptFormattingView: View {
    private let record: DictationRecord
    private let action: TranscriptTextAction
    private let formatter: LocalTranscriptFormatter
    private let summarizer: LocalTranscriptSummarizer
    private let apply: @MainActor (String) throws -> Void
    @AppStorage(LocalTextPreferences.formattingKey) private var formattingPrompt = ""
    @AppStorage(LocalTextPreferences.summaryKey) private var summaryPrompt = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var result: FormattingResult?
    @State private var showOriginal = false
    @State private var saveFailed = false
    @State private var attempt = 0
    @State private var precedingText = ""
    @State private var generatedContext = ""

    public init(record: DictationRecord, action: TranscriptTextAction = .format, formatter: LocalTranscriptFormatter = .apple,
                summarizer: LocalTranscriptSummarizer = .apple,
                apply: @escaping @MainActor (String) throws -> Void) {
        self.record = record
        self.action = action
        self.formatter = formatter
        self.summarizer = summarizer
        self.apply = apply
    }

    public var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(action == .format ? mText("Formatera text", "Format text") : mText("Sammanfattning", "Summary"), closeLabel: mText("Avbryt", "Cancel"), closeIdentifier: "format.close") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if action == .format {
                        conversationContext
                    }
                    let modeLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                    modeLayout {
                        modeKey(mText("Förslag", "Preview"), original: false)
                        modeKey(mText("Original", "Original"), original: true)
                    }
                    HStack(spacing: 10) {
                        if result == nil { ProgressView().controlSize(.small) }
                        else { Image(systemName: canApply ? "checkmark" : "info.circle") }
                        Text(status).font(.system(.callout, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("format.status")
                    }.foregroundStyle(MumlaStyle.secondary)
                    Text(preview)
                        .font(.system(.body, design: .monospaced)).lineSpacing(6).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(20).mumlaRecess(radius: 8)
                        .accessibilityIdentifier("format.preview")
                }.padding(24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            let footerLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            footerLayout {
                Label(mText("Lokalt", "On-device"), systemImage: "lock")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    MumlaIconButton("arrow.clockwise", label: mText("Försök igen", "Retry")) { attempt += 1 }
                        .disabled(result == nil).accessibilityIdentifier("format.retry")
                    MumlaIconButton("checkmark", label: mText("Använd förslag", "Use suggestion")) {
                        guard let result, canApply else { return }
                        do { try apply(result.text); dismiss() }
                        catch { saveFailed = true }
                    }.disabled(!canApply || scenePhase != .active)
                        .accessibilityIdentifier("format.apply")
                }
            }.padding(24).background(MumlaStyle.background).overlay(alignment: .top) { Divider() }
        }
        .background { MumlaBackdrop() }.tint(MumlaStyle.accent).mumlaAppearance()
        .presentationBackground(MumlaStyle.background)
        .font(.system(.body, design: .monospaced)).fontDesign(.monospaced)
        .task(id: Request(attempt: attempt, phase: scenePhase)) {
            result = nil
            saveFailed = false
            let context = LocalTextPreferences.boundedContext(precedingText)
            let response: FormattingResult
            if action == .format {
                response = await formatter.format(record.text, language: record.language, foreground: scenePhase == .active,
                                                  stylePrompt: formattingPrompt, precedingText: context)
            } else {
                response = await summarizer.summarize(record.text, language: record.language, foreground: scenePhase == .active,
                                                      stylePrompt: summaryPrompt)
            }
            guard !Task.isCancelled else { return }
            generatedContext = context
            result = response
        }
        #if os(macOS)
        .frame(width: 580, height: 540)
        #endif
    }

    private var conversationContext: some View {
        DisclosureGroup(mText("Föregående samtal (valfritt)", "Preceding conversation (optional)")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(mText("Lägg till relevanta meddelanden, högst 600 tecken. Kontexten används bara i denna förhandsvisning.",
                           "Add relevant messages, up to 600 characters. The context stays in this preview."))
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                TextEditor(text: $precedingText).scrollContentBackground(.hidden)
                    .frame(minHeight: 80).padding(12).mumlaRecess(radius: 8)
                    .accessibilityLabel(mText("Föregående samtal", "Preceding conversation"))
                    .accessibilityIdentifier("format.context")
                    .onChange(of: precedingText) { _, value in
                        if value.count > LocalTextPreferences.maximumContextCharacters {
                            precedingText = String(value.prefix(LocalTextPreferences.maximumContextCharacters))
                        }
                    }
                Button(mText("Uppdatera förslag", "Update preview")) { attempt += 1 }
                    .buttonStyle(MumlaKeyStyle()).disabled(result == nil || scenePhase != .active)
                    .accessibilityIdentifier("format.update-context")
            }.padding(.top, 12)
        }.accessibilityIdentifier("format.context-section")
    }

    private struct Request: Hashable {
        let attempt: Int
        let phase: ScenePhase
    }

    private var canApply: Bool {
        generatedContext == LocalTextPreferences.boundedContext(precedingText)
            && result?.status == (action == .format ? .formatted : .summarized)
    }

    private var preview: String {
        if showOriginal { return record.text }
        return result?.text ?? (action == .format ? record.text : "")
    }

    private func modeKey(_ title: String, original: Bool) -> some View {
        Button { showOriginal = original } label: {
            Text(title).font(.system(.caption, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }.buttonStyle(MumlaStereoKeyStyle(isLatched: showOriginal == original, height: typeSize.isAccessibilitySize ? 100 : 48))
            .accessibilityAddTraits(showOriginal == original ? .isSelected : [])
            .accessibilityIdentifier(original ? "format.original" : "format.formatted")
    }

    private var status: String {
        if saveFailed { return mText("Kunde inte spara. Originalet är kvar.", "Couldn't save. Keeping the original.") }
        guard let result else { return action == .format ? mText("Formaterar…", "Formatting…") : mText("Sammanfattar…", "Summarizing…") }
        if generatedContext != LocalTextPreferences.boundedContext(precedingText) {
            return mText("Uppdatera förslaget för att använda ändrad kontext", "Update the preview to use the changed context")
        }
        switch result.status {
        case .formatted: return mText("Förslag klart", "Preview ready")
        case .summarized: return mText("Kontrollera förslaget före användning", "Review the suggestion before using it")
        case .unchanged: return mText("Inga ändringar", "No changes")
        case .tooLong: return mText("Texten är för lång för försöksversionen", "This text is too long for the trial")
        case .unsafeOutput:
            return action == .format ? mText("Förslaget ändrade innehållet. Originalet är kvar.", "The suggestion changed the content. Keeping the original.") : mText("Kunde inte skapa ett giltigt förslag", "Couldn't create a valid suggestion")
        case .failed: return mText("Kunde inte skapa förslag. Originalet är kvar.", "Couldn't create a suggestion. Keeping the original.")
        case .cancelled: return mText("Avbrutet", "Cancelled")
        case .background: return mText("Pausat", "Paused")
        case .unavailable(let reason):
            switch reason {
            case .available: return ""
            case .systemTooOld: return mText("Kräver iOS 26 eller macOS 26", "Requires iOS 26 or macOS 26")
            case .deviceNotEligible: return mText("Apple Intelligence stöds inte på enheten", "This device doesn't support Apple Intelligence")
            case .intelligenceDisabled: return mText("Apple Intelligence är avstängt", "Apple Intelligence is turned off")
            case .modelNotReady: return mText("Apple Intelligence är inte redo", "Apple Intelligence isn't ready")
            case .unsupportedLanguage: return mText("Språket stöds inte på enheten", "This language isn't supported on this device")
            }
        }
    }
}
