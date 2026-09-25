import XCTest
@testable import MumlaCore

final class CorrectionLearnerTests: XCTestCase {
    func testLearnsSingleCloseWordCorrectionAfterSecondOccurrence() {
        let learner = CorrectionLearner()

        let first = learner.observe(
            originalText: "Vi använder Kubernetis idag",
            editedText: "Vi använder Kubernetes idag"
        )
        let second = learner.observe(
            originalText: "Kubernetis är snabbt",
            editedText: "Kubernetes är snabbt"
        )

        XCTAssertEqual(
            first,
            .pending(CorrectionCandidate(original: "Kubernetis", replacement: "Kubernetes"), count: 1)
        )

        guard case let .learned(entry) = second else {
            return XCTFail("Expected correction to be learned on second occurrence.")
        }
        XCTAssertEqual(entry.original, "Kubernetis")
        XCTAssertEqual(entry.replacement, "Kubernetes")
    }

    func testIgnoresDeletions() {
        XCTAssertNil(
            CorrectionLearner.candidate(
                originalText: "Ta bort fel ord",
                editedText: "Ta bort ord"
            )
        )
    }

    func testIgnoresMultiWordRewrite() {
        XCTAssertNil(
            CorrectionLearner.candidate(
                originalText: "Det här låter konstigt",
                editedText: "Det där känns rätt"
            )
        )
    }

    func testIgnoresWordsContainingDigits() {
        XCTAssertNil(
            CorrectionLearner.candidate(
                originalText: "Använd API2",
                editedText: "Använd API3"
            )
        )
    }

    func testIgnoresDistantReplacement() {
        XCTAssertNil(
            CorrectionLearner.candidate(
                originalText: "Vi säger katt",
                editedText: "Vi säger infrastrukturskuld"
            )
        )
    }

    func testStripsPunctuationAroundCandidate() {
        XCTAssertEqual(
            CorrectionLearner.candidate(
                originalText: "Hej Kubernetis.",
                editedText: "Hej Kubernetes."
            ),
            CorrectionCandidate(original: "Kubernetis", replacement: "Kubernetes")
        )
    }
}
