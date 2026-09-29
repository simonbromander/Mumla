import MumlaCore
import MumlaUI
import SwiftUI
import UIKit

struct CorrectableTranscript: View {
    let record: DictationRecord
    @ObservedObject var session: DictationSession
    var preview = false
    @State private var selection: TranscriptWordSelection?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        SelectableTranscriptText(
            record: record,
            preview: preview,
            dynamicTypeSize: dynamicTypeSize,
            onCorrect: { selection = $0 }
        )
        .sheet(item: $selection) { word in
            CorrectWordSheet(selection: word, session: session)
        }
    }
}

private struct SelectableTranscriptText: UIViewRepresentable {
    let record: DictationRecord
    let preview: Bool
    let dynamicTypeSize: DynamicTypeSize
    let onCorrect: (TranscriptWordSelection) -> Void

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: false)
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = preview ? 4 : 7
        let text = NSAttributedString(string: record.text, attributes: [
            .font: UIFont.preferredFont(forTextStyle: preview ? .body : .title3),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraph
        ])
        if view.attributedText != text { view.attributedText = text }
        view.tintColor = UIColor(MumlaStyle.accent)
        view.textContainer.maximumNumberOfLines = preview ? 6 : 0
        view.textContainer.lineBreakMode = preview ? .byTruncatingTail : .byWordWrapping
        view.accessibilityIdentifier = preview ? "latestTranscript.preview" : "transcript.text"
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        uiView.textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        uiView.layoutManager.ensureLayout(for: uiView.textContainer)
        return CGSize(width: width, height: ceil(uiView.layoutManager.usedRect(for: uiView.textContainer).height))
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTranscriptText
        init(parent: SelectableTranscriptText) { self.parent = parent }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard textView.text == parent.record.text,
                  let selection = TranscriptWordSelection(record: parent.record, range: range) else {
                return UIMenu(children: suggestedActions)
            }
            let correct = UIAction(title: mText("Rätta ord", "Correct word"), image: UIImage(systemName: "pencil")) { [weak self, weak textView] _ in
                textView?.resignFirstResponder()
                self?.parent.onCorrect(selection)
            }
            return UIMenu(children: [correct] + suggestedActions)
        }
    }
}

private struct CorrectWordSheet: View {
    let selection: TranscriptWordSelection
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var replacement = ""
    @State private var error: String?

    private var word: String { replacement.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Rätta ord", "Correct word"), closeLabel: mText("Avbryt", "Cancel"), closeIdentifier: "correction.cancel") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mText("Ersätt", "Replace")).font(.caption).foregroundStyle(MumlaStyle.secondary)
                        Text(selection.original).font(.title3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16).mumlaRecess(radius: 8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mText("Med", "With")).font(.caption).foregroundStyle(MumlaStyle.secondary)
                        TextField(mText("Rätt stavning", "Correct spelling"), text: $replacement, prompt: Text(selection.original))
                            .font(.title3).autocorrectionDisabled().textInputAutocapitalization(.never)
                            .focused($focused).submitLabel(.done).onSubmit(save)
                            .accessibilityIdentifier("correction.replacement")
                            .padding(16).mumlaRecess(radius: 8)
                    }
                    if !word.isEmpty && !TranscriptWordSelection.isWord(word) {
                        Text(mText("Ange ett ord.", "Enter a single word.")).font(.caption).foregroundStyle(MumlaStyle.secondary)
                    }
                    if let error { Text(error).font(.callout).foregroundStyle(MumlaStyle.recording) }
                }.padding(24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: save) {
                Label(mText("Spara i ordlistan", "Save to dictionary"), systemImage: "checkmark")
                    .frame(maxWidth: .infinity).padding(16)
            }
            .buttonStyle(MumlaKeyStyle(feedback: false)).disabled(!canSave)
            .accessibilityIdentifier("correction.save")
            .padding(24).background(MumlaStyle.background)
        }
        .background { MumlaBackdrop() }
        .presentationBackground(MumlaStyle.background)
        .tint(MumlaStyle.accent).preferredColorScheme(.dark)
        .onAppear { focused = true }
    }

    private var canSave: Bool { TranscriptWordSelection.isWord(word) && word != selection.original }

    private func save() {
        guard canSave else { return }
        do {
            try session.correctWord(selection, replacement: word)
            dismiss()
        } catch TranscriptCorrectionError.transcriptChanged {
            error = mText("Texten har ändrats. Markera ordet igen.", "The transcript changed. Select the word again.")
            MumlaFeedback.error()
        } catch TranscriptCorrectionError.dictionaryRollbackFailed {
            error = mText("Ordlistan sparades men texten kunde inte uppdateras. Försök igen.", "The dictionary was saved but the transcript could not be updated. Try again.")
            MumlaFeedback.error()
        } catch {
            self.error = mText("Kunde inte spara. Försök igen. ", "Could not save. Try again. ") + error.localizedDescription
            MumlaFeedback.error()
        }
    }
}
