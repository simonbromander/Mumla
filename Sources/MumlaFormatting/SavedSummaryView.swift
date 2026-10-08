import MumlaUI
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct SavedSummaryView: View {
    private let summary: String
    @State private var copied = false
    public init(_ summary: String) { self.summary = summary }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(mText("Sammanfattning", "Summary")).font(.system(.headline, design: .monospaced))
                Spacer()
                ShareLink(item: summary) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
                    .buttonStyle(MumlaKeyStyle()).accessibilityLabel(mText("Dela sammanfattning", "Share summary"))
                    .help(mText("Dela sammanfattning", "Share summary"))
                MumlaIconButton(copied ? "checkmark" : "doc.on.doc", label: mText("Kopiera sammanfattning", "Copy summary")) {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(summary, forType: .string)
                    #else
                    UIPasteboard.general.string = summary
                    copied = true
                    #endif
                }
            }
            Text(summary).lineSpacing(6).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("transcript.saved-summary")
        }.padding(.vertical, 16).onChange(of: summary) { _, _ in copied = false }
    }
}
