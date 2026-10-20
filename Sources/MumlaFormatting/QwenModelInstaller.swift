#if os(macOS)
import Foundation
import MumlaCore

actor QwenModelInstaller {
    typealias Download = @Sendable (URL, @escaping @Sendable (Double) -> Void) async throws -> URL
    private let store: QwenModelStore
    private let download: Download
    private var installing = false

    init(store: QwenModelStore, download: @escaping Download = QwenModelInstaller.downloadFile) {
        self.store = store
        self.download = download
    }

    func install(progress: @escaping @Sendable (Double) -> Void) async throws {
        guard !installing else { throw QwenModelError.busy }
        installing = true
        defer { installing = false }
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        guard let revision = store.artifact.revision else { throw QwenModelError.invalidFiles }
        let total = Double(store.artifact.files.reduce(Int64(0)) { $0 + ($1.byteCount ?? 0) })
        var completed = 0.0
        for file in store.artifact.files {
            try Task.checkCancellation()
            let size = Double(file.byteCount ?? 0)
            let destination = store.directory.appendingPathComponent(file.path)
            let oneFile = ModelArtifact(id: store.artifact.id, sourceURL: store.artifact.sourceURL, files: [file])
            if !ModelArtifactVerifier.verify(artifact: oneFile, baseDirectory: store.directory).isEmpty {
                let url = URL(string: "https://huggingface.co/\(store.artifact.id)/resolve/\(revision)/\(file.path)")!
                let base = completed
                let temporary = try await download(url) { fraction in
                    progress(min(0.99, (base + size * min(1, max(0, fraction))) / max(1, total)))
                }
                defer { try? FileManager.default.removeItem(at: temporary) }
                try Task.checkCancellation()
                guard let expectedSize = file.byteCount, let expectedHash = file.sha256,
                      (try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) == expectedSize,
                      try ModelArtifactVerifier.sha256Hex(of: temporary) == expectedHash else {
                    throw QwenModelError.invalidFiles
                }
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
            completed += size
            progress(min(0.99, completed / max(1, total)))
        }
        try Task.checkCancellation()
        try store.markInstalled()
        progress(1)
    }

    private static func downloadFile(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let delegate = QwenDownloadProgress(progress: progress)
        let (temporary, response) = try await URLSession.shared.download(from: url, delegate: delegate)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            try? FileManager.default.removeItem(at: temporary)
            throw QwenModelError.downloadFailed
        }
        return temporary
    }
}

private final class QwenDownloadProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let progress: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var lastPercent = -1 // Protected by lock; bound UI updates to one per percent.
    init(progress: @escaping @Sendable (Double) -> Void) { self.progress = progress }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(1, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        let changed = lock.withLock {
            let percent = Int(fraction * 100)
            guard percent > lastPercent else { return false }
            lastPercent = percent
            return true
        }
        if changed { progress(fraction) }
    }
}
#endif
