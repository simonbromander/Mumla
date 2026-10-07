import Foundation

public enum TranscriptFormattingPolicy {
    public static let maximumCharacters = 1_500

    public static func accepts(original: String, formatted: String) -> Bool {
        guard !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              original.count <= maximumCharacters,
              !formatted.isEmpty, formatted.count <= original.count * 2 + 32 else { return false }
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
