import Foundation

public struct TranscriptWordSelection: Identifiable, Sendable {
    public let id = UUID()
    public let recordID: UUID
    public let original: String
    public let text: String
    public let range: NSRange

    public init?(record: DictationRecord, range: NSRange) {
        let length = record.text.utf16.count
        guard range.location >= 0, range.length > 0, range.location <= length,
              range.length <= length - range.location,
              let selectedRange = Range(range, in: record.text),
              Self.wordExpression.matches(in: record.text, range: NSRange(record.text.startIndex..., in: record.text))
                .contains(where: { $0.range == range }) else { return nil }
        let word = String(record.text[selectedRange])
        guard word.unicodeScalars.contains(where: CharacterSet.letters.contains) else { return nil }
        recordID = record.id
        original = word
        text = record.text
        self.range = range
    }

    public func replacing(with replacement: String) throws -> String {
        let word = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isWord(word), word != original, let selectedRange = Range(range, in: text) else {
            throw TranscriptCorrectionError.invalidWord
        }
        return text.replacingCharacters(in: selectedRange, with: word)
    }

    public static func isWord(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return !text.isEmpty && text.unicodeScalars.contains(where: CharacterSet.letters.contains)
            && wordExpression.firstMatch(in: text, range: range)?.range == range
    }

    private static let wordExpression = try! NSRegularExpression(
        pattern: #"[\p{L}\p{N}][\p{L}\p{M}\p{N}]*(?:[-'’][\p{L}\p{N}][\p{L}\p{M}\p{N}]*)*"#
    )
}

public enum TranscriptCorrectionError: Error {
    case invalidWord
    case transcriptChanged
    case dictionaryRollbackFailed
}
