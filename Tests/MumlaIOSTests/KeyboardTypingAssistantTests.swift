import MumlaCore
import MumlaUI
import XCTest

@MainActor
final class KeyboardTypingAssistantTests: XCTestCase {
    private func assistant(_ provider: FixtureSpelling = FixtureSpelling()) -> KeyboardTypingAssistant {
        let defaults = UserDefaults(suiteName: "MumlaKeyboardTypingTests.\(UUID().uuidString)")!
        return KeyboardTypingAssistant(spelling: provider, defaults: defaults)
    }
    private func update(_ assistant: KeyboardTypingAssistant, _ before: String, allows: Bool = true) {
        assistant.update(context: .init(before: before), capitalization: .sentences, allowsCorrection: allows)
    }

    func testLocalSuggestionsKeepOriginalAndAutomaticReplacementCanBeUndone() {
        let typing = assistant()
        update(typing, "Hellp")
        XCTAssertEqual(typing.suggestions.map(\.text), ["Hellp", "Hello"])
        XCTAssertTrue(typing.suggestions[0].original)
        XCTAssertEqual(typing.insert(" ", at: 1), .init(deleteCount: 5, insertion: "Hello "))
        update(typing, "Hello ")
        XCTAssertEqual(typing.delete(), .init(deleteCount: 6, insertion: "Hellp"))
        update(typing, "Hellp")
        XCTAssertEqual(typing.insert(" ", at: 2), .init(insertion: " "))
    }

    func testCorrectionToggleAndLiteralFieldsDoNotModifyTyping() {
        let typing = assistant()
        update(typing, "hellp")
        typing.toggleCorrection()
        XCTAssertEqual(typing.insert(" "), .init(insertion: " "))
        XCTAssertEqual(typing.suggestions.last?.text, "hello")
        typing.toggleCorrection(); update(typing, "hellp", allows: false)
        XCTAssertTrue(typing.suggestions.isEmpty)
        XCTAssertEqual(typing.insert(" "), .init(insertion: " "))
        update(typing, "hellp ", allows: false)
        XCTAssertEqual(typing.insert(" "), .init(insertion: " "))
    }

    func testSupplementaryNamesAreProtectedAndShortcutsRemainLocal() {
        let typing = assistant()
        typing.setLexicon([(input: "Hellp", output: "Hellp"), (input: "brb", output: "be right back")])
        update(typing, "Hellp")
        XCTAssertEqual(typing.insert(" "), .init(insertion: " "))
        update(typing, "brb")
        XCTAssertEqual(typing.suggestions.map(\.text), ["brb", "be right back"])
        XCTAssertEqual(typing.insert(" "), .init(deleteCount: 3, insertion: "be right back "))
    }

    func testMidSentenceUnknownNamesAreSuggestedButNeverAutocorrected() {
        let typing = assistant()
        update(typing, "Meet Hellp")
        XCTAssertEqual(typing.suggestions.last?.text, "Hello")
        XCTAssertEqual(typing.insert(" "), .init(insertion: " "))
    }

    func testLanguageToggleRefreshesCachedSpellcheckingAndPersistsOnlyPreferences() {
        let spelling = FixtureSpelling()
        let typing = assistant(spelling)
        update(typing, "hellp"); update(typing, "hellp")
        XCTAssertEqual(spelling.languages, ["sv"])
        typing.toggleLanguage()
        XCTAssertEqual(typing.language, "en")
        XCTAssertEqual(spelling.languages, ["sv", "en"])
    }

    func testStaleSuggestionSelectionOrCaretCannotReplaceOtherText() {
        let typing = assistant()
        update(typing, "hellp")
        let suggestion = typing.suggestions[1]
        update(typing, "hello")
        XCTAssertNil(typing.choose(suggestion))
        update(typing, "hellp", allows: false)
        XCTAssertNil(typing.choose(suggestion))
        typing.update(context: .init(before: "hellp", after: "suffix"), capitalization: .none, allowsCorrection: true)
        XCTAssertTrue(typing.suggestions.isEmpty)
        XCTAssertNil(typing.choose(suggestion))
        typing.update(context: .init(before: "hellp", selection: "selected"), capitalization: .none, allowsCorrection: true)
        XCTAssertEqual(typing.insert(" "), .init(insertion: " "))
    }

    func testRealLocalSpellcheckerSupportsEnglishAndSwedishWithoutAModel() {
        let spelling = LocalKeyboardSpelling()
        XCTAssertFalse(spelling.check("hello", language: "en").misspelled)
        XCTAssertFalse(spelling.check("tangentbord", language: "sv").misspelled)
        XCTAssertTrue(spelling.check("helllo", language: "en").guesses.contains("hello"))
        XCTAssertFalse(spelling.check("hello", language: "unavailable").misspelled)
    }

    func testDeactivationDropsTypingContextAndPendingCorrections() {
        let typing = assistant()
        update(typing, "hellp")
        _ = typing.insert(" ")
        typing.deactivate()
        XCTAssertTrue(typing.suggestions.isEmpty)
        XCTAssertFalse(typing.automaticUppercase)
        XCTAssertEqual(typing.delete(), .init(deleteCount: 1, insertion: ""))
    }
}

@MainActor
private final class FixtureSpelling: KeyboardSpellingProviding {
    var languages: [String] = []
    func check(_ word: String, language: String) -> KeyboardSpellingResult {
        languages.append(language)
        if word.lowercased() == "hellp" { return .init(misspelled: true, guesses: ["hello"]) }
        return .init(misspelled: false)
    }
}
