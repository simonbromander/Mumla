import Foundation
import MumlaCore

@main
struct MumlaPhase0CLI {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let command = arguments.first else {
            printUsage()
            throw ExitCode.failure
        }

        switch command {
        case "validate":
            guard arguments.count == 2 else {
                printUsage()
                throw ExitCode.failure
            }
            try validateManifest(path: arguments[1])
        case "score":
            guard arguments.count == 3 else {
                printUsage()
                throw ExitCode.failure
            }
            try score(manifestPath: arguments[1], predictionsPath: arguments[2])
        default:
            printUsage()
            throw ExitCode.failure
        }
    }

    private static func validateManifest(path: String) throws {
        let manifestURL = URL(fileURLWithPath: path)
        let manifest: Phase0Manifest = try loadJSON(from: manifestURL)
        let issues = manifest.validationIssues(baseDirectory: manifestURL.deletingLastPathComponent())

        if issues.isEmpty {
            print("OK: \(manifest.clips.count) clips")
        } else {
            print("Invalid manifest:")
            for issue in issues {
                print("- \(issue.description)")
            }
            throw ExitCode.failure
        }
    }

    private static func score(manifestPath: String, predictionsPath: String) throws {
        let manifestURL = URL(fileURLWithPath: manifestPath)
        let predictionsURL = URL(fileURLWithPath: predictionsPath)
        let manifest: Phase0Manifest = try loadJSON(from: manifestURL)
        let predictions: [Phase0Prediction] = try loadJSON(from: predictionsURL)
        let score = Phase0Scorer.score(manifest: manifest, predictions: predictions)

        print("Model: \(score.model)")
        print("Clips scored: \(score.clipCount)/\(manifest.clips.count)")
        print("WER: \(formatPercent(score.wordErrorRate.errorRate))")
        print("Errors: S=\(score.wordErrorRate.substitutions) I=\(score.wordErrorRate.insertions) D=\(score.wordErrorRate.deletions)")

        if let latency = score.p95LatencyMilliseconds {
            print("p95 latency: \(Int(latency.rounded())) ms")
        }

        if !score.missingPredictionIDs.isEmpty {
            print("Missing predictions: \(score.missingPredictionIDs.joined(separator: ", "))")
            throw ExitCode.failure
        }
    }

    private static func loadJSON<T: Decodable>(from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private static func formatPercent(_ value: Double) -> String {
        String(format: "%.2f%%", value * 100)
    }

    private static func printUsage() {
        print(
            """
            Usage:
              mumla-phase0 validate <manifest.json>
              mumla-phase0 score <manifest.json> <predictions.json>
            """
        )
    }
}

enum ExitCode: Error {
    case failure
}

