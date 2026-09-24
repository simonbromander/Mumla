import Foundation

public struct Phase0Manifest: Codable, Equatable, Sendable {
    public var createdAt: String
    public var clips: [Phase0Clip]

    public init(createdAt: String, clips: [Phase0Clip]) {
        self.createdAt = createdAt
        self.clips = clips
    }

    public func validationIssues(baseDirectory: URL, fileManager: FileManager = .default) -> [Phase0ValidationIssue] {
        var issues: [Phase0ValidationIssue] = []
        var seenIDs = Set<String>()

        for clip in clips {
            if clip.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.emptyClipID)
            }

            if !seenIDs.insert(clip.id).inserted {
                issues.append(.duplicateClipID(clip.id))
            }

            if clip.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.emptyReference(clip.id))
            }

            if let duration = clip.durationSeconds, duration <= 0 {
                issues.append(.invalidDuration(clip.id))
            }

            let audioURL = baseDirectory.appendingPathComponent(clip.audioPath)
            if !fileManager.fileExists(atPath: audioURL.path) {
                issues.append(.missingAudio(clip.id, clip.audioPath))
            }
        }

        return issues
    }
}

public struct Phase0Clip: Codable, Equatable, Sendable {
    public var id: String
    public var audioPath: String
    public var reference: String
    public var expectedLanguage: MumlaLanguage
    public var durationSeconds: Double?

    public init(
        id: String,
        audioPath: String,
        reference: String,
        expectedLanguage: MumlaLanguage,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.audioPath = audioPath
        self.reference = reference
        self.expectedLanguage = expectedLanguage
        self.durationSeconds = durationSeconds
    }
}

public enum Phase0ValidationIssue: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyClipID
    case duplicateClipID(String)
    case emptyReference(String)
    case invalidDuration(String)
    case missingAudio(String, String)

    public var description: String {
        switch self {
        case .emptyClipID:
            return "A clip has an empty id."
        case let .duplicateClipID(id):
            return "Duplicate clip id: \(id)."
        case let .emptyReference(id):
            return "Clip \(id) has an empty reference transcript."
        case let .invalidDuration(id):
            return "Clip \(id) has an invalid duration."
        case let .missingAudio(id, path):
            return "Clip \(id) is missing audio at \(path)."
        }
    }
}

public struct Phase0Prediction: Codable, Equatable, Sendable {
    public var clipId: String
    public var model: String
    public var transcript: String
    public var latencyMilliseconds: Double?
    public var detectedLanguage: MumlaLanguage?

    public init(
        clipId: String,
        model: String,
        transcript: String,
        latencyMilliseconds: Double? = nil,
        detectedLanguage: MumlaLanguage? = nil
    ) {
        self.clipId = clipId
        self.model = model
        self.transcript = transcript
        self.latencyMilliseconds = latencyMilliseconds
        self.detectedLanguage = detectedLanguage
    }
}

public enum Phase0Scorer {
    public static func score(
        manifest: Phase0Manifest,
        predictions: [Phase0Prediction],
        normalizer: TranscriptNormalizer = TranscriptNormalizer()
    ) -> Phase0Score {
        var predictionsByID: [String: Phase0Prediction] = [:]
        var duplicateIDs: [String] = []
        for prediction in predictions {
            if predictionsByID[prediction.clipId] != nil {
                duplicateIDs.append(prediction.clipId)
            } else {
                predictionsByID[prediction.clipId] = prediction
            }
        }

        var referenceWords: [String] = []
        var hypothesisWords: [String] = []
        var missing: [String] = []
        var latencies: [Double] = []
        let model = predictions.first?.model ?? "unknown"
        var languageBuckets: [MumlaLanguage: (clips: Int, reference: [String], hypothesis: [String])] = [:]
        var languageCorrect = 0
        var languageEvaluated = 0
        var languageMissing = 0
        var languageMismatches: [LanguageMismatch] = []

        for clip in manifest.clips {
            guard let prediction = predictionsByID[clip.id] else {
                missing.append(clip.id)
                continue
            }

            let reference = normalizer.normalize(clip.reference, language: clip.expectedLanguage)
            let hypothesis = normalizer.normalize(prediction.transcript, language: clip.expectedLanguage)
            referenceWords.append(contentsOf: WordErrorRate.tokenize(reference))
            hypothesisWords.append(contentsOf: WordErrorRate.tokenize(hypothesis))

            let clipReferenceWords = WordErrorRate.tokenize(reference)
            let clipHypothesisWords = WordErrorRate.tokenize(hypothesis)
            var bucket = languageBuckets[clip.expectedLanguage] ?? (clips: 0, reference: [], hypothesis: [])
            bucket.clips += 1
            bucket.reference.append(contentsOf: clipReferenceWords)
            bucket.hypothesis.append(contentsOf: clipHypothesisWords)
            languageBuckets[clip.expectedLanguage] = bucket

            if let latency = prediction.latencyMilliseconds {
                latencies.append(latency)
            }

            if let detectedLanguage = prediction.detectedLanguage {
                languageEvaluated += 1
                if detectedLanguage == clip.expectedLanguage {
                    languageCorrect += 1
                } else {
                    languageMismatches.append(
                        LanguageMismatch(
                            clipID: clip.id,
                            expected: clip.expectedLanguage,
                            detected: detectedLanguage
                        )
                    )
                }
            } else {
                languageMissing += 1
            }
        }

        let languageScores = languageBuckets
            .map { language, bucket in
                Phase0LanguageScore(
                    language: language,
                    clipCount: bucket.clips,
                    wordErrorRate: WordErrorRate.score(
                        referenceWords: bucket.reference,
                        hypothesisWords: bucket.hypothesis
                    )
                )
            }
            .sorted { $0.language.rawValue < $1.language.rawValue }

        return Phase0Score(
            model: model,
            clipCount: manifest.clips.count - missing.count,
            totalClipCount: manifest.clips.count,
            wordErrorRate: WordErrorRate.score(referenceWords: referenceWords, hypothesisWords: hypothesisWords),
            languageScores: languageScores,
            latency: LatencySummary.make(values: latencies),
            languageAccuracy: LanguageAccuracySummary(
                evaluatedCount: languageEvaluated,
                correctCount: languageCorrect,
                missingCount: languageMissing,
                mismatches: languageMismatches
            ),
            missingPredictionIDs: missing,
            duplicatePredictionIDs: Array(Set(duplicateIDs)).sorted()
        )
    }
}
