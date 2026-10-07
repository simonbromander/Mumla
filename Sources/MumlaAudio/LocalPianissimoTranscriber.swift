import FluidAudio
import Foundation
import MumlaCore

public struct LocalTranscriptionResult: Equatable, Sendable {
    public var text: String
    public var language: MumlaLanguage
    public var durationSeconds: Double
    public var processingMilliseconds: Double

    public init(
        text: String,
        language: MumlaLanguage,
        durationSeconds: Double,
        processingMilliseconds: Double
    ) {
        self.text = text
        self.language = language
        self.durationSeconds = durationSeconds
        self.processingMilliseconds = processingMilliseconds
    }
}

public actor LocalPianissimoTranscriber {
    private let managerLoader: @Sendable () async throws -> AsrManager
    private var manager: AsrManager?
    private var loading: (id: UUID, task: Task<AsrManager, Error>)?

    public init(modelDirectory: URL) {
        managerLoader = { try await Self.makeManager(from: modelDirectory) }
    }

    init(managerLoader: @escaping @Sendable () async throws -> AsrManager) {
        self.managerLoader = managerLoader
    }

    public func warmUp() async throws {
        _ = try await loadManager()
    }

    public func transcribe(audioURL: URL, language: MumlaLanguage = .swedish) async throws -> LocalTranscriptionResult {
        let manager = try await loadManager()
        var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let started = Date()
        let result = try await manager.transcribe(
            audioURL,
            decoderState: &decoderState,
            language: language.fluidAudioLanguage
        )
        return LocalTranscriptionResult(
            text: result.text,
            language: language,
            durationSeconds: result.duration,
            processingMilliseconds: Date().timeIntervalSince(started) * 1000
        )
    }

    private func loadManager() async throws -> AsrManager {
        try Task.checkCancellation()
        if let manager {
            return manager
        }

        // Foreground preparation and an explicit start share one Core ML load.
        let pending: (id: UUID, task: Task<AsrManager, Error>)
        if let loading {
            pending = loading
        } else {
            let loader = managerLoader
            pending = (UUID(), Task { try await loader() })
            loading = pending
        }
        do {
            let manager = try await pending.task.value
            if loading?.id == pending.id {
                self.manager = manager
                loading = nil
            }
            try Task.checkCancellation()
            return manager
        } catch {
            if loading?.id == pending.id { loading = nil }
            throw error
        }
    }

    private static func makeManager(from modelDirectory: URL) async throws -> AsrManager {
        let version = AsrModelVersion.v3
        let models = try AsrModels.loadLocal(
            from: modelDirectory,
            version: version,
            encoderPrecision: .int8
        )
        let config = ASRConfig(
            tdtConfig: TdtConfig(blankId: version.blankId),
            encoderHiddenSize: version.encoderHiddenSize
        )
        let manager = AsrManager(config: config)
        try await manager.loadModels(models)
        return manager
    }
}

private extension MumlaLanguage {
    var fluidAudioLanguage: Language {
        switch self {
        case .english:
            return .english
        case .swedish:
            return .swedish
        }
    }
}
