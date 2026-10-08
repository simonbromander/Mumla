import Foundation
import MumlaCore
import XCTest

final class TranscriptSummaryTests: XCTestCase {
    func testSaveSummaryKeepsTranscriptAndRejectsStalePreview() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DictationHistoryStore(directory: directory)
        let record = DictationRecord(text: "hej Simon vi ses på fredag", language: .swedish)
        try store.append(record)
        let saved = try store.applySummary(recordID: record.id, expectedText: record.text, summary: "Vi ses på fredag.")
        XCTAssertEqual(saved.first?.text, record.text)
        XCTAssertEqual(try store.load().first?.summary, "Vi ses på fredag.")
        XCTAssertThrowsError(try store.applySummary(recordID: record.id, expectedText: "changed", summary: "New summary"))
        XCTAssertThrowsError(try store.applySummary(recordID: record.id, expectedText: record.text, summary: ""))
        let formatted = try store.applyFormatting(recordID: record.id, expectedText: record.text, formattedText: "Hej Simon. Vi ses på fredag.")
        XCTAssertNil(formatted.first?.summary)
        try store.applySummary(recordID: record.id, expectedText: formatted[0].text, summary: "Friday")
        let restored = try store.restoreOriginal(recordID: record.id, expectedText: formatted[0].text)
        XCTAssertNil(restored.first?.summary)
        XCTAssertEqual(restored.first?.text, record.text)
    }

    func testWordCorrectionInvalidatesSummary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DictationHistoryStore(directory: directory)
        let record = DictationRecord(text: "hej Simon", language: .swedish)
        try store.append(record)
        try store.applySummary(recordID: record.id, expectedText: record.text, summary: "Hej Simon.")
        let selection = try XCTUnwrap(TranscriptWordSelection(record: record, range: NSRange(location: 4, length: 5)))
        let corrected = try store.correctWord(selection, replacement: "Sara", dictionary: DictionaryStore(directory: directory))
        XCTAssertNil(corrected.history.first?.summary)
    }

    func testOldHistoryAndPromptLimits() throws {
        let old = """
        {"id":"00000000-0000-0000-0000-000000000001","createdAt":0,"text":"hej","language":"sv"}
        """
        let record = try JSONDecoder().decode(DictationRecord.self, from: Data(old.utf8))
        XCTAssertNil(record.summary)
        XCTAssertEqual(LocalTextPreferences.boundedPrompt("  Short paragraphs \n"), "Short paragraphs")
        XCTAssertEqual(LocalTextPreferences.boundedPrompt(String(repeating: "å", count: 501)).count, 500)
    }
}
