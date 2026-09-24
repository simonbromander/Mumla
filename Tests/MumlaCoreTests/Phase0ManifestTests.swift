import XCTest
@testable import MumlaCore

final class Phase0ManifestTests: XCTestCase {
    func testFixtureManifestValidates() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "phase0-manifest", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(Phase0Manifest.self, from: data)

        XCTAssertEqual(manifest.clips.count, 1)
        XCTAssertEqual(manifest.validationIssues(baseDirectory: url.deletingLastPathComponent()), [])
    }

    func testScorerAggregatesPredictions() {
        let manifest = Phase0Manifest(
            createdAt: "2026-09-24T00:00:00Z",
            clips: [
                Phase0Clip(
                    id: "clip-1",
                    audioPath: "clip-1.wav",
                    reference: "hello this is a test",
                    expectedLanguage: .english
                )
            ]
        )

        let score = Phase0Scorer.score(
            manifest: manifest,
            predictions: [
                Phase0Prediction(
                    clipId: "clip-1",
                    model: "fixture",
                    transcript: "hello this is test",
                    latencyMilliseconds: 100
                )
            ]
        )

        XCTAssertEqual(score.model, "fixture")
        XCTAssertEqual(score.clipCount, 1)
        XCTAssertEqual(score.totalClipCount, 1)
        XCTAssertEqual(score.wordErrorRate.deletions, 1)
        XCTAssertEqual(score.p95LatencyMilliseconds, 100)
        XCTAssertEqual(score.latency.p50Milliseconds, 100)
        XCTAssertEqual(score.languageScores.count, 1)
        XCTAssertEqual(score.languageScores.first?.language, .english)
    }

    func testScorerReportsLanguageAccuracyAndDuplicates() {
        let manifest = Phase0Manifest(
            createdAt: "2026-09-24T00:00:00Z",
            clips: [
                Phase0Clip(
                    id: "clip-1",
                    audioPath: "clip-1.wav",
                    reference: "hej världen",
                    expectedLanguage: .swedish
                ),
                Phase0Clip(
                    id: "clip-2",
                    audioPath: "clip-2.wav",
                    reference: "hello world",
                    expectedLanguage: .english
                )
            ]
        )

        let score = Phase0Scorer.score(
            manifest: manifest,
            predictions: [
                Phase0Prediction(
                    clipId: "clip-1",
                    model: "fixture",
                    transcript: "hej världen",
                    detectedLanguage: .swedish
                ),
                Phase0Prediction(
                    clipId: "clip-1",
                    model: "fixture",
                    transcript: "duplicate",
                    detectedLanguage: .english
                )
            ]
        )

        XCTAssertEqual(score.clipCount, 1)
        XCTAssertEqual(score.missingPredictionIDs, ["clip-2"])
        XCTAssertEqual(score.duplicatePredictionIDs, ["clip-1"])
        XCTAssertEqual(score.languageAccuracy.evaluatedCount, 1)
        XCTAssertEqual(score.languageAccuracy.correctCount, 1)
        XCTAssertEqual(score.languageAccuracy.accuracy, 1)
    }
}
