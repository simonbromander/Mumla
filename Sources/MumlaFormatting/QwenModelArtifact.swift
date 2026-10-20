import Foundation
import MumlaCore

public enum QwenModelArtifact {
    public static let revision = "32f3e8ecf65426fc3306969496342d504bfa13f3"
    public static let artifact = ModelArtifact(
        id: "mlx-community/Qwen3.5-4B-MLX-4bit",
        sourceURL: URL(string: "https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit")!,
        revision: revision,
        files: [
            ModelArtifactFile(path: "config.json", byteCount: 3_366,
                sha256: "f3efc81b2ea8d96a45301037d3ccccbcccdef44a961845c87f286aaddbc6eaaa"),
            ModelArtifactFile(path: "tokenizer_config.json", byteCount: 1_139,
                sha256: "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182"),
            ModelArtifactFile(path: "chat_template.jinja", byteCount: 7_756,
                sha256: "a4aee8afcf2e0711942cf848899be66016f8d14a889ff9ede07bca099c28f715"),
            ModelArtifactFile(path: "model.safetensors.index.json", byteCount: 101_944,
                sha256: "52e534c41f7b97708329c85f762e5882bf48bd5955a422c6ae74eba321e6048a"),
            ModelArtifactFile(path: "tokenizer.json", byteCount: 19_989_343,
                sha256: "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"),
            ModelArtifactFile(path: "model.safetensors", byteCount: 3_034_300_695,
                sha256: "5fb9acd0246866381cf8c5c354c6db1019f6498eec4ccb4f5edcc71ffeacb2db")
        ])

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Mumla/Models/Qwen3.5-4B/\(revision)", isDirectory: true)
    }
}

struct QwenModelStore: Sendable {
    let directory: URL
    let artifact: ModelArtifact

    init(directory: URL, artifact: ModelArtifact = QwenModelArtifact.artifact) {
        self.directory = directory
        self.artifact = artifact
    }

    private var marker: URL { directory.appendingPathComponent("verified-revision") }

    var isInstalled: Bool {
        guard let revision = artifact.revision,
              (try? String(contentsOf: marker, encoding: .utf8)) == revision else { return false }
        return artifact.files.allSatisfy { file in
            let values = try? directory.appendingPathComponent(file.path).resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            return values?.isRegularFile == true && values?.fileSize.map(Int64.init) == file.byteCount
        }
    }

    func verify() throws {
        let issues = ModelArtifactVerifier.verify(artifact: artifact, baseDirectory: directory)
        guard issues.isEmpty else {
            try? FileManager.default.removeItem(at: marker)
            throw QwenModelError.invalidFiles
        }
    }

    func markInstalled() throws {
        try verify()
        guard let revision = artifact.revision else { throw QwenModelError.invalidFiles }
        try Data(revision.utf8).write(to: marker, options: .atomic)
    }

    func remove() throws {
        try? FileManager.default.removeItem(at: marker)
        for file in artifact.files {
            let url = directory.appendingPathComponent(file.path)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }
}

enum QwenModelError: Error {
    case invalidFiles, downloadFailed, busy, unsupportedDevice
}
