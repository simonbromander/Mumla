import Foundation
import MumlaCore
import XCTest

final class TranscriptFormattingTests: XCTestCase {
    func testProseAndParagraphs() {
        XCTAssertTrue(TranscriptFormattingPolicy.accepts(original: "hej Simon det är fredag vi ses snart", formatted: "Hej Simon, det är fredag.\n\nVi ses snart."))
        XCTAssertTrue(TranscriptFormattingPolicy.accepts(original: "vi använder Kubernetes iPhone och SDK", formatted: "Vi använder Kubernetes, iPhone och SDK."))
        XCTAssertFalse(TranscriptFormattingPolicy.accepts(original: "Simon och iPhone", formatted: "simon och IPhone."))
        XCTAssertFalse(TranscriptFormattingPolicy.accepts(original: "vi använder SDK", formatted: "Vi använder Sdk."))
    }

    func testNumbersLinksAndSymbolsStayExact() {
        for (source, output) in [
            ("kostar 3,5 miljoner", "Kostar 3.5 miljoner."),
            ("tiden är 14:30", "Tiden är 14 30."),
            ("cirka 50%", "Cirka 50."),
            ("värdet är -2", "Värdet är 2."),
            ("öppna https://mumla.app/path", "Öppna https://mumla.app. /path"),
            ("mejla hej@mumla.app", "Mejla hej@mumla. app."),
            ("foo_bar = 2", "Foo_bar 2."),
            ("a + b", "A b +")
        ] { XCTAssertFalse(TranscriptFormattingPolicy.accepts(original: source, formatted: output), source) }
        XCTAssertTrue(TranscriptFormattingPolicy.accepts(original: "mejla hej@mumla.app nästa vecka", formatted: "Mejla hej@mumla.app nästa vecka."))
        XCTAssertTrue(TranscriptFormattingPolicy.accepts(original: "öppna https://mumla.app nästa vecka", formatted: "Öppna https://mumla.app nästa vecka."))
    }

    func testRejectsInstructionResponsesAndChangedMeaningWords() {
        let source = "vi ska inte köpa huset"
        for output in ["Vi ska köpa huset.", "Vi borde inte köpa huset.", "Huset ska vi inte köpa.", "Här är texten: Vi ska inte köpa huset.", "```Vi ska inte köpa huset.```", "", "Jag kan inte hjälpa till med det."] {
            XCTAssertFalse(TranscriptFormattingPolicy.accepts(original: source, formatted: output))
        }
    }

    func testHistoryAcceptanceAndRestoreSurviveReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DictationHistoryStore(directory: directory)
        let record = DictationRecord(text: "hej Simon vi ses snart", language: .swedish)
        try store.append(record)
        let records = try store.applyFormatting(recordID: record.id, expectedText: record.text, formattedText: "Hej Simon. Vi ses snart.")
        XCTAssertEqual(records.first?.originalText, record.text)
        XCTAssertEqual(try store.load(), records)
        XCTAssertEqual(records.first?.id, record.id)
        XCTAssertEqual(records.first?.createdAt, record.createdAt)
        XCTAssertThrowsError(try store.applyFormatting(recordID: record.id, expectedText: record.text, formattedText: "Hej Simon, vi ses snart."))
        XCTAssertEqual(try store.load(), records)
        let restored = try store.restoreOriginal(recordID: record.id, expectedText: records[0].text)
        XCTAssertEqual(restored.first?.text, record.text)
        XCTAssertNil(restored.first?.originalText)
    }

    func testInvalidOutputNeverOverwritesHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DictationHistoryStore(directory: directory)
        let record = DictationRecord(text: "vi ska inte köpa huset", language: .swedish)
        try store.append(record)
        XCTAssertThrowsError(try store.applyFormatting(recordID: record.id, expectedText: record.text, formattedText: "Vi ska köpa huset."))
        XCTAssertEqual(try store.load().first?.text, record.text)
        XCTAssertNil(try store.load().first?.originalText)
    }

    func testOldHistoryWithoutOriginalTextDecodes() throws {
        let record = DictationRecord(text: "Original.", language: .english)
        let data = try JSONEncoder().encode(record)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "originalText")
        let decoded = try JSONDecoder().decode(DictationRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded, record)
    }
}
