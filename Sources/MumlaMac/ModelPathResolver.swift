import Foundation

enum ModelPathResolver {
    static func resolveCompiledPianissimoModel(fileManager: FileManager = .default) -> URL? {
        let candidates = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent("ModelCache/markstrom-pianissimo-sv-coreml-compiled", isDirectory: true),
            appSupportDirectory(fileManager: fileManager)
                .appendingPathComponent("Models/markstrom-pianissimo-sv-coreml-compiled", isDirectory: true)
        ]

        return candidates.first { candidate in
            requiredFiles.allSatisfy { fileManager.fileExists(atPath: candidate.appendingPathComponent($0).path) }
        }
    }

    private static let requiredFiles = [
        "Preprocessor.mlmodelc",
        "Encoder.mlmodelc",
        "Decoder.mlmodelc",
        "JointDecisionv3.mlmodelc",
        "parakeet_vocab.json"
    ]

    private static func appSupportDirectory(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Mumla", isDirectory: true)
    }
}
