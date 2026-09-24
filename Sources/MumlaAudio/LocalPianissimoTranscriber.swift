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
    private let modelDirectory: URL
    private var manager: AsrManager?

    public init(modelDirectory: URL) {
        self.modelDirectory = modelDirectory
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
        if let manager {
            return manager
        }

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
        self.manager = manager
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
