import AppKit
import ApplicationServices
import XCTest
@testable import MumlaMac

@MainActor
final class AutoPasteTests: XCTestCase {
    func testEditorsDoNotNeedAccessibilitySettersToAcceptPaste() {
        XCTAssertTrue(FocusedTextTargetInspector.acceptsPaste(role: "AXTextArea", enabled: true, editable: nil))
        XCTAssertTrue(FocusedTextTargetInspector.acceptsPaste(role: "AXTextField", enabled: nil, editable: nil))
        XCTAssertFalse(FocusedTextTargetInspector.acceptsPaste(role: "AXTextArea", enabled: true, editable: false))
        XCTAssertFalse(FocusedTextTargetInspector.acceptsPaste(role: "AXTextField", enabled: false, editable: true))
        XCTAssertFalse(FocusedTextTargetInspector.acceptsPaste(role: "AXStaticText", enabled: true, editable: nil))
        XCTAssertFalse(FocusedTextTargetInspector.acceptsPaste(role: "AXSecureTextField", enabled: true, editable: true))
    }

    func testSlowEditorIsConfirmedWithoutPostingTwiceAndClipboardIsRestored() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.applyOnRead = 7
        let result = await inserter(system, board).insert("Hej Mumla", target: target)
        guard case .inserted = result else { return XCTFail("A delayed paste should be confirmed") }
        XCTAssertEqual(system.value, "Hej Mumla")
        XCTAssertEqual(system.postCount, 1)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    func testFailedPasteReturnsManualCopyAndRestoresClipboard() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.applyOnRead = nil
        let result = await inserter(system, board).insert("Hej Mumla", target: target)
        assertManualCopy(result)
        XCTAssertEqual(system.postCount, 1)
        XCTAssertEqual(system.value, "")
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    func testFailureToPostRestoresClipboard() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.postSucceeds = false
        assertManualCopy(await inserter(system, board).insert("Hej Mumla", target: target))
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    func testNewUserClipboardIsPreservedWhilePasteIsConfirmed() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.onPost = { board.clearContents(); board.setString("New user copy", forType: .string) }
        let result = await inserter(system, board).insert("Hej Mumla", target: target)
        guard case .inserted = result else { return XCTFail("Expected confirmed insertion") }
        XCTAssertEqual(board.string(forType: .string), "New user copy")
    }

    func testMissingTargetAndPermissionNeverPostOrReplaceClipboard() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        assertManualCopy(await inserter(system, board).insert("Hej Mumla", target: nil))
        system.canPostEvents = false
        assertManualCopy(await inserter(system, board).insert("Hej Mumla", target: target))
        XCTAssertEqual(system.postCount, 0)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    func testSecureInputNeverPostsOrReadsText() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.isSecureInput = true
        let result = await inserter(system, board).insert("Hej Mumla", target: target)
        guard case .blockedSecureField = result else { return XCTFail("Expected secure-field block") }
        XCTAssertEqual(system.postCount, 0)
        XCTAssertEqual(system.readCount, 0)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    func testFocusChangeDuringPasteNeverRetriesInAnotherField() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.onPost = { system.focused = false }
        assertManualCopy(await inserter(system, board).insert("Hej Mumla", target: target))
        XCTAssertEqual(system.postCount, 1)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    private var target: FocusedTextTargetSnapshot {
        FocusedTextTargetSnapshot(element: AXUIElementCreateApplication(getpid()), processID: getpid())
    }

    private func inserter(_ system: PasteSystem, _ board: NSPasteboard) -> ClipboardTextInserter {
        ClipboardTextInserter(system: system, pasteboard: board, verificationDelays: Array(repeating: .zero, count: 16))
    }

    private func assertManualCopy(_ result: ClipboardInsertionResult, file: StaticString = #filePath, line: UInt = #line) {
        guard case .needsCopy(copied: false) = result else {
            return XCTFail("Only a failed insertion should request manual copy", file: file, line: line)
        }
    }
}

@MainActor
private final class PasteSystem: TextInsertionSystem {
    let board: NSPasteboard
    var isSecureInput = false
    var canPostEvents = true
    var focused = true
    var value = ""
    var postSucceeds = true
    var applyOnRead: Int? = 2
    var readCount = 0
    var postCount = 0
    var pendingText: String?
    var onPost: (() -> Void)?

    init(board: NSPasteboard) { self.board = board }
    func isFocused(_ target: FocusedTextTargetSnapshot) -> Bool { focused }
    func value(for target: FocusedTextTargetSnapshot) -> String? {
        readCount += 1
        if let applyOnRead, readCount >= applyOnRead, let pendingText { value = pendingText }
        return value
    }
    func selectedRange(for target: FocusedTextTargetSnapshot) -> NSRange? { NSRange(location: 0, length: 0) }
    func postPasteShortcut(to target: FocusedTextTargetSnapshot) -> Bool {
        postCount += 1
        if postSucceeds { pendingText = board.string(forType: .string) }
        onPost?()
        return postSucceeds
    }
}
