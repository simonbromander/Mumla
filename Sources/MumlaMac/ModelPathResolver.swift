import Foundation

enum ModelPathResolver {
    static func resolveCompiledPianissimoModel(fileManager: FileManager = .default) -> URL? {
        let candidates = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent("ModelCache/markstrom-pianissimo-sv-coreml-compiled", isDirectory: true),
            compiledPianissimoInstallDirectory(fileManager: fileManager)
        ]

        return candidates.first { candidate in
            isCompiledPianissimoModel(at: candidate, fileManager: fileManager)
        }
    }

    static func isCompiledPianissimoModel(at url: URL, fileManager: FileManager = .default) -> Bool {
        requiredFiles.allSatisfy { fileManager.fileExists(atPath: url.appendingPathComponent($0).path) }
    }

    static func portablePianissimoDownloadDirectory(fileManager: FileManager = .default) -> URL {
        appSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Downloads/markstrom-pianissimo-sv-coreml", isDirectory: true)
    }

    static func compiledPianissimoInstallDirectory(fileManager: FileManager = .default) -> URL {
        appSupportDirectory(fileManager: fileManager)
            .appendingPathComponent("Models/markstrom-pianissimo-sv-coreml-compiled", isDirectory: true)
    }

    private static let requiredFiles = [
        "Preprocessor.mlmodelc",
        "Encoder.mlmodelc",
        "Decoder.mlmodelc",
        "JointDecisionv3.mlmodelc",
        "parakeet_vocab.json"
    ]

    static func appSupportDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Mumla", isDirectory: true)
    }
}
