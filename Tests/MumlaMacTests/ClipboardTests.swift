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
    }
}
