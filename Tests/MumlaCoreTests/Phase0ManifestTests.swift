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
        XCTAssertEqual(score.wordErrorRate.deletions, 1)
        XCTAssertEqual(score.p95LatencyMilliseconds, 100)
    }
}

