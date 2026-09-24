import CryptoKit
import Foundation

public struct ModelArtifact: Codable, Equatable, Sendable {
    public var id: String
    public var sourceURL: URL
    public var revision: String?
    public var files: [ModelArtifactFile]

    public init(id: String, sourceURL: URL, revision: String? = nil, files: [ModelArtifactFile]) {
        self.id = id
        self.sourceURL = sourceURL
        self.revision = revision
        self.files = files
    }
}

public struct ModelArtifactFile: Codable, Equatable, Sendable {
    public var path: String
    public var byteCount: Int64?
    public var sha256: String?

    public init(path: String, byteCount: Int64? = nil, sha256: String? = nil) {
        self.path = path
        self.byteCount = byteCount
        self.sha256 = sha256
    }
}

public enum ModelArtifactVerificationIssue: Error, Codable, Equatable, CustomStringConvertible, Sendable {
    case missingFile(String)
    case sizeMismatch(path: String, expected: Int64, actual: Int64)
    case checksumMismatch(path: String, expected: String, actual: String)
    case unreadableFile(String)

    public var description: String {
        switch self {
        case let .missingFile(path):
            return "Missing artifact file: \(path)."
        case let .sizeMismatch(path, expected, actual):
            return "Size mismatch for \(path): expected \(expected), got \(actual)."
        case let .checksumMismatch(path, expected, actual):
            return "Checksum mismatch for \(path): expected \(expected), got \(actual)."
        case let .unreadableFile(path):
            return "Unreadable artifact file: \(path)."
        }
    }
}

public enum ModelArtifactVerifier {
    public static func verify(
        artifact: ModelArtifact,
        baseDirectory: URL,
        fileManager: FileManager = .default
    ) -> [ModelArtifactVerificationIssue] {
        artifact.files.flatMap { file in
            verify(file: file, baseDirectory: baseDirectory, fileManager: fileManager)
        }
    }

    public static func sha256Hex(of url: URL) throws -> String {
        guard let stream = InputStream(url: url) else {
            throw ModelArtifactVerificationIssue.unreadableFile(url.path)
        }

        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let bufferSize = 1024 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count < 0 {
                throw ModelArtifactVerificationIssue.unreadableFile(url.path)
            }
            if count > 0 {
                hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: count))
            }
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func verify(
        file: ModelArtifactFile,
        baseDirectory: URL,
        fileManager: FileManager
    ) -> [ModelArtifactVerificationIssue] {
        let fileURL = baseDirectory.appendingPathComponent(file.path)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return [.missingFile(file.path)]
        }

        var issues: [ModelArtifactVerificationIssue] = []

        if let expectedSize = file.byteCount {
            let actualSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
            if let actualSize {
                if actualSize != expectedSize {
                    issues.append(.sizeMismatch(path: file.path, expected: expectedSize, actual: actualSize))
                }
            } else {
                issues.append(.unreadableFile(file.path))
            }
        }

        if let expectedChecksum = file.sha256 {
            do {
                let actualChecksum = try sha256Hex(of: fileURL)
                if actualChecksum.caseInsensitiveCompare(expectedChecksum) != .orderedSame {
                    issues.append(.checksumMismatch(path: file.path, expected: expectedChecksum, actual: actualChecksum))
                }
            } catch {
                issues.append(.unreadableFile(file.path))
            }
        }

        return issues
    }
}

