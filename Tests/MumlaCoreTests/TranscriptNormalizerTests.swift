import XCTest
@testable import MumlaCore

final class TranscriptNormalizerTests: XCTestCase {
    func testRemovesSwedishFillers() {
        let normalizer = TranscriptNormalizer()

        XCTAssertEqual(
            normalizer.normalize("eh hej öh världen ehm", language: .swedish),
            "hej världen"
        )
    }

    func testAppliesDictionaryReplacements() {
        let normalizer = TranscriptNormalizer(dictionary: [
            DictionaryReplacement(source: "Kubernetis", replacement: "Kubernetes")
        ])

        XCTAssertEqual(
            normalizer.normalize("Vi kör Kubernetis idag", language: .swedish),
            "Vi kör Kubernetes idag"
        )
    }

    func testBuildsDictionaryFromEntries() {
        let normalizer = TranscriptNormalizer(dictionaryEntries: [
            DictionaryEntry(original: "Mummla", replacement: "Mumla")
        ])

        XCTAssertEqual(
            normalizer.normalize("Mummla skriver svenska", language: .swedish),
            "Mumla skriver svenska"
        )
    }
}
