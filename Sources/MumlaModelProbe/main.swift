import Darwin
import FluidAudio
import Foundation

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
                options.language = try ProbeLanguage(rawValue: arguments[index + 1])
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
            let prediction = Phase0ProbePrediction(
                clipId: options.clipID,
                model: "markstrom-pianissimo-sv-coreml-fluidAudio-local",
                transcript: result.text,
                latencyMilliseconds: transcriptionMilliseconds,
                detectedLanguage: options.language.rawValue
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

    private static func formatMilliseconds(_ milliseconds: Double) -> String {
        String(format: "%.0f", milliseconds)
    }

    private static func printUsage() {
        print(
            """
            Usage:
              mumla-model-probe load <compiled-model-directory>
              mumla-model-probe transcribe <compiled-model-directory> <audio.wav> [--language sv|en] [--clip-id id] [--json] [--json-output predictions.json]
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
    var language: ProbeLanguage = .swedish
    var emitsJSON = false
    var jsonOutputURL: URL?
}

private enum ProbeLanguage: String {
    case english = "en"
    case swedish = "sv"

    init(rawValue: String) throws {
        switch rawValue {
        case "en":
            self = .english
        case "sv":
            self = .swedish
        default:
            throw ProbeError.unsupportedLanguage(rawValue)
        }
    }

    var fluidAudioLanguage: Language {
        switch self {
        case .english:
            return .english
        case .swedish:
            return .swedish
        }
    }
}

private struct Phase0ProbePrediction: Encodable {
    var clipId: String
    var model: String
    var transcript: String
    var latencyMilliseconds: Double
    var detectedLanguage: String
}

private enum ProbeError: Error, LocalizedError {
    case invalidArguments
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Invalid arguments."
        case let .unsupportedLanguage(language):
            return "Unsupported language: \(language). Use sv or en."
        }
    }
}
