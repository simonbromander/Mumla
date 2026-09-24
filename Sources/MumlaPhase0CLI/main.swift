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
            guard arguments.count == 3 || arguments.count == 4 else {
                printUsage()
                throw ExitCode.failure
            }
            try score(
                manifestPath: arguments[1],
                predictionsPath: arguments[2],
                emitsJSON: arguments.last == "--json"
            )
        case "verify-model":
            guard arguments.count == 3 else {
                printUsage()
                throw ExitCode.failure
            }
            try verifyModel(artifactPath: arguments[1], modelDirectoryPath: arguments[2])
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

    private static func verifyModel(artifactPath: String, modelDirectoryPath: String) throws {
        let artifactURL = URL(fileURLWithPath: artifactPath)
        let artifact: ModelArtifact = try loadJSON(from: artifactURL)
        let issues = ModelArtifactVerifier.verify(
            artifact: artifact,
            baseDirectory: URL(fileURLWithPath: modelDirectoryPath, isDirectory: true)
        )

        if issues.isEmpty {
            print("OK: \(artifact.id) artifact files verified")
        } else {
            print("Invalid model artifact:")
            for issue in issues {
                print("- \(issue.description)")
            }
            throw ExitCode.failure
        }
    }

    private static func score(manifestPath: String, predictionsPath: String, emitsJSON: Bool) throws {
        let manifestURL = URL(fileURLWithPath: manifestPath)
        let predictionsURL = URL(fileURLWithPath: predictionsPath)
        let manifest: Phase0Manifest = try loadJSON(from: manifestURL)
        let predictions: [Phase0Prediction] = try loadJSON(from: predictionsURL)
        let score = Phase0Scorer.score(manifest: manifest, predictions: predictions)

        if emitsJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(score)
            print(String(decoding: data, as: UTF8.self))
            return
        }

        print("Model: \(score.model)")
        print("Clips scored: \(score.clipCount)/\(score.totalClipCount)")
        print("WER: \(formatPercent(score.wordErrorRate.errorRate))")
        print("Errors: S=\(score.wordErrorRate.substitutions) I=\(score.wordErrorRate.insertions) D=\(score.wordErrorRate.deletions)")

        for languageScore in score.languageScores {
            print("\(languageScore.language.displayName) WER: \(formatPercent(languageScore.wordErrorRate.errorRate)) (\(languageScore.clipCount) clips)")
        }

        if let latency = score.latency.p50Milliseconds {
            print("p50 latency: \(Int(latency.rounded())) ms")
        }

        if let latency = score.p95LatencyMilliseconds {
            print("p95 latency: \(Int(latency.rounded())) ms")
        }

        if let accuracy = score.languageAccuracy.accuracy {
            print("Language accuracy: \(formatPercent(accuracy)) (\(score.languageAccuracy.correctCount)/\(score.languageAccuracy.evaluatedCount))")
        } else {
            print("Language accuracy: n/a")
        }

        if !score.missingPredictionIDs.isEmpty {
            print("Missing predictions: \(score.missingPredictionIDs.joined(separator: ", "))")
        }

        if !score.duplicatePredictionIDs.isEmpty {
            print("Duplicate predictions: \(score.duplicatePredictionIDs.joined(separator: ", "))")
        }

        if !score.missingPredictionIDs.isEmpty || !score.duplicatePredictionIDs.isEmpty {
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
              mumla-phase0 score <manifest.json> <predictions.json> [--json]
              mumla-phase0 verify-model <artifact.json> <model-directory>
            """
        )
    }
}

enum ExitCode: Error {
    case failure
}
