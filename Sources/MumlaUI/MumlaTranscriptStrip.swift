import SwiftUI

public struct MumlaTranscriptStrip: View {
    public let preview: String?
    public let text: String?
    public let copied: Bool
    public let copy: () -> Void

    public init(preview: String?, text: String?, copied: Bool, copy: @escaping () -> Void) {
        self.preview = preview; self.text = text; self.copied = copied; self.copy = copy
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(preview ?? mText("Ingen text än", "No transcript yet"))
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(preview == nil ? MumlaStyle.secondary : .primary)
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("latestTranscript.preview")
            Button(action: copy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 18, weight: .medium, design: .monospaced)).frame(width: 44, height: 44)
            }.buttonStyle(MumlaKeyStyle(feedback: false)).disabled(text == nil)
                .accessibilityLabel(mText("Kopiera transkript", "Copy transcript"))
                .accessibilityValue(copied ? mText("Kopierat", "Copied") : "")
                .accessibilityIdentifier("latestTranscript.copy")
                .help(mText("Kopiera transkript", "Copy transcript"))
            ShareLink(item: text ?? "") {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium, design: .monospaced)).frame(width: 44, height: 44)
            }.buttonStyle(MumlaKeyStyle()).disabled(text == nil)
                .accessibilityLabel(mText("Dela transkript", "Share transcript"))
                .accessibilityIdentifier("latestTranscript.share")
                .help(mText("Dela transkript", "Share transcript"))
        }
        .padding(8).padding(.leading, 6).frame(height: 60).mumlaRecess(radius: 8)
        .accessibilityElement(children: .contain)
    }
}
