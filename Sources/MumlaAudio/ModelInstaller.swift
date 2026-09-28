import CoreML
import Foundation
import MumlaCore

public struct ModelInstallProgress: Equatable, Sendable {
    public enum Phase: String, Sendable {
        case idle
        case downloading
        case verifying
        case compiling
        case installed
        case failed
    }

    public var phase: Phase
    public var fraction: Double
    public var detail: String

    public init(phase: Phase, fraction: Double, detail: String) {
        self.phase = phase
        self.fraction = fraction
        self.detail = detail
    }

    public static let idle = ModelInstallProgress(phase: .idle, fraction: 0, detail: "")
}

public actor ModelInstaller {
    private let artifact: ModelArtifact
    private let downloadDirectory: URL
    private let compiledDirectory: URL
    private let fileManager: FileManager

    public init(
        artifact: ModelArtifact = MumlaModelArtifacts.communityPianissimoCoreML,
        downloadDirectory: URL = ModelPathResolver.portablePianissimoDownloadDirectory(),
        compiledDirectory: URL = ModelPathResolver.compiledPianissimoInstallDirectory(),
        fileManager: FileManager = .default
    ) {
        self.artifact = artifact
        self.downloadDirectory = downloadDirectory
        self.compiledDirectory = compiledDirectory
        self.fileManager = fileManager
    }

    public func install(progress: @Sendable (ModelInstallProgress) async -> Void) async throws -> URL {
        if ModelPathResolver.isCompiledPianissimoModel(at: compiledDirectory, fileManager: fileManager) {
            await progress(ModelInstallProgress(phase: .installed, fraction: 1, detail: "Model ready"))
            return compiledDirectory
        }

        try await download(progress: progress)
        await progress(ModelInstallProgress(phase: .verifying, fraction: 0.72, detail: "Checking files"))
        let issues = ModelArtifactVerifier.verify(
            artifact: artifact,
            baseDirectory: downloadDirectory,
            fileManager: fileManager
        )
        if !issues.isEmpty {
            throw ModelInstallerError.verificationFailed(issues.map(\.description).joined(separator: "\n"))
        }

        try await compile(progress: progress)
        await progress(ModelInstallProgress(phase: .installed, fraction: 1, detail: "Model ready"))
        return compiledDirectory
    }

    private func download(progress: @Sendable (ModelInstallProgress) async -> Void) async throws {
        guard let revision = artifact.revision else {
            throw ModelInstallerError.missingRevision
        }

        let totalBytes = artifact.files.reduce(Int64(0)) { $0 + ($1.byteCount ?? 0) }
        var completedBytes = Int64(0)

        for file in artifact.files {
            let destination = downloadDirectory.appendingPathComponent(file.path)
            let expectedSize = file.byteCount ?? 0
            if try isFileAlreadyValid(file, at: destination) {
                completedBytes += expectedSize
                await progress(downloadProgress(completedBytes: completedBytes, totalBytes: totalBytes, detail: file.path))
                continue
            }

            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let partial = destination.appendingPathExtension("part")
            var existingBytes = (try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            if existingBytes > expectedSize {
                try? fileManager.removeItem(at: partial)
                existingBytes = 0
            }

            var request = URLRequest(url: resolveURL(repoID: artifact.id, revision: revision, path: file.path))
            if existingBytes > 0 {
                request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
            }

            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            if
                existingBytes > 0,
                let http = response as? HTTPURLResponse,
                http.statusCode != 206
            {
                try? fileManager.removeItem(at: partial)
                existingBytes = 0
            }

            if !fileManager.fileExists(atPath: partial.path) {
                fileManager.createFile(atPath: partial.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: partial)
            try handle.seekToEnd()
            defer {
                try? handle.close()
            }

            var buffer = [UInt8]()
            buffer.reserveCapacity(64 * 1024)
            var downloadedForFile = existingBytes

            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= 64 * 1024 {
                    try handle.write(contentsOf: buffer)
                    downloadedForFile += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    await progress(
                        downloadProgress(
                            completedBytes: completedBytes + downloadedForFile,
                            totalBytes: totalBytes,
                            detail: file.path
                        )
                    )
                }
            }

            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
                downloadedForFile += Int64(buffer.count)
            }

            guard downloadedForFile == expectedSize else {
                throw ModelInstallerError.sizeMismatch(path: file.path, expected: expectedSize, actual: downloadedForFile)
            }

            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: partial, to: destination)

            if try !isFileAlreadyValid(file, at: destination) {
                try? fileManager.removeItem(at: destination)
                throw ModelInstallerError.checksumMismatch(file.path)
            }

            completedBytes += expectedSize
            await progress(downloadProgress(completedBytes: completedBytes, totalBytes: totalBytes, detail: file.path))
        }
    }

    private func compile(progress: @Sendable (ModelInstallProgress) async -> Void) async throws {
        let temporaryRoot = fileManager.temporaryDirectory
            .appendingPathComponent("MumlaCoreMLStage-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: temporaryRoot)
        }

        let components = ["Preprocessor", "Encoder", "Decoder", "JointDecisionv3"]
        for (index, component) in components.enumerated() {
            await progress(
                ModelInstallProgress(
                    phase: .compiling,
                    fraction: 0.72 + (Double(index) / Double(components.count)) * 0.26,
                    detail: "Compiling \(component)"
                )
            )
            let package = downloadDirectory.appendingPathComponent("\(component).mlpackage", isDirectory: true)
            let compiled = try await MLModel.compileModel(at: package)
            let destination = temporaryRoot.appendingPathComponent("\(component).mlmodelc", isDirectory: true)
            try? fileManager.removeItem(at: destination)
            try fileManager.copyItem(at: compiled, to: destination)
        }

        try fileManager.copyItem(
            at: downloadDirectory.appendingPathComponent("parakeet_vocab.json"),
            to: temporaryRoot.appendingPathComponent("parakeet_vocab.json")
        )

        let license = downloadDirectory.appendingPathComponent("LICENSE-and-attribution.txt")
        if fileManager.fileExists(atPath: license.path) {
            try fileManager.copyItem(
                at: license,
                to: temporaryRoot.appendingPathComponent("LICENSE-and-attribution.txt")
            )
        }

        let parent = compiledDirectory.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let replacement = parent.appendingPathComponent("\(compiledDirectory.lastPathComponent).replacement-\(UUID().uuidString)", isDirectory: true)
        try fileManager.moveItem(at: temporaryRoot, to: replacement)
        try? fileManager.removeItem(at: compiledDirectory)
        try fileManager.moveItem(at: replacement, to: compiledDirectory)
    }

    private func isFileAlreadyValid(_ file: ModelArtifactFile, at url: URL) throws -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }

        if let expectedSize = file.byteCount {
            let actualSize = (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
            guard actualSize == expectedSize else {
                return false
            }
        }

        if let sha256 = file.sha256 {
            let actual = try ModelArtifactVerifier.sha256Hex(of: url)
            guard actual.caseInsensitiveCompare(sha256) == .orderedSame else {
                return false
            }
        }

        return true
    }

    private func downloadProgress(completedBytes: Int64, totalBytes: Int64, detail: String) -> ModelInstallProgress {
        let fraction = totalBytes == 0 ? 0 : min(0.72, max(0, Double(completedBytes) / Double(totalBytes) * 0.72))
        return ModelInstallProgress(phase: .downloading, fraction: fraction, detail: detail)
    }

    private func resolveURL(repoID: String, revision: String, path: String) -> URL {
        let repo = repoID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repoID
        let encodedRevision = revision.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? revision
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return URL(string: "https://huggingface.co/\(repo)/resolve/\(encodedRevision)/\(encodedPath)")!
    }
}

public enum ModelInstallerError: Error, LocalizedError {
    case missingRevision
    case verificationFailed(String)
    case sizeMismatch(path: String, expected: Int64, actual: Int64)
    case checksumMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .missingRevision:
            return "Model manifest is missing a pinned revision."
        case let .verificationFailed(message):
            return "Model verification failed: \(message)"
        case let .sizeMismatch(path, expected, actual):
            return "\(path) downloaded \(actual) bytes, expected \(expected)."
        case let .checksumMismatch(path):
            return "\(path) failed checksum verification."
        }
    }
}
