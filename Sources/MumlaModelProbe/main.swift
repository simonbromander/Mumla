import Darwin
import FluidAudio
import Foundation
import MumlaCore

@main
struct MumlaModelProbe {
    static func main() async {
        do {
            try await run()
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsage()
            throw ProbeError.invalidArguments
        }
        arguments.removeFirst()

        switch command {
        case "load":
            guard arguments.count == 1 else {
                printUsage()
                throw ProbeError.invalidArguments
            }
            let modelDirectory = URL(fileURLWithPath: arguments[0], isDirectory: true)
            let measurement = try await loadManager(from: modelDirectory)
            print("OK: loaded models in \(formatMilliseconds(measurement.loadMilliseconds)) ms")

        case "transcribe":
            try await transcribe(arguments: arguments)

        case "transcribe-manifest":
            try await transcribeManifest(arguments: arguments)

        default:
            printUsage()
            throw ProbeError.invalidArguments
        }
    }

    private static func transcribe(arguments: [String]) async throws {
        guard arguments.count >= 2 else {
            printUsage()
            throw ProbeError.invalidArguments
        }

        let modelDirectory = URL(fileURLWithPath: arguments[0], isDirectory: true)
        let audioURL = URL(fileURLWithPath: arguments[1])
        var options = ProbeOptions(clipID: audioURL.deletingPathExtension().lastPathComponent)

        var index = 2
        while index < arguments.count {
            switch arguments[index] {
            case "--clip-id":
                guard index + 1 < arguments.count else { throw ProbeError.invalidArguments }
                options.clipID = arguments[index + 1]
                index += 2
            case "--language":
                guard index + 1 < arguments.count else { throw ProbeError.invalidArguments }
                options.language = try parseLanguage(arguments[index + 1])
                index += 2
            case "--json":
                options.emitsJSON = true
                index += 1
            case "--json-output":
                guard index + 1 < arguments.count else { throw ProbeError.invalidArguments }
                options.emitsJSON = true
                options.jsonOutputURL = URL(fileURLWithPath: arguments[index + 1])
                index += 2
            default:
                throw ProbeError.invalidArguments
            }
        }

        let measurement = try await loadManager(from: modelDirectory)
        var decoderState = TdtDecoderState.make(decoderLayers: await measurement.manager.decoderLayerCount)
        let transcriptionStart = Date()
        let result = try await measurement.manager.transcribe(
            audioURL,
            decoderState: &decoderState,
            language: options.language.fluidAudioLanguage
        )
        let transcriptionMilliseconds = Date().timeIntervalSince(transcriptionStart) * 1000

        if options.emitsJSON {
            let prediction = Phase0Prediction(
                clipId: options.clipID,
                model: "markstrom-pianissimo-sv-coreml-fluidAudio-local",
                transcript: result.text,
                latencyMilliseconds: transcriptionMilliseconds,
                detectedLanguage: options.language
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode([prediction])
            if let jsonOutputURL = options.jsonOutputURL {
                let parent = jsonOutputURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                try data.write(to: jsonOutputURL, options: .atomic)
                print("Prediction JSON written to \(jsonOutputURL.path)")
            } else {
                print(String(decoding: data, as: UTF8.self))
            }
        } else {
            print("Load: \(formatMilliseconds(measurement.loadMilliseconds)) ms")
            print("Transcribe: \(formatMilliseconds(transcriptionMilliseconds)) ms")
            print("Duration: \(String(format: "%.2f", result.duration)) s")
            print("RTFx: \(String(format: "%.2f", result.rtfx))")
            print("Transcript: \(result.text)")
        }
    }

    private static func transcribeManifest(arguments: [String]) async throws {
        guard arguments.count >= 2 else {
            printUsage()
            throw ProbeError.invalidArguments
        }

        let modelDirectory = URL(fileURLWithPath: arguments[0], isDirectory: true)
        let manifestURL = URL(fileURLWithPath: arguments[1])
        var options = ManifestProbeOptions()

        var index = 2
        while index < arguments.count {
            switch arguments[index] {
            case "--json-output":
                guard index + 1 < arguments.count else { throw ProbeError.invalidArguments }
                options.jsonOutputURL = URL(fileURLWithPath: arguments[index + 1])
                index += 2
            case "--language":
                guard index + 1 < arguments.count else { throw ProbeError.invalidArguments }
                options.languageSelection = try ManifestLanguageSelection(rawValue: arguments[index + 1])
                index += 2
            case "--limit":
                guard index + 1 < arguments.count, let limit = Int(arguments[index + 1]), limit > 0 else {
                    throw ProbeError.invalidArguments
                }
                options.limit = limit
                index += 2
            default:
                throw ProbeError.invalidArguments
            }
        }

        guard let outputURL = options.jsonOutputURL else {
            throw ProbeError.missingJSONOutput
        }

        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(Phase0Manifest.self, from: data)
        let manifestBaseDirectory = manifestURL.deletingLastPathComponent()
        let issues = manifest.validationIssues(baseDirectory: manifestBaseDirectory)
        guard issues.isEmpty else {
            throw ProbeError.invalidManifest(issues)
        }

        let measurement = try await loadManager(from: modelDirectory)
        print("Loaded models in \(formatMilliseconds(measurement.loadMilliseconds)) ms")

        let clips = Array(manifest.clips.prefix(options.limit ?? manifest.clips.count))
        var predictions: [Phase0Prediction] = []
        predictions.reserveCapacity(clips.count)

        for (offset, clip) in clips.enumerated() {
            let audioURL = resolveAudioURL(path: clip.audioPath, baseDirectory: manifestBaseDirectory)
            let language = options.languageSelection.language(for: clip)
            var decoderState = TdtDecoderState.make(decoderLayers: await measurement.manager.decoderLayerCount)
            let start = Date()
            let result = try await measurement.manager.transcribe(
                audioURL,
                decoderState: &decoderState,
                language: language.fluidAudioLanguage
            )
            let latencyMilliseconds = Date().timeIntervalSince(start) * 1000
            predictions.append(
                Phase0Prediction(
                    clipId: clip.id,
                    model: "markstrom-pianissimo-sv-coreml-fluidAudio-local",
                    transcript: result.text,
                    latencyMilliseconds: latencyMilliseconds,
                    detectedLanguage: language
                )
            )
            print(
                "[\(offset + 1)/\(clips.count)] \(clip.id): \(formatMilliseconds(latencyMilliseconds)) ms, \(language.rawValue)"
            )
        }

        try writePredictions(predictions, to: outputURL)
        print("Prediction JSON written to \(outputURL.path)")
    }

    private static func loadManager(from modelDirectory: URL) async throws -> ModelLoadMeasurement {
        let start = Date()
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
        let loadMilliseconds = Date().timeIntervalSince(start) * 1000
        return ModelLoadMeasurement(manager: manager, loadMilliseconds: loadMilliseconds)
    }

    private static func resolveAudioURL(path: String, baseDirectory: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return baseDirectory.appendingPathComponent(path)
    }

    private static func writePredictions(_ predictions: [Phase0Prediction], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(predictions)
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private static func parseLanguage(_ rawValue: String) throws -> MumlaLanguage {
        guard let language = MumlaLanguage(rawValue: rawValue) else {
            throw ProbeError.unsupportedLanguage(rawValue)
        }
        return language
    }

    private static func formatMilliseconds(_ milliseconds: Double) -> String {
        String(format: "%.0f", milliseconds)
    }

    private static func printUsage() {
        print(
            """
            Usage:
              mumla-model-probe load <compiled-model-directory>
              mumla-model-probe transcribe <compiled-model-directory> <audio.wav> [--language sv|en] [--clip-id id] [--json] [--json-output predictions.json]
              mumla-model-probe transcribe-manifest <compiled-model-directory> <manifest.json> --json-output predictions.json [--language expected|sv|en] [--limit n]
            """
        )
    }
}

private struct ModelLoadMeasurement {
    var manager: AsrManager
    var loadMilliseconds: Double
}

private struct ProbeOptions {
    var clipID: String
    var language: MumlaLanguage = .swedish
    var emitsJSON = false
    var jsonOutputURL: URL?
}

private struct ManifestProbeOptions {
    var jsonOutputURL: URL?
    var languageSelection: ManifestLanguageSelection = .expected
    var limit: Int?
}

private enum ManifestLanguageSelection {
    case expected
    case fixed(MumlaLanguage)

    init(rawValue: String) throws {
        switch rawValue {
        case "expected":
            self = .expected
        case "en":
            self = .fixed(.english)
        case "sv":
            self = .fixed(.swedish)
        default:
            throw ProbeError.unsupportedLanguage(rawValue)
        }
    }

    func language(for clip: Phase0Clip) -> MumlaLanguage {
        switch self {
        case .expected:
            return clip.expectedLanguage
        case let .fixed(language):
            return language
        }
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

private enum ProbeError: Error, LocalizedError {
    case invalidArguments
    case missingJSONOutput
    case invalidManifest([Phase0ValidationIssue])
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Invalid arguments."
        case .missingJSONOutput:
            return "transcribe-manifest requires --json-output."
        case let .invalidManifest(issues):
            return "Invalid manifest: \(issues.map { $0.description }.joined(separator: "; "))"
        case let .unsupportedLanguage(language):
            return "Unsupported language: \(language). Use expected, sv, or en."
        }
    }
}
