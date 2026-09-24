import XCTest
@testable import MumlaCore

final class WordErrorRateTests: XCTestCase {
    func testPerfectMatchHasZeroErrors() {
        let result = WordErrorRate.score(
            reference: "Hej, det här är Mumla.",
            hypothesis: "hej det här är mumla"
        )

        XCTAssertEqual(result.totalErrors, 0)
        XCTAssertEqual(result.errorRate, 0)
    }

    func testCountsSubstitutionInsertionAndDeletion() {
        let result = WordErrorRate.score(
            reference: "a b c d",
            hypothesis: "a x c y"
        )

        XCTAssertEqual(result.substitutions, 2)
        XCTAssertEqual(result.insertions, 0)
        XCTAssertEqual(result.deletions, 0)
        XCTAssertEqual(result.referenceWordCount, 4)
        XCTAssertEqual(result.errorRate, 0.5)
    }

    func testDiacriticsAreFoldedForMeasurement() {
        let result = WordErrorRate.score(
            reference: "Kubernetes körs på ön",
            hypothesis: "kubernetes kors pa on"
        )

        XCTAssertEqual(result.totalErrors, 0)
    }
}

