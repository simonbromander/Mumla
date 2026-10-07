import MumlaCore
import MumlaUI
import SwiftUI

public struct TranscriptFormattingView: View {
    private let record: DictationRecord
    private let formatter: LocalTranscriptFormatter
    private let apply: @MainActor (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var result: FormattingResult?
    @State private var showOriginal = false
    @State private var saveFailed = false
    @State private var attempt = 0

    public init(record: DictationRecord, formatter: LocalTranscriptFormatter = .apple,
                apply: @escaping @MainActor (String) throws -> Void) {
        self.record = record
        self.formatter = formatter
        self.apply = apply
    }

    public var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Formatera text", "Format text"), closeLabel: mText("Avbryt", "Cancel"), closeIdentifier: "format.close") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let modeLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                    modeLayout {
                        modeKey(mText("Förslag", "Preview"), original: false)
                        modeKey(mText("Original", "Original"), original: true)
                    }
                    HStack(spacing: 10) {
                        if result == nil { ProgressView().controlSize(.small) }
                        else { Image(systemName: result?.status == .formatted ? "checkmark" : "info.circle") }
                        Text(status).font(.system(.callout, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("format.status")
                    }.foregroundStyle(MumlaStyle.secondary)
                    Text(showOriginal ? record.text : result?.text ?? record.text)
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
                        guard let result, result.status == .formatted else { return }
                        do { try apply(result.text); dismiss() }
                        catch { saveFailed = true }
                    }.disabled(result?.status != .formatted || scenePhase != .active)
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
            let response = await formatter.format(record.text, language: record.language, foreground: scenePhase == .active)
            guard !Task.isCancelled else { return }
            result = response
        }
        #if os(macOS)
        .frame(width: 580, height: 540)
        #endif
    }

    private struct Request: Hashable {
        let attempt: Int
        let phase: ScenePhase
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
        guard let result else { return mText("Formaterar…", "Formatting…") }
        switch result.status {
        case .formatted: return mText("Förslag klart", "Preview ready")
        case .unchanged: return mText("Inga ändringar", "No changes")
        case .tooLong: return mText("Texten är för lång för försöksversionen", "This text is too long for the trial")
        case .unsafeOutput: return mText("Förslaget ändrade innehållet. Originalet är kvar.", "The suggestion changed the content. Keeping the original.")
        case .failed: return mText("Kunde inte formatera. Originalet är kvar.", "Couldn't format. Keeping the original.")
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
