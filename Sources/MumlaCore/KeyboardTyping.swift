import Foundation

public struct KeyboardTypingSuggestion: Equatable, Identifiable, Sendable {
    public let source: String
    public let text: String
    public let original: Bool
    public var id: String { text }
    public init(source: String, text: String, original: Bool = false) {
        self.source = source; self.text = text; self.original = original
    }
}

public enum KeyboardCapitalization: Sendable {
    case none, sentences, words, allCharacters
}

public struct KeyboardTypingContext: Equatable, Sendable {
    public var before: String?
    public var after: String?
    public var selection: String?

    public init(before: String?, after: String? = "", selection: String? = nil) {
        self.before = before; self.after = after; self.selection = selection
    }

    public var word: String? {
        guard selection?.isEmpty != false, let before,
              after?.first.map({ !$0.isLetter && $0 != "'" && $0 != "’" }) != false else { return nil }
        let token = String(before.suffix(128).reversed().prefix { !$0.isWhitespace && !"(\"“[{".contains($0) }.reversed())
        guard !token.isEmpty, token.count <= 48, token.first?.isLetter == true,
              token.last?.isLetter == true,
              token.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "’" }) else { return nil }
        return token
    }

    public func uppercase(for mode: KeyboardCapitalization) -> Bool {
        guard selection?.isEmpty != false, let before else { return mode == .allCharacters }
        switch mode {
        case .none: return false
        case .allCharacters: return true
        case .words: return before.isEmpty || before.last?.isWhitespace == true
        case .sentences:
            if before.isEmpty { return true }
            let line = before.split(separator: "\n", omittingEmptySubsequences: false).last ?? ""
            if line.allSatisfy(\.isWhitespace) { return true }
            guard before.last?.isWhitespace == true else { return false }
            let end = line.reversed().drop { $0.isWhitespace || "\"'”’)]}".contains($0) }.first
            return end.map { ".!?".contains($0) } == true
        }
    }
}

public struct KeyboardTextEdit: Equatable, Sendable {
    public var deleteCount: Int
    public var insertion: String
    public init(deleteCount: Int = 0, insertion: String) {
        self.deleteCount = deleteCount; self.insertion = insertion
    }
}

public struct KeyboardTypingEngine: Sendable {
    private var lastSpace: (time: TimeInterval, before: String?, after: String?)?
    private var undo: (original: String, applied: String, after: String?)?
    private var rejectedWord: String?
    public init() {}

    public mutating func reset() { lastSpace = nil; undo = nil; rejectedWord = nil }

    public mutating func insert(_ text: String, context: KeyboardTypingContext,
                                at time: TimeInterval, correction: String? = nil,
                                doubleSpacePeriod: Bool = true) -> KeyboardTextEdit {
        undo = nil
        if text == " ", doubleSpacePeriod, context.selection?.isEmpty != false,
           let lastSpace, time >= lastSpace.time, time - lastSpace.time <= 0.65,
           lastSpace.before == context.before, lastSpace.after == context.after,
           let before = context.before, before.last == " ",
           let previous = before.dropLast().last,
           previous.isLetter || previous.isNumber || "\"'”’)]}".contains(previous) {
            self.lastSpace = nil; rejectedWord = nil
            return KeyboardTextEdit(deleteCount: 1, insertion: ". ")
        }

        var edit = KeyboardTextEdit(insertion: text)
        if [" ", "\n", ".", ",", "!", "?", ";", ":"].contains(text),
           let word = context.word, word.lowercased() != rejectedWord,
           let correction, correction != word, !correction.isEmpty, correction.count <= 128 {
            edit = KeyboardTextEdit(deleteCount: word.count, insertion: correction + text)
            undo = (word, correction + text, context.after)
        }
        rejectedWord = nil
        if text == " ", let before = context.before {
            lastSpace = (time, String(before.dropLast(edit.deleteCount)) + edit.insertion, context.after)
        } else { lastSpace = nil }
        return edit
    }

    public mutating func delete(context: KeyboardTypingContext) -> KeyboardTextEdit {
        lastSpace = nil
        if let undo, context.selection?.isEmpty != false,
           context.before?.hasSuffix(undo.applied) == true, context.after == undo.after {
            self.undo = nil; rejectedWord = undo.original.lowercased()
            return KeyboardTextEdit(deleteCount: undo.applied.count, insertion: undo.original)
        }
        undo = nil; rejectedWord = nil
        return KeyboardTextEdit(deleteCount: 1, insertion: "")
    }

    public mutating func choose(_ replacement: String, source: String,
                                context: KeyboardTypingContext) -> KeyboardTextEdit? {
        guard context.word == source, !replacement.isEmpty, replacement.count <= 128 else { return nil }
        reset()
        // Explicit choices never run back through automatic correction.
        return KeyboardTextEdit(deleteCount: source.count, insertion: replacement + " ")
    }
}

public enum KeyboardSpellingPolicy {
    public static func matchCase(_ replacement: String, to source: String) -> String {
        if source == source.uppercased() { return replacement.uppercased() }
        if source.first?.isUppercase == true && replacement == replacement.lowercased() {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        return replacement
    }

    public static func automaticCorrection(word: String, guesses: [String]) -> String? {
        let lower = word.lowercased()
        guard word.count >= 4, word.count <= 48, word.allSatisfy(\.isLetter),
              word != word.uppercased(), word.dropFirst().allSatisfy({ !$0.isUppercase }) else { return nil }
        let limit = word.count >= 7 ? 2 : 1
        var seen = Set<String>()
        let ranked = guesses.compactMap { candidate -> (String, Int)? in
            let normalized = candidate.lowercased()
            guard !candidate.isEmpty, normalized != lower, candidate.allSatisfy(\.isLetter), candidate.count <= 48,
                  seen.insert(normalized).inserted else { return nil }
            let distance = editDistance(lower, normalized)
            return distance <= limit ? (candidate, distance) : nil
        }.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }
        guard let best = ranked.first, ranked.count == 1 || ranked[1].1 > best.1 else { return nil }
        return matchCase(best.0, to: word)
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { table[i][0] = i }
        for j in 0...b.count { table[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                table[i][j] = min(table[i - 1][j] + 1, table[i][j - 1] + 1,
                                  table[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    table[i][j] = min(table[i][j], table[i - 2][j - 2] + 1)
                }
            }
        }
        return table[a.count][b.count]
    }
}

public enum KeyboardAccents {
    public static func alternatives(for key: String) -> [String] {
        let variants: [String]
        switch key.lowercased() {
        case "a", "å", "ä": variants = ["a", "å", "ä", "á", "à", "â", "æ"]
        case "e": variants = ["e", "é", "è", "ê", "ë"]
        case "i": variants = ["i", "í", "ì", "î", "ï"]
        case "o", "ö": variants = ["o", "ö", "ó", "ò", "ô", "ø", "œ"]
        case "u": variants = ["u", "ü", "ú", "ù", "û"]
        case "y": variants = ["y", "ý", "ÿ"]
        case "c": variants = ["c", "ç"]
        case "n": variants = ["n", "ñ"]
        case "s": variants = ["s", "ß", "š"]
        case "z": variants = ["z", "ž"]
        default: return []
        }
        return key.first?.isUppercase == true ? variants.map { $0.uppercased() } : variants
    }
}

public struct KeyboardCursorDrag: Sendable {
    private var steps = 0
    public init() {}
    public mutating func move(translation: Double) -> Int {
        let next = Int(translation / 9)
        defer { steps = next }
        return next - steps
    }
    public mutating func reset() { steps = 0 }
}
