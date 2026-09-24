import XCTest
@testable import MumlaCore

final class LanguageRouterTests: XCTestCase {
    func testManualSwedishOverrideUsesPianissimo() {
        let decision = LanguageRouter.route(
            LanguageRoutingInput(
                durationSeconds: 5,
                mode: .swedish,
                lastLanguage: .english,
                parakeetDetection: LanguageDetectionResult(language: .english, confidence: 0.99),
                appleDetection: LanguageDetectionResult(language: .english, confidence: 0.99)
            )
        )

        XCTAssertEqual(decision.language, .swedish)
        XCTAssertEqual(decision.model.id, "KlangAI/pianissimo-sv")
        XCTAssertEqual(decision.reason, .manualOverride)
    }

    func testShortClipUsesLastLanguage() {
        let decision = LanguageRouter.route(
            LanguageRoutingInput(
                durationSeconds: 1.4,
                mode: .automatic,
                lastLanguage: .english,
                parakeetDetection: LanguageDetectionResult(language: .swedish, confidence: 0.92),
                appleDetection: LanguageDetectionResult(language: .swedish, confidence: 0.90)
            )
        )

        XCTAssertEqual(decision.language, .english)
        XCTAssertEqual(decision.reason, .shortClipUsesLastLanguage)
    }

    func testAgreementWinsForLongClip() {
        let decision = LanguageRouter.route(
            LanguageRoutingInput(
                durationSeconds: 2.5,
                mode: .automatic,
                lastLanguage: .english,
                parakeetDetection: LanguageDetectionResult(language: .swedish, confidence: 0.72),
                appleDetection: LanguageDetectionResult(language: .swedish, confidence: 0.69)
            )
        )

        XCTAssertEqual(decision.language, .swedish)
        XCTAssertEqual(decision.reason, .detectorsAgree)
    }
}

