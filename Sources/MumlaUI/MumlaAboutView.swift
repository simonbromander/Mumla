import SwiftUI

public struct MumlaAboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notice: LicenseNotice?
    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Om Mumla", "About Mumla"), closeLabel: mText("Stäng", "Close"), closeIdentifier: "about.close") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        MumlaWordmark()
                        Spacer()
                        MumlaReadout(version)
                    }
                    Text(mText("Talmodellen körs på din enhet. Ljud och transkript skickas inte till någon transkriberingstjänst.", "The speech model runs on your device. Audio and transcripts are not sent to a transcription service."))
                        .font(.system(.callout, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                    Divider()
                    credit("Pianissimo-sv", owner: "Klang AI AB", license: "CC BY 4.0",
                           detail: mText("Den svenska talmodellen som används för diktering i den här versionen.", "The Swedish speech model used for dictation in this version."),
                           source: "https://huggingface.co/KlangAI/pianissimo-sv", licenseURL: "https://creativecommons.org/licenses/by/4.0/")
                    credit("Parakeet TDT 0.6B v3", owner: "NVIDIA", license: "CC BY 4.0",
                           detail: mText("Grundmodellen som Pianissimo är finjusterad från. En separat engelsk modell är ännu inte aktiverad i Mumla.", "The base model that Pianissimo was fine-tuned from. A separate English model is not yet enabled in Mumla."),
                           source: "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3", licenseURL: "https://creativecommons.org/licenses/by/4.0/")
                    credit("Pianissimo CoreML", owner: "markstrom", license: "CC BY 4.0",
                           detail: mText("Konverterad till CoreML, med ändrad attention-konfiguration för fasta 15-sekundersfönster. Encoderns vikter är int8-kvantiserade; decoder och joint använder fp16. Mumla har inte tränat om vikterna.", "Converted to CoreML with an adapted attention configuration for fixed 15-second windows. Encoder weights are quantized to int8; decoder and joint use fp16. Mumla has not retrained the weights."),
                           source: "https://huggingface.co/markstrom/pianissimo-sv-coreml", licenseURL: "https://creativecommons.org/licenses/by/4.0/")
                    credit("FluidAudio", owner: "Fluid Inference", license: "Apache 2.0",
                           detail: mText("Swift-biblioteket som kör CoreML-modellen lokalt på Apple-enheter.", "The Swift library that runs the CoreML model locally on Apple devices."),
                           source: "https://github.com/FluidInference/FluidAudio", licenseURL: "https://www.apache.org/licenses/LICENSE-2.0")
                    Text(mText("LICENSER OCH NOTISER", "LICENSES AND NOTICES"))
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary).accessibilityAddTraits(.isHeader)
                    ForEach(LicenseNotice.all) { item in
                        Button { notice = item } label: {
                            HStack {
                                Text(item.title).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "doc.text")
                            }.padding(14).frame(maxWidth: .infinity)
                        }.buttonStyle(MumlaKeyStyle()).accessibilityIdentifier("about.notice.\(item.id)")
                    }
                }.padding(24)
            }.accessibilityIdentifier("about.content")
        }
        .font(.system(.body, design: .monospaced)).fontDesign(.monospaced)
        .background { MumlaBackdrop() }.tint(MumlaStyle.accent).preferredColorScheme(.dark)
        .presentationBackground(MumlaStyle.background)
        .sheet(item: $notice) { item in
            VStack(spacing: 0) {
                MumlaPanelHeader(item.title, closeLabel: mText("Tillbaka", "Back"), closeIdentifier: "about.notice.close") { notice = nil }
                ScrollView {
                    Text(item.contents).font(.system(.footnote, design: .monospaced)).lineSpacing(5).textSelection(.enabled)
                        .accessibilityIdentifier("about.notice.text")
                        .frame(maxWidth: .infinity, alignment: .leading).padding(24)
                }
            }.background { MumlaBackdrop() }.preferredColorScheme(.dark)
                .presentationBackground(MumlaStyle.background)
                #if os(macOS)
                .frame(width: 580, height: 520)
                #endif
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let version = info["CFBundleShortVersionString"] as? String else { return mText("Utveckling", "Development") }
        if let build = info["CFBundleVersion"] as? String { return "\(version) (\(build))" }
        return version
    }

    private func credit(_ title: String, owner: String, license: String, detail: String, source: String, licenseURL: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(.headline, design: .monospaced)).accessibilityAddTraits(.isHeader)
            Text(owner).font(.system(.subheadline, design: .monospaced)).foregroundStyle(MumlaStyle.accent)
            Text(detail).font(.system(.callout, design: .monospaced)).foregroundStyle(MumlaStyle.secondary).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { creditLinks(source: source, license: license, licenseURL: licenseURL) }
                VStack(alignment: .leading, spacing: 12) { creditLinks(source: source, license: license, licenseURL: licenseURL) }
            }.font(.system(.caption, design: .monospaced)).buttonStyle(MumlaKeyStyle())
            Divider().padding(.top, 8)
        }
    }

    @ViewBuilder private func creditLinks(source: String, license: String, licenseURL: String) -> some View {
        Link(destination: URL(string: source)!) {
            Label(mText("Källa", "Source"), systemImage: "arrow.up.right").padding(12)
        }
        Link(destination: URL(string: licenseURL)!) {
            Label(license, systemImage: "doc.text").padding(12)
        }
    }
}

private struct LicenseNotice: Identifiable {
    let title: String
    let file: String
    let ext: String
    var id: String { file }
    var contents: String {
        guard let url = Bundle.module.url(forResource: file, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return mText("Notisen kunde inte läsas.", "The notice could not be read.") }
        return text
    }
    static let all = [
        LicenseNotice(title: "Pianissimo / CoreML", file: "Pianissimo-attribution", ext: "txt"),
        LicenseNotice(title: "FluidAudio / Apache 2.0", file: "FluidAudio-LICENSE", ext: "txt"),
        LicenseNotice(title: "fastcluster", file: "fastcluster-LICENSE", ext: "md"),
        LicenseNotice(title: "NeMo Text Processing", file: "NemoTextProcessing-LICENSE", ext: "md"),
        LicenseNotice(title: "VBx", file: "vbx-LICENSE", ext: "md"),
        LicenseNotice(title: "Japanese G2P", file: "JapaneseG2P-LICENSE", ext: "md"),
        LicenseNotice(title: "Kokoro G2P", file: "KokoroAneSpanishFrenchG2P-LICENSE", ext: "md")
    ]
}
