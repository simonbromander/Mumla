import Foundation

public struct DictionaryReplacement: Codable, Equatable, Sendable {
    public var source: String
    public var replacement: String

    public init(source: String, replacement: String) {
        self.source = source
        self.replacement = replacement
    }
}

public struct TranscriptNormalizer: Sendable {
    public var dictionary: [DictionaryReplacement]
    public var removesFillers: Bool

    public init(dictionary: [DictionaryReplacement] = [], removesFillers: Bool = true) {
        self.dictionary = dictionary
        self.removesFillers = removesFillers
    }

    public init(dictionaryEntries: [DictionaryEntry], removesFillers: Bool = true) {
        self.init(
            dictionary: dictionaryEntries.map {
                DictionaryReplacement(source: $0.original, replacement: $0.replacement)
            },
            removesFillers: removesFillers
        )
    }

    public func normalize(_ transcript: String, language: MumlaLanguage) -> String {
        let replaced = applyDictionary(to: transcript)
        guard removesFillers else {
            return collapseWhitespace(replaced)
        }

        let fillers = Self.fillers(for: language)
        let tokens = replaced
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { token in
                let stripped = stripToken(token)
                return !fillers.contains(stripped)
            }

        return collapseWhitespace(tokens.joined(separator: " "))
    }

    public static func fillers(for language: MumlaLanguage) -> Set<String> {
        switch language {
        case .swedish:
            return ["eh", "öh", "ehm"]
        case .english:
            return ["um", "uh"]
        }
    }

    private func applyDictionary(to transcript: String) -> String {
        dictionary.reduce(transcript) { current, entry in
            guard !entry.source.isEmpty else {
                return current
            }

            let pattern = #"(?i)(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: entry.source) + #"(?![\p{L}\p{N}])"#

            guard let expression = try? NSRegularExpression(pattern: pattern) else {
                return current
            }

            let range = NSRange(current.startIndex..<current.endIndex, in: current)
            return expression.stringByReplacingMatches(
                in: current,
                range: range,
                withTemplate: entry.replacement
            )
        }
    }

    private func stripToken(_ token: String) -> String {
        let kept = token.unicodeScalars.filter { scalar in
            CharacterSet.letters.contains(scalar)
        }
        return String(String.UnicodeScalarView(kept)).lowercased()
    }

    private func collapseWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
