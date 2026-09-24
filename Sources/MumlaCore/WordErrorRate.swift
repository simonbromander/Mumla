import Foundation

public struct WordErrorRateResult: Codable, Equatable, Sendable {
    public var substitutions: Int
    public var insertions: Int
    public var deletions: Int
    public var referenceWordCount: Int
    public var hypothesisWordCount: Int

    public var totalErrors: Int {
        substitutions + insertions + deletions
    }

    public var errorRate: Double {
        guard referenceWordCount > 0 else {
            return hypothesisWordCount == 0 ? 0 : 1
        }
        return Double(totalErrors) / Double(referenceWordCount)
    }

    public init(
        substitutions: Int,
        insertions: Int,
        deletions: Int,
        referenceWordCount: Int,
        hypothesisWordCount: Int
    ) {
        self.substitutions = substitutions
        self.insertions = insertions
        self.deletions = deletions
        self.referenceWordCount = referenceWordCount
        self.hypothesisWordCount = hypothesisWordCount
    }
}

public enum WordErrorRate {
    public static func score(reference: String, hypothesis: String) -> WordErrorRateResult {
        score(referenceWords: tokenize(reference), hypothesisWords: tokenize(hypothesis))
    }

    public static func tokenize(_ text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "sv_SE"))
        var scalars = String.UnicodeScalarView()
        var previousWasSpace = true

        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "'" {
                scalars.append(scalar)
                previousWasSpace = false
            } else if !previousWasSpace {
                scalars.append(" ")
                previousWasSpace = true
            }
        }

        return String(scalars)
            .split(separator: " ")
            .map(String.init)
    }

    public static func score(referenceWords: [String], hypothesisWords: [String]) -> WordErrorRateResult {
        let rows = referenceWords.count + 1
        let columns = hypothesisWords.count + 1
        var table = Array(repeating: Array(repeating: Cell.zero, count: columns), count: rows)

        for row in 1..<rows {
            table[row][0] = Cell(
                cost: row,
                substitutions: 0,
                insertions: 0,
                deletions: row
            )
        }

        for column in 1..<columns {
            table[0][column] = Cell(
                cost: column,
                substitutions: 0,
                insertions: column,
                deletions: 0
            )
        }

        guard rows > 1 || columns > 1 else {
            return WordErrorRateResult(
                substitutions: 0,
                insertions: 0,
                deletions: 0,
                referenceWordCount: referenceWords.count,
                hypothesisWordCount: hypothesisWords.count
            )
        }

        for row in 1..<rows {
            for column in 1..<columns {
                if referenceWords[row - 1] == hypothesisWords[column - 1] {
                    table[row][column] = table[row - 1][column - 1]
                } else {
                    let substitution = table[row - 1][column - 1].adding(substitutions: 1)
                    let insertion = table[row][column - 1].adding(insertions: 1)
                    let deletion = table[row - 1][column].adding(deletions: 1)
                    table[row][column] = [substitution, insertion, deletion].min() ?? substitution
                }
            }
        }

        let cell = table[rows - 1][columns - 1]
        return WordErrorRateResult(
            substitutions: cell.substitutions,
            insertions: cell.insertions,
            deletions: cell.deletions,
            referenceWordCount: referenceWords.count,
            hypothesisWordCount: hypothesisWords.count
        )
    }
}

private struct Cell: Comparable {
    static let zero = Cell(cost: 0, substitutions: 0, insertions: 0, deletions: 0)

    var cost: Int
    var substitutions: Int
    var insertions: Int
    var deletions: Int

    static func < (lhs: Cell, rhs: Cell) -> Bool {
        if lhs.cost != rhs.cost {
            return lhs.cost < rhs.cost
        }
        if lhs.substitutions != rhs.substitutions {
            return lhs.substitutions < rhs.substitutions
        }
        if lhs.deletions != rhs.deletions {
            return lhs.deletions < rhs.deletions
        }
        return lhs.insertions < rhs.insertions
    }

    func adding(substitutions: Int = 0, insertions: Int = 0, deletions: Int = 0) -> Cell {
        Cell(
            cost: cost + substitutions + insertions + deletions,
            substitutions: self.substitutions + substitutions,
            insertions: self.insertions + insertions,
            deletions: self.deletions + deletions
        )
    }
}
