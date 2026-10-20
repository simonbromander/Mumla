#if os(macOS)
import Combine
import Foundation
import MumlaCore

@MainActor
public final class QwenTextModel: ObservableObject {
    @Published public private(set) var isInstalled: Bool
    @Published public private(set) var downloadProgress: Double?
    @Published public private(set) var isRemoving = false
    @Published public private(set) var failed = false
    public var supportsDevice: Bool { QwenTextGenerator.supportsDevice }
    private let store: QwenModelStore
    private let installer: QwenModelInstaller
    private let generator: QwenTextGenerator
    private var downloadTask: Task<Void, Never>?
    private var downloadID = UUID()

    public init(directory: URL = QwenModelArtifact.defaultDirectory) {
        let store = QwenModelStore(directory: directory)
        self.store = store
        self.installer = QwenModelInstaller(store: store)
        self.generator = QwenTextGenerator(store: store)
        self.isInstalled = store.isInstalled
    }

    public var formatter: LocalTranscriptFormatter {
        let store = store, generator = generator
        return LocalTranscriptFormatter(availability: { _ in
            Self.availability(store: store)
        }, generate: { request in
            try await generator.generate(request, action: .format)
        })
    }

    public var summarizer: LocalTranscriptSummarizer {
        let store = store, generator = generator
        return LocalTranscriptSummarizer(availability: { _ in
            Self.availability(store: store)
        }, generate: { request in
            try await generator.generate(request, action: .summary)
        })
    }

    nonisolated private static func availability(store: QwenModelStore) -> FormattingAvailability {
        guard QwenTextGenerator.supportsDevice else { return .deviceNotEligible }
        return store.isInstalled ? .available : .modelNotInstalled
    }

    public func refresh() {
        guard downloadTask == nil, !isRemoving else { return }
        isInstalled = store.isInstalled
    }

    public func download() {
        guard supportsDevice, downloadTask == nil, !isRemoving else { return }
        failed = false
        downloadProgress = 0
        downloadID = UUID()
        let id = downloadID
        let installer = installer
        downloadTask = Task { [weak self] in
            do {
                try await installer.install { [weak self] fraction in
                    Task { @MainActor in
                        guard let self, self.downloadID == id, self.downloadProgress != nil else { return }
                        self.downloadProgress = max(self.downloadProgress ?? 0, fraction)
                    }
                }
                try Task.checkCancellation()
            } catch {
                if !Task.isCancelled { self?.failed = true }
            }
            guard let self else { return }
            self.downloadProgress = nil
            self.downloadTask = nil
            self.isInstalled = self.store.isInstalled
        }
    }

    public func cancelDownload() { downloadTask?.cancel() }

    public func remove() {
        guard downloadTask == nil, !isRemoving else { return }
        failed = false
        isRemoving = true
        Task { [weak self, generator] in
            do { try await generator.removeModel() }
            catch { self?.failed = true }
            self?.isRemoving = false
            self?.refresh()
        }
    }
}
#endif
