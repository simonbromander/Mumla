import XCTest
@testable import MumlaCore

final class TranscriptPreviewTests: XCTestCase {
    func testThreeWordPreviewDoesNotChangeFullTranscript() {
        let record = DictationRecord(text: "Vi bestämde att börja med svenska.", language: .swedish)
        XCTAssertEqual(record.compactPreview, "Vi bestämde att…")
        XCTAssertEqual(record.text, "Vi bestämde att börja med svenska.")
    }

    func testShortAndEmptyTranscriptsHaveNoEllipsis() {
        XCTAssertEqual(DictationRecord(text: "En kort rad.", language: .swedish).compactPreview, "En kort rad.")
        XCTAssertEqual(DictationRecord(text: "  \n", language: .swedish).compactPreview, "")
    }

    func testPreviewNormalizesWhitespaceWithoutChangingWords() {
        XCTAssertEqual(DictationRecord(text: "  Första\nandra\t tredje  fjärde", language: .swedish).compactPreview, "Första andra tredje…")
    }
}
