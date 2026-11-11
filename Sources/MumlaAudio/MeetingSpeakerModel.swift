#if os(macOS)
import CoreML
import Foundation
import MumlaCore

public actor MeetingSpeakerModel {
    public static let revision = "28ce1b1f8ef186729df63b3886fbaae7bc10c4a1"
    public static let files: [(path: String, sha256: String)] = [
        ("Manifest.json", "39cf44e7aaab8dda89c16d4f8e42d20bb9e33c8f65f2bc4c029944e24b7060b7"),
        ("Data/com.apple.CoreML/model.mlmodel", "cedf01fcea7289c508f0174575bc7f7cb6a932676c48bf6d17e6e8761e0e7ce1"),
        ("Data/com.apple.CoreML/weights/weight.bin", "0bf5dc575c0dcb1856eb21e25f401e9e45c183c663f6b6324404b650fdcdbec2")
    ]
    public nonisolated let directory: URL
    public nonisolated var modelURL: URL { directory.appendingPathComponent("speaker.mlmodelc") }
    public nonisolated var isInstalled: Bool { FileManager.default.fileExists(atPath: modelURL.appendingPathComponent("coremldata.bin").path) }

    public init(directory: URL) { self.directory = directory.appendingPathComponent("Models/LSEEND/" + Self.revision, isDirectory: true) }

    public nonisolated static func verifySource(for modelURL: URL) throws {
        let source = modelURL.deletingLastPathComponent().appendingPathComponent("speaker.mlpackage")
        for file in files {
            guard try ModelArtifactVerifier.sha256Hex(of: source.appendingPathComponent(file.path)) == file.sha256 else {
                throw MeetingStoreError.invalidData
            }
        }
    }

    public func install(progress: @escaping @Sendable (Double) -> Void) async throws {
        let source = directory.appendingPathComponent("speaker.mlpackage", isDirectory: true)
        for (index, file) in Self.files.enumerated() {
            try Task.checkCancellation()
            let destination = source.appendingPathComponent(file.path)
            if (try? ModelArtifactVerifier.sha256Hex(of: destination)) != file.sha256 {
                let base = "https://huggingface.co/FluidInference/ls-eend-coreml/resolve/\(Self.revision)/optimized/dih3/100ms/ls_eend_dih3_100ms.mlpackage/"
                let (temporary, response) = try await URLSession.shared.download(from: URL(string: base + file.path)!)
                defer { try? FileManager.default.removeItem(at: temporary) }
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      try ModelArtifactVerifier.sha256Hex(of: temporary) == file.sha256 else { throw MeetingStoreError.invalidData }
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try Data(contentsOf: temporary, options: .mappedIfSafe)
                try data.write(to: destination, options: .atomic)
            }
            progress(Double(index + 1) / 4)
        }
        try Task.checkCancellation()
        let compiled = try await MLModel.compileModel(at: source)
        if FileManager.default.fileExists(atPath: modelURL.path) { try FileManager.default.removeItem(at: modelURL) }
        try FileManager.default.copyItem(at: compiled, to: modelURL)
        progress(1)
    }
}
#endif
