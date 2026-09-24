import Foundation

public struct LatencySummary: Codable, Equatable, Sendable {
    public var count: Int
    public var p50Milliseconds: Double?
    public var p95Milliseconds: Double?
    public var minMilliseconds: Double?
    public var maxMilliseconds: Double?

    public init(
        count: Int,
        p50Milliseconds: Double?,
        p95Milliseconds: Double?,
        minMilliseconds: Double?,
        maxMilliseconds: Double?
    ) {
        self.count = count
        self.p50Milliseconds = p50Milliseconds
        self.p95Milliseconds = p95Milliseconds
        self.minMilliseconds = minMilliseconds
        self.maxMilliseconds = maxMilliseconds
    }

    public static func make(values: [Double]) -> LatencySummary {
        let sorted = values.sorted()
        return LatencySummary(
            count: sorted.count,
            p50Milliseconds: percentile(sorted, percentile: 0.50),
            p95Milliseconds: percentile(sorted, percentile: 0.95),
            minMilliseconds: sorted.first,
            maxMilliseconds: sorted.last
        )
    }

    private static func percentile(_ sortedValues: [Double], percentile: Double) -> Double? {
        guard !sortedValues.isEmpty else {
            return nil
        }

        let index = Int(ceil(percentile * Double(sortedValues.count))) - 1
        return sortedValues[max(0, min(index, sortedValues.count - 1))]
    }
}

public struct LanguageMismatch: Codable, Equatable, Sendable {
    public var clipID: String
    public var expected: MumlaLanguage
    public var detected: MumlaLanguage?

    public init(clipID: String, expected: MumlaLanguage, detected: MumlaLanguage?) {
        self.clipID = clipID
        self.expected = expected
        self.detected = detected
    }
}

public struct LanguageAccuracySummary: Codable, Equatable, Sendable {
    public var evaluatedCount: Int
    public var correctCount: Int
    public var missingCount: Int
    public var mismatches: [LanguageMismatch]

    public var accuracy: Double? {
        guard evaluatedCount > 0 else {
            return nil
        }
        return Double(correctCount) / Double(evaluatedCount)
    }

    public init(
        evaluatedCount: Int,
        correctCount: Int,
        missingCount: Int,
        mismatches: [LanguageMismatch]
    ) {
        self.evaluatedCount = evaluatedCount
        self.correctCount = correctCount
        self.missingCount = missingCount
        self.mismatches = mismatches
    }
}

public struct Phase0LanguageScore: Codable, Equatable, Sendable {
    public var language: MumlaLanguage
    public var clipCount: Int
    public var wordErrorRate: WordErrorRateResult

    public init(language: MumlaLanguage, clipCount: Int, wordErrorRate: WordErrorRateResult) {
        self.language = language
        self.clipCount = clipCount
        self.wordErrorRate = wordErrorRate
    }
}

public struct Phase0Score: Codable, Equatable, Sendable {
    public var model: String
    public var clipCount: Int
    public var totalClipCount: Int
    public var wordErrorRate: WordErrorRateResult
    public var languageScores: [Phase0LanguageScore]
    public var latency: LatencySummary
    public var languageAccuracy: LanguageAccuracySummary
    public var missingPredictionIDs: [String]
    public var duplicatePredictionIDs: [String]

    public var p95LatencyMilliseconds: Double? {
        latency.p95Milliseconds
    }

    public init(
        model: String,
        clipCount: Int,
        totalClipCount: Int,
        wordErrorRate: WordErrorRateResult,
        languageScores: [Phase0LanguageScore],
        latency: LatencySummary,
        languageAccuracy: LanguageAccuracySummary,
        missingPredictionIDs: [String],
        duplicatePredictionIDs: [String]
    ) {
        self.model = model
        self.clipCount = clipCount
        self.totalClipCount = totalClipCount
        self.wordErrorRate = wordErrorRate
        self.languageScores = languageScores
        self.latency = latency
        self.languageAccuracy = languageAccuracy
        self.missingPredictionIDs = missingPredictionIDs
        self.duplicatePredictionIDs = duplicatePredictionIDs
    }
}

public struct Phase0GateThresholds: Codable, Equatable, Sendable {
    public var maximumAbsoluteWordErrorRate: Double
    public var maximumRelativeWordErrorRate: Double
    public var maximumP95LatencyMilliseconds: Double
    public var minimumLanguageAccuracy: Double

    public init(
        maximumAbsoluteWordErrorRate: Double = 0.07,
        maximumRelativeWordErrorRate: Double = 0.50,
        maximumP95LatencyMilliseconds: Double = 700,
        minimumLanguageAccuracy: Double = 0.97
    ) {
        self.maximumAbsoluteWordErrorRate = maximumAbsoluteWordErrorRate
        self.maximumRelativeWordErrorRate = maximumRelativeWordErrorRate
        self.maximumP95LatencyMilliseconds = maximumP95LatencyMilliseconds
        self.minimumLanguageAccuracy = minimumLanguageAccuracy
    }
}

public struct Phase0GateResult: Codable, Equatable, Sendable {
    public var passed: Bool
    public var failures: [String]

    public init(passed: Bool, failures: [String]) {
        self.passed = passed
        self.failures = failures
    }
}

public enum Phase0GateEvaluator {
    public static func evaluate(
        score: Phase0Score,
        appleBaselineWER: Double?,
        thresholds: Phase0GateThresholds = Phase0GateThresholds()
    ) -> Phase0GateResult {
        var failures: [String] = []

        if score.wordErrorRate.errorRate > thresholds.maximumAbsoluteWordErrorRate {
            failures.append("WER exceeds \(formatPercent(thresholds.maximumAbsoluteWordErrorRate)).")
        }

        if let appleBaselineWER {
            let relativeLimit = appleBaselineWER * thresholds.maximumRelativeWordErrorRate
            if score.wordErrorRate.errorRate > relativeLimit {
                failures.append("WER is not at most \(formatPercent(thresholds.maximumRelativeWordErrorRate)) of Apple baseline.")
            }
        }

        if let p95 = score.latency.p95Milliseconds, p95 > thresholds.maximumP95LatencyMilliseconds {
            failures.append("p95 latency exceeds \(Int(thresholds.maximumP95LatencyMilliseconds)) ms.")
        }

        if let accuracy = score.languageAccuracy.accuracy, accuracy < thresholds.minimumLanguageAccuracy {
            failures.append("Language accuracy is below \(formatPercent(thresholds.minimumLanguageAccuracy)).")
        }

        if !score.missingPredictionIDs.isEmpty {
            failures.append("Missing predictions for \(score.missingPredictionIDs.count) clips.")
        }

        if !score.duplicatePredictionIDs.isEmpty {
            failures.append("Duplicate predictions for \(score.duplicatePredictionIDs.count) clips.")
        }

        return Phase0GateResult(passed: failures.isEmpty, failures: failures)
    }

    private static func formatPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }
}

