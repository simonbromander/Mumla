import Foundation
import XCTest
@testable import MumlaCore

final class TranscriptCorrectionTests: XCTestCase {
    func testCorrectionPreservesMetadataFormattingAndOtherOccurrencesAfterReload() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = DictationHistoryStore(directory: directory)
        let dictionary = DictionaryStore(directory: directory)
        let record = DictationRecord(text: "🎙️ Kubernetis,\n  Kubernetis!", language: .swedish, durationMilliseconds: 17000)
        try history.append(record)
        let newest = DictationRecord(text: "Newest", language: .english)
        try history.append(newest)
        let range = (record.text as NSString).range(of: "Kubernetis", options: .backwards)
        let selection = try XCTUnwrap(TranscriptWordSelection(record: record, range: range))
        let result = try history.correctWord(selection, replacement: " Kubernetes ", dictionary: dictionary)
        XCTAssertEqual(result.history.map(\.id), [newest.id, record.id])
        XCTAssertEqual(result.history[1].text, "🎙️ Kubernetis,\n  Kubernetes!")
        XCTAssertEqual(result.history[1].createdAt, record.createdAt)
        XCTAssertEqual(result.history[1].durationMilliseconds, record.durationMilliseconds)
        XCTAssertEqual(result.history[1].language, record.language)
        XCTAssertEqual(try DictationHistoryStore(directory: directory).load(), result.history)
        XCTAssertEqual(try DictionaryStore(directory: directory).load(), result.dictionary)
        XCTAssertEqual(result.dictionary.first?.original, "Kubernetis")
        XCTAssertEqual(result.dictionary.first?.replacement, "Kubernetes")
        XCTAssertEqual(TranscriptNormalizer(dictionaryEntries: result.dictionary).normalize("Kubernetis fungerar", language: .swedish), "Kubernetes fungerar")
    }

    func testRejectsPartialWordsPhrasesPunctuationAndInvalidRanges() {
        let record = DictationRecord(text: "Hej Åsa-Lisa,\nKubernetis fungerar!", language: .swedish)
        for value in ["Hej Åsa", "Åsa", "bernet", "!", ""] {
            XCTAssertNil(TranscriptWordSelection(record: record, range: (record.text as NSString).range(of: value)), value)
        }
        XCTAssertNil(TranscriptWordSelection(record: record, range: NSRange(location: NSNotFound, length: 0)))
        XCTAssertNil(TranscriptWordSelection(record: record, range: NSRange(location: 1, length: Int.max)))
        XCTAssertNil(TranscriptWordSelection(record: record, range: NSRange(location: -1, length: 2)))
        XCTAssertNotNil(TranscriptWordSelection(record: record, range: (record.text as NSString).range(of: "Åsa-Lisa")))
        for word in ["Örjan", "Åsa-Lisa", "O’Neill", "GPT5", "A\u{030A}sa"] {
            XCTAssertTrue(TranscriptWordSelection.isWord(word), word)
        }
        for word in ["", " ", "two words", "word!", "123", "🤔"] {
            XCTAssertFalse(TranscriptWordSelection.isWord(word), word)
        }
    }

    func testStaleOrDeletedSelectionCannotOverwriteTranscriptOrDictionary() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = DictationHistoryStore(directory: directory)
        let dictionary = DictionaryStore(directory: directory)
        let record = DictationRecord(text: "Mummla", language: .swedish)
        try history.append(record)
        let selection = try XCTUnwrap(TranscriptWordSelection(record: record, range: NSRange(location: 0, length: 6)))
        let saved = try history.correctWord(selection, replacement: "Mumla", dictionary: dictionary)
        XCTAssertThrowsError(try history.correctWord(selection, replacement: "Mummel", dictionary: dictionary))
        XCTAssertEqual(try history.load(), saved.history)
        XCTAssertEqual(try dictionary.load(), saved.dictionary)
        try history.clear()
        XCTAssertThrowsError(try history.correctWord(selection, replacement: "Mummel", dictionary: dictionary))
        XCTAssertEqual(try dictionary.load(), saved.dictionary)
        XCTAssertTrue(try history.load().isEmpty)
    }

    func testDictionaryWriteFailureLeavesTranscriptUntouched() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = DictationHistoryStore(directory: directory)
        let record = DictationRecord(text: "Mummla", language: .swedish)
        try history.append(record)
        let blocked = directory.appendingPathComponent("blocked")
        try Data().write(to: blocked)
        let dictionary = DictionaryStore(directory: blocked)
        let selection = try XCTUnwrap(TranscriptWordSelection(record: record, range: NSRange(location: 0, length: 6)))
        XCTAssertThrowsError(try history.correctWord(selection, replacement: "Mumla", dictionary: dictionary))
        XCTAssertEqual(try history.load(), [record])
    }

    func testHistoryWriteFailureRestoresPreviousDictionaryEntry() throws {
        let directory = temporaryDirectory()
        let historyDirectory = directory.appendingPathComponent("history")
        let history = DictationHistoryStore(directory: historyDirectory)
        let dictionary = DictionaryStore(directory: directory.appendingPathComponent("words"))
        let record = DictationRecord(text: "Mummla", language: .swedish)
        try history.append(record)
        let previousDictionary = try dictionary.add(original: "Mummla", replacement: "Mummel")
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: historyDirectory.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: historyDirectory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let selection = try XCTUnwrap(TranscriptWordSelection(record: record, range: NSRange(location: 0, length: 6)))
        XCTAssertThrowsError(try history.correctWord(selection, replacement: "Mumla", dictionary: dictionary))
        XCTAssertEqual(try history.load(), [record])
        XCTAssertEqual(try dictionary.load(), previousDictionary)
    }

    func testInvalidReplacementDoesNotPersistAnything() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = DictationHistoryStore(directory: directory)
        let dictionary = DictionaryStore(directory: directory)
        let record = DictationRecord(text: "Mummla", language: .swedish)
        try history.append(record)
        let selection = try XCTUnwrap(TranscriptWordSelection(record: record, range: NSRange(location: 0, length: 6)))
        for replacement in ["", " ", "two words", "Mummla"] {
            XCTAssertThrowsError(try history.correctWord(selection, replacement: replacement, dictionary: dictionary))
        }
        XCTAssertEqual(try history.load(), [record])
        XCTAssertTrue(try dictionary.load().isEmpty)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MumlaCorrections-\(UUID().uuidString)", isDirectory: true)
    }
}
