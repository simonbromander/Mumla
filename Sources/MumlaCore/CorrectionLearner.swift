import Foundation

public struct CorrectionCandidate: Codable, Equatable, Hashable, Sendable {
    public var original: String
    public var replacement: String

    public init(original: String, replacement: String) {
        self.original = original
        self.replacement = replacement
    }
}

public enum CorrectionLearningResult: Equatable, Sendable {
    case ignored
    case pending(CorrectionCandidate, count: Int)
    case learned(DictionaryEntry)
}

public final class CorrectionLearner: @unchecked Sendable {
    private let threshold: Int
    private var counts: [CorrectionCandidate: Int] = [:]
    private let lock = NSLock()

    public init(threshold: Int = 2) {
        self.threshold = max(1, threshold)
    }

    public func observe(originalText: String, editedText: String) -> CorrectionLearningResult {
        guard let candidate = Self.candidate(originalText: originalText, editedText: editedText) else {
            return .ignored
        }

        return lock.withLock {
            let count = (counts[candidate] ?? 0) + 1
            counts[candidate] = count

            if count >= threshold {
                counts[candidate] = nil
                return .learned(
                    DictionaryEntry(
                        original: candidate.original,
                        replacement: candidate.replacement
                    )
                )
            }

            return .pending(candidate, count: count)
        }
    }

    public static func candidate(originalText: String, editedText: String) -> CorrectionCandidate? {
        let originalWords = words(in: originalText)
        let editedWords = words(in: editedText)

        guard originalWords.count == editedWords.count else {
            return nil
        }

        let differingIndices = zip(originalWords, editedWords)
            .enumerated()
            .filter { _, pair in
                pair.0.normalized != pair.1.normalized
            }
            .map(\.offset)

        guard differingIndices.count == 1, let index = differingIndices.first else {
            return nil
        }

        let original = originalWords[index]
        let edited = editedWords[index]
        guard
            !original.containsDigit,
            !edited.containsDigit,
            isClose(original.normalized, edited.normalized)
        else {
            return nil
        }

        return CorrectionCandidate(original: original.value, replacement: edited.value)
    }

    private static func words(in text: String) -> [CorrectionWord] {
        text.split(whereSeparator: \.isWhitespace)
            .compactMap { rawWord in
                let value = String(rawWord)
                    .trimmingCharacters(in: .punctuationCharacters.union(.symbols))
                guard !value.isEmpty else { return nil }
                return CorrectionWord(value: value)
            }
    }

    private static func isClose(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else {
            return false
        }
        let maxLength = max(lhs.count, rhs.count)
        let allowedDistance = max(1, Int((Double(maxLength) * 0.35).rounded(.up)))
        return levenshteinDistance(lhs, rhs) <= allowedDistance
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let source = Array(lhs)
        let target = Array(rhs)
        guard !source.isEmpty else { return target.count }
        guard !target.isEmpty else { return source.count }

        var previous = Array(0...target.count)
        var current = Array(repeating: 0, count: target.count + 1)

        for sourceIndex in 1...source.count {
            current[0] = sourceIndex
            for targetIndex in 1...target.count {
                let substitutionCost = source[sourceIndex - 1] == target[targetIndex - 1] ? 0 : 1
                current[targetIndex] = min(
                    previous[targetIndex] + 1,
                    current[targetIndex - 1] + 1,
                    previous[targetIndex - 1] + substitutionCost
                )
            }
            swap(&previous, &current)
        }

        return previous[target.count]
    }
}

private struct CorrectionWord {
    var value: String

    var normalized: String {
        value.lowercased()
    }

    var containsDigit: Bool {
        value.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
