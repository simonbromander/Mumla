import MumlaCore
import XCTest

final class KeyboardTypingTests: XCTestCase {
    func testCapitalizationHonorsFieldModesAndSentenceBoundaries() {
        for text in ["", "Hej. ", "Hej!  ", "Hej?\" ", "Hej\n", "Hej\n  "] {
            XCTAssertTrue(KeyboardTypingContext(before: text).uppercase(for: .sentences), text)
        }
        for text in ["Hej", "Hej ", "Hej.", "Hej. nästa", "hej\nnu"] {
            XCTAssertFalse(KeyboardTypingContext(before: text).uppercase(for: .sentences), text)
        }
        XCTAssertFalse(KeyboardTypingContext(before: nil).uppercase(for: .sentences))
        XCTAssertFalse(KeyboardTypingContext(before: "", selection: "Hej").uppercase(for: .sentences))
        XCTAssertFalse(KeyboardTypingContext(before: "").uppercase(for: .none))
        XCTAssertTrue(KeyboardTypingContext(before: "hej ").uppercase(for: .words))
        XCTAssertTrue(KeyboardTypingContext(before: "hej").uppercase(for: .allCharacters))
    }

    func testAutomaticShiftCanBeOverriddenAndDoesNotUnlockCaps() {
        var shift = MumlaKeyboardShift()
        shift.updateAutomatic(true); XCTAssertTrue(shift.uppercase)
        shift.tap(at: 1); shift.updateAutomatic(true); XCTAssertFalse(shift.uppercase)
        shift.didType(); shift.updateAutomatic(true); XCTAssertTrue(shift.uppercase)
        shift.reset(); shift.tap(at: 2); shift.tap(at: 2.1)
        shift.didType(); shift.updateAutomatic(false); XCTAssertTrue(shift.locked); XCTAssertTrue(shift.uppercase)
    }

    func testWordContextDoesNotRewriteSensitiveOrPartialTokens() {
        XCTAssertEqual(KeyboardTypingContext(before: "Hej åäö").word, "åäö")
        XCTAssertEqual(KeyboardTypingContext(before: "\"don't").word, "don't")
        for text in ["a@b.se", "https://mumla.app", "foo_bar", "he1o", "hello,", String(repeating: "a", count: 49)] {
            XCTAssertNil(KeyboardTypingContext(before: text).word, text)
        }
        XCTAssertNil(KeyboardTypingContext(before: "hel", after: "lo").word)
        XCTAssertNil(KeyboardTypingContext(before: "hello", selection: "there").word)
        XCTAssertNil(KeyboardTypingContext(before: nil).word)
    }

    func testRapidDoubleSpaceAddsPeriodButSlowOrUnrelatedSpacesDoNot() {
        var engine = KeyboardTypingEngine()
        _ = engine.insert(" ", context: .init(before: "Hej"), at: 1)
        XCTAssertEqual(engine.insert(" ", context: .init(before: "Hej "), at: 1.2), .init(deleteCount: 1, insertion: ". "))
        _ = engine.insert(" ", context: .init(before: "Hej"), at: 2)
        XCTAssertEqual(engine.insert(" ", context: .init(before: "Hej "), at: 3), .init(insertion: " "))
        _ = engine.insert(" ", context: .init(before: "Hej"), at: 4)
        XCTAssertEqual(engine.insert(" ", context: .init(before: "Bye "), at: 4.1), .init(insertion: " "))
        _ = engine.insert(" ", context: .init(before: "Hej."), at: 5)
        XCTAssertEqual(engine.insert(" ", context: .init(before: "Hej. "), at: 5.1), .init(insertion: " "))
    }

    func testDoubleSpaceHonorsLiteralFieldsSelectionsAndCaretChanges() {
        var engine = KeyboardTypingEngine()
        _ = engine.insert(" ", context: .init(before: "hej"), at: 1)
        XCTAssertEqual(engine.insert(" ", context: .init(before: "hej "), at: 1.1, doubleSpacePeriod: false), .init(insertion: " "))
        _ = engine.insert(" ", context: .init(before: "hej", after: "bye"), at: 2)
        XCTAssertEqual(engine.insert(" ", context: .init(before: "hej ", after: "changed"), at: 2.1), .init(insertion: " "))
        _ = engine.insert(" ", context: .init(before: "hej"), at: 3)
        XCTAssertEqual(engine.insert(" ", context: .init(before: "hej ", selection: "selected"), at: 3.1), .init(insertion: " "))
    }

    func testAutomaticReplacementCanBeUndoneWithoutRecorrecting() {
        var engine = KeyboardTypingEngine()
        let edit = engine.insert(" ", context: .init(before: "Say hellp"), at: 1, correction: "hello")
        XCTAssertEqual(edit, .init(deleteCount: 5, insertion: "hello "))
        XCTAssertEqual(engine.delete(context: .init(before: "Say hello ")), .init(deleteCount: 6, insertion: "hellp"))
        XCTAssertEqual(engine.insert(" ", context: .init(before: "Say hellp"), at: 2, correction: "hello"), .init(insertion: " "))
    }

    func testCorrectionUndoCannotChangeADifferentCaretOrAfterReset() {
        var engine = KeyboardTypingEngine()
        _ = engine.insert(" ", context: .init(before: "hellp"), at: 1, correction: "hello")
        XCTAssertEqual(engine.delete(context: .init(before: "Other")), .init(deleteCount: 1, insertion: ""))
        _ = engine.insert(" ", context: .init(before: "hellp"), at: 2, correction: "hello")
        engine.reset()
        XCTAssertEqual(engine.delete(context: .init(before: "hello ")), .init(deleteCount: 1, insertion: ""))
    }

    func testSuggestionIsBoundToCurrentWordAndSupportsOriginalAndShortcut() {
        var engine = KeyboardTypingEngine()
        XCTAssertEqual(engine.choose("hello", source: "hell", context: .init(before: "Say hell")), .init(deleteCount: 4, insertion: "hello "))
        XCTAssertEqual(engine.choose("hellp", source: "hellp", context: .init(before: "hellp")), .init(deleteCount: 5, insertion: "hellp "))
        XCTAssertEqual(engine.choose("be right back", source: "brb", context: .init(before: "brb")), .init(deleteCount: 3, insertion: "be right back "))
        XCTAssertNil(engine.choose("hello", source: "hell", context: .init(before: "help")))
        XCTAssertNil(engine.choose("hello", source: "hell", context: .init(before: "hell", after: "o")))
    }

    func testConservativeCorrectionRejectsAmbiguousNamesIdentifiersAndNumbers() {
        XCTAssertEqual(KeyboardSpellingPolicy.automaticCorrection(word: "hellp", guesses: ["hello", "helpful"]), "hello")
        XCTAssertEqual(KeyboardSpellingPolicy.automaticCorrection(word: "Tangetbord", guesses: ["tangentbord"]), "Tangentbord")
        XCTAssertEqual(KeyboardSpellingPolicy.automaticCorrection(word: "tehse", guesses: ["these"]), "these")
        XCTAssertNil(KeyboardSpellingPolicy.automaticCorrection(word: "hellp", guesses: ["hello", "hells"]))
        for word in ["Bob", "HELLO", "iPhnoe", "ab12", "user_name"] {
            XCTAssertNil(KeyboardSpellingPolicy.automaticCorrection(word: word, guesses: ["hello"]))
        }
        XCTAssertNil(KeyboardSpellingPolicy.automaticCorrection(word: "hellp", guesses: [""]))
        XCTAssertEqual(KeyboardSpellingPolicy.matchCase("iPhone", to: "Iphone"), "iPhone")
        XCTAssertEqual(KeyboardSpellingPolicy.automaticCorrection(word: "iphnoe", guesses: ["iPhone"]), "iPhone")
    }

    func testAccentsPreserveCaseAndSwedishCharacters() {
        XCTAssertTrue(KeyboardAccents.alternatives(for: "a").contains("å"))
        XCTAssertTrue(KeyboardAccents.alternatives(for: "E").contains("É"))
        XCTAssertTrue(KeyboardAccents.alternatives(for: "ö").contains("ø"))
        XCTAssertTrue(KeyboardAccents.alternatives(for: "n").contains("ñ"))
        XCTAssertTrue(KeyboardAccents.alternatives(for: "1").isEmpty)
    }

    func testCursorDragMovesIncrementallyAndReversesWithoutJumping() {
        var drag = KeyboardCursorDrag()
        XCTAssertEqual(drag.move(translation: 8), 0)
        XCTAssertEqual(drag.move(translation: 28), 3)
        XCTAssertEqual(drag.move(translation: 35), 0)
        XCTAssertEqual(drag.move(translation: 10), -2)
        XCTAssertEqual(drag.move(translation: -10), -2)
        drag.reset(); XCTAssertEqual(drag.move(translation: -20), -2)
    }
}
