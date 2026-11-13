import AppKit
import XCTest
@testable import MumlaMac

final class ClipboardTests: XCTestCase {
    @MainActor
    func testClipboardRestoresAllItemTypesAfterPaste() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("Original", forType: .string)
        item.setData(Data([1, 2, 3]), forType: .rtf)
        board.writeObjects([item])
        let snapshot = ClipboardSnapshot.capture(from: board)
        board.clearContents()
        board.setString("Dictation", forType: .string)
        XCTAssertTrue(snapshot.restore(ifUnchanged: board.changeCount, to: board))
        XCTAssertEqual(board.string(forType: .string), "Original")
        XCTAssertEqual(board.data(forType: .rtf), Data([1, 2, 3]))
    }

    @MainActor
    func testClipboardNeverOverwritesANewerCopy() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Original", forType: .string)
        let snapshot = ClipboardSnapshot.capture(from: board)
        board.clearContents()
        board.setString("Dictation", forType: .string)
        let pasteCount = board.changeCount
        board.clearContents()
        board.setString("New user copy", forType: .string)
        XCTAssertFalse(snapshot.restore(ifUnchanged: pasteCount, to: board))
        XCTAssertEqual(board.string(forType: .string), "New user copy")
    }

    @MainActor
    func testEmptyClipboardRestoresToEmpty() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.clearContents()
        let snapshot = ClipboardSnapshot.capture(from: board)
        board.setString("Dictation", forType: .string)
        XCTAssertTrue(snapshot.restore(ifUnchanged: board.changeCount, to: board))
        XCTAssertNil(board.string(forType: .string))
    }

    @MainActor
    func testPasteVerificationChecksExpectedInsertionAndSelectionReplacement() {
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello ", after: "Hello Mumla", selectedRange: NSRange(location: 6, length: 0)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello wrong", after: "Hello Mumla", selectedRange: NSRange(location: 6, length: 5)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("hej", before: "🇸🇪 ", after: "🇸🇪 hej", selectedRange: NSRange(location: 5, length: 0)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Mumla old", after: "Mumla changed", selectedRange: NSRange(location: 9, length: 0)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: nil, after: "Mumla", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "", after: "Mumla", selectedRange: NSRange(location: 5, length: 0)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "", after: "Mumla", selectedRange: NSRange(location: -1, length: 0)))
    }

    @MainActor
    func testEditorWithoutCursorRangeRequiresAnExactNewInsertion() {
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello ", after: "Hello Mumla", selectedRange: nil))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("abc", before: "ab", after: "abcab", selectedRange: nil))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("cab", before: "ab", after: "abcab", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Mumla", after: "Mumla", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello", after: "Changed Mumla", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("", before: "Hello", after: "Hello", selectedRange: nil))
    }

    @MainActor
    func testStaleCollapsedCursorRangeStillRequiresAnExactNewInsertion() {
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello ", after: "Hello Mumla", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello", after: "Different Mumla", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello ", after: "Hello Mumla", selectedRange: NSRange(location: 0, length: 2)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Mumla", after: "Mumla", selectedRange: NSRange(location: 0, length: 0)))
    }

    @MainActor
    func testEditorLineEndingNormalizationDoesNotInvalidatePaste() {
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("One\nTwo", before: "Start: ", after: "Start: One\r\nTwo", selectedRange: NSRange(location: 7, length: 0)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "One\r\nTwo ", after: "One\nTwo Mumla", selectedRange: NSRange(location: 9, length: 0)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello ", after: "Hello  Mumla", selectedRange: NSRange(location: 6, length: 0)))
    }

    @MainActor
    func testEmptyChromiumEditorReportedAsNewlineAcceptsPaste() {
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "\n", after: "Mumla", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "\n", after: "Mumla\n", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "\n", after: "\n", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "\n", after: "Other", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("\n", before: "\n", after: "\n", selectedRange: nil))
    }

    @MainActor
    func testRichEditorParagraphTerminatorDoesNotKeepSuccessfulPasteUnconfirmed() {
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Hej Mumla", before: "", after: "Hej Mumla\n", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Hej Mumla", before: "", after: "Hej Mumla\n", selectedRange: nil))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello ", after: "Hello Mumla\n", selectedRange: NSRange(location: 6, length: 0)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello wrong", after: "Hello Mumla\n", selectedRange: NSRange(location: 6, length: 5)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello ", after: "Hello Mumla\n", selectedRange: nil))
    }

    @MainActor
    func testRichEditorTextPresentationPreservesWordAndLineBoundaries() {
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("One\nTwo", before: "", after: "One\u{2028}Two\u{2029}", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Hej Mumla", before: "", after: "Hej\u{00a0}Mumla", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello\u{00a0}", after: "Hello Mumla\n", selectedRange: NSRange(location: 6, length: 0)))
        XCTAssertTrue(ClipboardTextInserter.verifiesInsertion("hej", before: "\u{1f1f8}\u{1f1ea} ", after: "\u{1f1f8}\u{1f1ea} hej\n", selectedRange: NSRange(location: 5, length: 0)))
    }

    @MainActor
    func testRichEditorPresentationCannotConfirmMissingDuplicateOrUnrelatedText() {
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Hej Mumla", before: "", after: "Hej\n", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Hej Mumla", before: "", after: "Hej MumlaHej Mumla\n", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Hej Mumla", before: "", after: "Hej  Mumla\n", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Hej Mumla", before: "", after: "Hej\nMumla\n", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla\n", before: "", after: "Mumla", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "", after: "Mumla\n\n", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "", after: "Mumla\nOther", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Mumla\n", after: "Mumla\n", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello ", after: "Different Mumla\n", selectedRange: nil))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "Hello ", after: "Hello Mumla\n", selectedRange: NSRange(location: 0, length: 2)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: "", after: "Mumla\n", selectedRange: NSRange(location: 1, length: 0)))
        XCTAssertFalse(ClipboardTextInserter.verifiesInsertion("Mumla", before: nil, after: "Mumla\n", selectedRange: nil))
    }
}
