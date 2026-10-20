#if os(macOS)
import MumlaUI
import SwiftUI

public struct QwenTextModelControls: View {
    @ObservedObject private var model: QwenTextModel
    public init(model: QwenTextModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Qwen3.5 4B · 4-bit")
                .font(.system(.callout, design: .monospaced))
            Text(mText("Körs lokalt på Apple Silicon. Hämta cirka 3,1 GB en gång.",
                       "Runs locally on Apple Silicon. Download approximately 3.1 GB once."))
                .font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(mText("Modellen använder cirka 3 GB minne efter första användningen.",
                       "The model uses approximately 3 GB of memory after first use."))
                .font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !model.supportsDevice {
                Text(mText("Kräver en Mac med Apple Silicon", "Requires a Mac with Apple Silicon"))
            } else if let progress = model.downloadProgress {
                MumlaDownloadGauge(fraction: progress)
                Button { model.cancelDownload() } label: {
                    Text(mText("Avbryt hämtning", "Cancel download")).padding(12)
                }
                    .accessibilityIdentifier("text-model.cancel")
            } else if model.isInstalled {
                HStack(spacing: 12) {
                    Label(mText("Installerad", "Installed"), systemImage: "checkmark")
                    Button { model.remove() } label: {
                        Text(mText("Ta bort modell", "Remove model")).padding(12)
                    }
                        .disabled(model.isRemoving).accessibilityIdentifier("text-model.remove")
                }
            } else {
                Button { model.download() } label: {
                    Text(mText("Hämta textmodell", "Download text model")).padding(12)
                }
                    .disabled(model.isRemoving).accessibilityIdentifier("text-model.download")
            }
            if model.failed {
                Text(mText("Åtgärden misslyckades. Försök igen.", "The operation failed. Try again."))
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                    .accessibilityIdentifier("text-model.error")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(MumlaKeyStyle())
            .onAppear { model.refresh() }
            .accessibilityElement(children: .contain)
    }
}
#endif
