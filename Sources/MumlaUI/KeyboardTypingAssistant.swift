#if os(iOS)
import MumlaCore
import SwiftUI
import UIKit

public struct KeyboardSpellingResult {
    public var misspelled: Bool
    public var guesses: [String]
    public var completions: [String]
    public init(misspelled: Bool, guesses: [String] = [], completions: [String] = []) {
        self.misspelled = misspelled; self.guesses = guesses; self.completions = completions
    }
}

@MainActor
public protocol KeyboardSpellingProviding {
    func check(_ word: String, language: String) -> KeyboardSpellingResult
}

@MainActor
public final class LocalKeyboardSpelling: KeyboardSpellingProviding {
    private let checker = UITextChecker()
    public init() {}
    public func check(_ word: String, language: String) -> KeyboardSpellingResult {
        guard let supported = UITextChecker.availableLanguages.first(where: { $0 == language || $0.hasPrefix(language + "_") || $0.hasPrefix(language + "-") }) else {
            return KeyboardSpellingResult(misspelled: false)
        }
        let range = NSRange(word.startIndex..<word.endIndex, in: word)
        let misspelled = checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0,
                                                      wrap: false, language: supported).location != NSNotFound
        return KeyboardSpellingResult(misspelled: misspelled,
            guesses: misspelled ? Array((checker.guesses(forWordRange: range, in: word, language: supported) ?? []).prefix(12)) : [],
            completions: Array((checker.completions(forPartialWordRange: range, in: word, language: supported) ?? []).prefix(6)))
    }
}

@MainActor
public final class KeyboardTypingAssistant: ObservableObject {
    @Published public private(set) var suggestions: [KeyboardTypingSuggestion] = []
    @Published public private(set) var automaticUppercase = false
    @Published public private(set) var revision = 0
    @Published public private(set) var language: String
    @Published public private(set) var correctionEnabled: Bool
    public private(set) var allowsCorrection = true
    private var capitalization = KeyboardCapitalization.sentences
    private var context = KeyboardTypingContext(before: nil)
    private var engine = KeyboardTypingEngine()
    private let spelling: any KeyboardSpellingProviding
    private let defaults: UserDefaults
    private var lexicon: [(input: String, output: String)] = []
    private var automaticReplacement: String?
    private var cachedWord: String?
    private var cachedSpelling = KeyboardSpellingResult(misspelled: false)

    public init(spelling: (any KeyboardSpellingProviding)? = nil, defaults: UserDefaults = .standard) {
        self.spelling = spelling ?? LocalKeyboardSpelling(); self.defaults = defaults
        language = defaults.string(forKey: "keyboard.typingLanguage") == "en" ? "en" : "sv"
        correctionEnabled = defaults.object(forKey: "keyboard.autocorrect") as? Bool ?? true
    }

    public func update(context: KeyboardTypingContext, capitalization: KeyboardCapitalization,
                       allowsCorrection: Bool, externalChange: Bool = false) {
        if externalChange { engine.reset() }
        self.context = context; self.capitalization = capitalization; self.allowsCorrection = allowsCorrection
        automaticUppercase = context.uppercase(for: capitalization)
        revision &+= 1
        refreshSuggestions()
    }

    public func setLexicon(_ entries: [(input: String, output: String)]) {
        lexicon = Array(entries.filter { !$0.input.isEmpty && $0.input.count <= 48 && !$0.output.isEmpty && $0.output.count <= 128 }.prefix(2_000))
        refreshSuggestions()
    }

    public func toggleLanguage() {
        language = language == "sv" ? "en" : "sv"
        defaults.set(language, forKey: "keyboard.typingLanguage")
        cachedWord = nil; engine.reset(); refreshSuggestions()
    }

    public func toggleCorrection() {
        correctionEnabled.toggle(); defaults.set(correctionEnabled, forKey: "keyboard.autocorrect")
        engine.reset(); refreshSuggestions()
    }

    public func insert(_ text: String, at time: TimeInterval = ProcessInfo.processInfo.systemUptime) -> KeyboardTextEdit {
        let replacement = correctionEnabled && allowsCorrection ? automaticReplacement : nil
        return engine.insert(text, context: context, at: time, correction: replacement,
                             doubleSpacePeriod: allowsCorrection)
    }
    public func delete() -> KeyboardTextEdit { engine.delete(context: context) }
    public func choose(_ suggestion: KeyboardTypingSuggestion) -> KeyboardTextEdit? {
        guard allowsCorrection else { return nil }
        return engine.choose(suggestion.text, source: suggestion.source, context: context)
    }
    public func reset() { engine.reset(); cachedWord = nil }
    public func deactivate() {
        reset(); context = .init(before: nil); suggestions = []; automaticReplacement = nil
        cachedSpelling = .init(misspelled: false); automaticUppercase = false
    }

    private func refreshSuggestions() {
        automaticReplacement = nil
        guard allowsCorrection, let word = context.word else { suggestions = []; return }
        let lower = word.lowercased()
        let exact = lexicon.first { $0.input.lowercased() == lower }
        if cachedWord != word {
            cachedWord = word; cachedSpelling = spelling.check(word, language: language)
        }
        var replacements: [String] = []
        if let exact, exact.output.caseInsensitiveCompare(word) != .orderedSame {
            replacements.append(KeyboardSpellingPolicy.matchCase(exact.output, to: word))
            automaticReplacement = replacements.first
        } else if exact == nil && cachedSpelling.misspelled {
            replacements += cachedSpelling.guesses.map { KeyboardSpellingPolicy.matchCase($0, to: word) }
            // A capitalized unknown word inside a sentence is more likely a name.
            let preceding = KeyboardTypingContext(before: context.before.map { String($0.dropLast(word.count)) })
            if word.first?.isUppercase != true || preceding.uppercase(for: .sentences) {
                automaticReplacement = KeyboardSpellingPolicy.automaticCorrection(word: word, guesses: cachedSpelling.guesses)
            }
        }
        if word.count >= 2 {
            replacements += lexicon.filter { $0.input.lowercased().hasPrefix(lower) && $0.output.caseInsensitiveCompare(word) != .orderedSame }
                .prefix(6).map { KeyboardSpellingPolicy.matchCase($0.output, to: word) }
            replacements += cachedSpelling.completions.map { KeyboardSpellingPolicy.matchCase($0, to: word) }
        }
        var seen = Set([word.lowercased()])
        suggestions = [KeyboardTypingSuggestion(source: word, text: word, original: true)]
        if let automaticReplacement { replacements.insert(automaticReplacement, at: 0) }
        suggestions += replacements.filter { !$0.isEmpty && $0.count <= 128 && seen.insert($0.lowercased()).inserted }
            .prefix(2).map { KeyboardTypingSuggestion(source: word, text: $0) }
    }
}
#endif
