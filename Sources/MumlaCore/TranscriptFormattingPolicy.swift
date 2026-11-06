import Foundation

public enum TranscriptFormattingPolicy {
    public static let maximumCharacters = 1_500

    public static func accepts(original: String, formatted: String) -> Bool {
        guard !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              original.count <= maximumCharacters,
              !formatted.isEmpty, formatted.count <= original.count * 2 + 32 else { return false }
        if acceptsContent(original: original, formatted: formatted) { return true }
        guard let listContent = removingAddedListMarkers(from: formatted) else { return false }
        return acceptsContent(original: original, formatted: listContent)
    }

    private static func acceptsContent(original: String, formatted: String) -> Bool {
        let words = #"[\p{L}\p{M}\p{N}_]+(?:['’\-][\p{L}\p{M}\p{N}_]+)*"#
        let source = matches(words, in: original)
        let output = matches(words, in: formatted)
        guard !source.isEmpty, source.count == output.count else { return false }
        for (before, after) in zip(source, output) {
            if before == after { continue }
            // Only sentence-style capitalization of a lowercase word is allowed.
            guard before.allSatisfy(\.isLetter), before == before.lowercased(),
                  after == before.prefix(1).uppercased() + before.dropFirst() else { return false }
        }
        let numbers = #"[+\-]?\p{N}+(?:[.,:/\-]\p{N}+)*(?:\s?%)?"#
        guard matches(numbers, in: original) == matches(numbers, in: formatted) else { return false }
        let links = #"(?:https?://|www\.)[^\s<>]+|[\p{L}\p{N}._%+\-]+@[\p{L}\p{N}.\-]+\.[\p{L}]{2,}"#
        let trimLink: (String) -> String = { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:")) }
        guard matches(links, in: original).map(trimLink) == matches(links, in: formatted).map(trimLink) else { return false }
        // Symbols outside ordinary prose punctuation must remain in the same gaps.
        guard gaps(words, in: original).map(fixedSymbols) == gaps(words, in: formatted).map(fixedSymbols) else { return false }
        return true
    }

    private static func removingAddedListMarkers(from text: String) -> String? {
        let prefix = try! NSRegularExpression(pattern: #"^ {0,3}(?:[-*•][\t ]+|([1-9][0-9]{0,2})[.)][\t ]+)(?=\S)"#)
        var nextNumber = 1
        var itemCount = 0
        var lines: [String] = []
        for line in text.components(separatedBy: .newlines) {
            guard let match = prefix.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let range = Range(match.range, in: line) else { lines.append(line); continue }
            if let numberRange = Range(match.range(at: 1), in: line) {
                guard Int(line[numberRange]) == nextNumber else { return nil }
                nextNumber += 1
            }
            itemCount += 1
            lines.append(String(line[range.upperBound...]))
        }
        // Only new list markers are ignored. Original numbers and symbols still
        // pass through the full content check, including signs, links and their positions.
        return itemCount > 0 ? lines.joined(separator: "\n") : nil
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    private static func gaps(_ pattern: String, in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        var end = text.startIndex
        var result: [String] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            result.append(String(text[end..<range.lowerBound]))
            end = range.upperBound
        }
        result.append(String(text[end...]))
        return result
    }

    private static func fixedSymbols(_ text: String) -> String {
        let allowed = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,!?;:"))
        return String(text.unicodeScalars.filter { !allowed.contains($0) })
    }
}
