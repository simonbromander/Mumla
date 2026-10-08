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
        XCTAssertTrue(FocusedTextTargetInspector.acceptsPaste(role: "AXGroup", enabled: true, editable: true))
        XCTAssertTrue(FocusedTextTargetInspector.acceptsPaste(role: "AXWebArea", enabled: true, editable: true))
        XCTAssertFalse(FocusedTextTargetInspector.acceptsPaste(role: "AXGroup", enabled: true, editable: nil))
        XCTAssertFalse(FocusedTextTargetInspector.acceptsPaste(role: "AXWebArea", enabled: true, editable: false))
        XCTAssertFalse(FocusedTextTargetInspector.acceptsPaste(role: "AXButton", enabled: true, editable: true))
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

    func testDelayedAccessibilityAcknowledgementConfirmsWithoutAnotherPasteOrClipboardWrite() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.applyOnRead = 20
        let service = inserter(system, board)
        assertManualCopy(await service.insert("Hej Mumla", target: target))
        XCTAssertEqual(service.lastOutcome, .unconfirmed)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
        let restoredCount = board.changeCount
        let confirmed = await service.confirmPendingInsertion("Hej Mumla")
        XCTAssertTrue(confirmed)
        XCTAssertEqual(service.lastOutcome, .confirmed)
        XCTAssertEqual(system.postCount, 1)
        XCTAssertEqual(board.changeCount, restoredCount)
    }

    func testLateVerificationStopsOnFocusChangeOrSecureInput() async {
        for secure in [false, true] {
            let board = NSPasteboard.withUniqueName()
            defer { board.releaseGlobally() }
            board.setString("Previous clipboard", forType: .string)
            let system = PasteSystem(board: board)
            system.applyOnRead = 20
            let service = inserter(system, board)
            assertManualCopy(await service.insert("Hej Mumla", target: target))
            let reads = system.readCount
            if secure { system.isSecureInput = true } else { system.focused = false }
            let confirmed = await service.confirmPendingInsertion("Hej Mumla")
            XCTAssertFalse(confirmed)
            XCTAssertEqual(system.readCount, reads)
            XCTAssertEqual(system.postCount, 1)
            XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
        }
    }

    func testUnreadableAndFailedPasteNeverAcquireLateConfirmation() async {
        for readable in [false, true] {
            let board = NSPasteboard.withUniqueName()
            defer { board.releaseGlobally() }
            let system = PasteSystem(board: board)
            system.valueReadable = readable
            system.applyOnRead = nil
            let service = inserter(system, board)
            assertManualCopy(await service.insert("Hej Mumla", target: target))
            let confirmed = await service.confirmPendingInsertion("Hej Mumla")
            XCTAssertFalse(confirmed)
            XCTAssertEqual(system.postCount, 1)
        }
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

    func testNewUserCopyBeforeDispatchCancelsPasteAndPreservesTheCopy() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.onModifierCheck = {
            if board.string(forType: .string) == "Hej Mumla" {
                board.clearContents()
                board.setString("New user copy", forType: .string)
            }
        }
        let service = inserter(system, board)
        assertManualCopy(await service.insert("Hej Mumla", target: target))
        XCTAssertEqual(service.lastOutcome, .clipboardChanged)
        XCTAssertEqual(system.postCount, 0)
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

    func testWaitsForModifierReleaseBeforeReadingOrWritingTheClipboard() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.modifiersHeld = true
        let initialCount = board.changeCount
        system.onModifierCheck = {
            if system.modifierChecks <= 3 {
                XCTAssertEqual(board.changeCount, initialCount)
                XCTAssertEqual(system.readCount, 0)
            }
            if system.modifierChecks == 3 { system.modifiersHeld = false }
        }
        let service = inserter(system, board)
        guard case .inserted = await service.insert("Hej Mumla", target: target) else { return XCTFail("Expected one confirmed paste after release") }
        XCTAssertEqual(service.lastOutcome, .confirmed)
        XCTAssertEqual(system.postCount, 1)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    func testHeldModifiersNeverReadTextOrStageAPaste() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let initialCount = board.changeCount
        let system = PasteSystem(board: board)
        system.modifiersHeld = true
        let service = inserter(system, board)
        assertManualCopy(await service.insert("Hej Mumla", target: target))
        XCTAssertEqual(service.lastOutcome, .modifiersHeld)
        XCTAssertEqual(system.postCount, 0)
        XCTAssertEqual(system.readCount, 0)
        XCTAssertEqual(board.changeCount, initialCount)
    }

    func testFocusChangeWhileWaitingForModifiersNeverPostsOrTouchesClipboard() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let initialCount = board.changeCount
        let system = PasteSystem(board: board)
        system.modifiersHeld = true
        system.onModifierCheck = { system.focused = false }
        let service = inserter(system, board)
        assertManualCopy(await service.insert("Hej Mumla", target: target))
        XCTAssertEqual(service.lastOutcome, .targetChanged)
        XCTAssertEqual(system.postCount, 0)
        XCTAssertEqual(system.readCount, 0)
        XCTAssertEqual(board.changeCount, initialCount)
    }

    func testSecureInputActivatedWhileWaitingNeverReadsOrWrites() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let initialCount = board.changeCount
        let system = PasteSystem(board: board)
        system.modifiersHeld = true
        system.onModifierCheck = { system.isSecureInput = true }
        let service = inserter(system, board)
        guard case .blockedSecureField = await service.insert("Hej Mumla", target: target) else { return XCTFail("Expected a secure-input block") }
        XCTAssertEqual(service.lastOutcome, .secureInput)
        XCTAssertEqual(system.postCount, 0)
        XCTAssertEqual(system.readCount, 0)
        XCTAssertEqual(board.changeCount, initialCount)
    }

    func testFocusChangeDuringInitialReadDoesNotStageClipboard() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let initialCount = board.changeCount
        let system = PasteSystem(board: board)
        system.onRead = { system.focused = false }
        let service = inserter(system, board)
        assertManualCopy(await service.insert("Hej Mumla", target: target))
        XCTAssertEqual(service.lastOutcome, .targetChanged)
        XCTAssertEqual(system.postCount, 0)
        XCTAssertEqual(board.changeCount, initialCount)
    }

    func testAnUnreadableTargetIsNotDeclaredSuccessfulFromAPostedEvent() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.valueReadable = false
        let service = inserter(system, board)
        assertManualCopy(await service.insert("Hej Mumla", target: target))
        XCTAssertEqual(service.lastOutcome, .textUnavailable)
        XCTAssertEqual(system.postCount, 1)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    func testEmptyTextCannotEraseTheSelection() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let initialCount = board.changeCount
        let system = PasteSystem(board: board)
        let service = inserter(system, board)
        assertManualCopy(await service.insert("", target: target))
        XCTAssertEqual(service.lastOutcome, .emptyText)
        XCTAssertEqual(system.postCount, 0)
        XCTAssertEqual(system.readCount, 0)
        XCTAssertEqual(board.changeCount, initialCount)
    }

    func testCancelledOperationCannotPostOrStageClipboard() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let initialCount = board.changeCount
        let system = PasteSystem(board: board)
        let service = inserter(system, board)
        let target = target
        let task = Task { await service.insert("Hej Mumla", target: target) }
        task.cancel()
        assertManualCopy(await task.value)
        XCTAssertEqual(service.lastOutcome, .cancelled)
        XCTAssertEqual(system.postCount, 0)
        XCTAssertEqual(system.readCount, 0)
        XCTAssertEqual(board.changeCount, initialCount)
    }

    func testCancellationAfterPostingRestoresClipboardWithoutRetrying() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let system = PasteSystem(board: board)
        system.onPost = { withUnsafeCurrentTask { $0?.cancel() } }
        let service = inserter(system, board)
        let target = target
        let task = Task { await service.insert("Hej Mumla", target: target) }
        assertManualCopy(await task.value)
        XCTAssertEqual(service.lastOutcome, .cancelled)
        XCTAssertEqual(system.postCount, 1)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    private var target: FocusedTextTargetSnapshot {
        FocusedTextTargetSnapshot(element: AXUIElementCreateApplication(getpid()), processID: getpid())
    }

    private func inserter(_ system: PasteSystem, _ board: NSPasteboard) -> ClipboardTextInserter {
        ClipboardTextInserter(system: system, pasteboard: board, verificationDelays: Array(repeating: .zero, count: 16),
                             modifierReleaseDelays: Array(repeating: .zero, count: 4),
                             lateVerificationDelays: Array(repeating: .zero, count: 8))
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
    var modifiersHeld = false
    var modifierChecks = 0
    var onModifierCheck: (() -> Void)?
    var areModifiersReleased: Bool {
        modifierChecks += 1
        onModifierCheck?()
        return !modifiersHeld
    }
    var focused = true
    var value = ""
    var postSucceeds = true
    var applyOnRead: Int? = 2
    var readCount = 0
    var postCount = 0
    var pendingText: String?
    var onPost: (() -> Void)?
    var onRead: (() -> Void)?
    var valueReadable = true

    init(board: NSPasteboard) { self.board = board }
    func isFocused(_ target: FocusedTextTargetSnapshot) -> Bool { focused }
    func value(for target: FocusedTextTargetSnapshot) -> String? {
        readCount += 1
        onRead?()
        if let applyOnRead, readCount >= applyOnRead, let pendingText { value = pendingText }
        return valueReadable ? value : nil
    }
    func selectedRange(for target: FocusedTextTargetSnapshot) -> NSRange? { NSRange(location: 0, length: 0) }
    func postPasteShortcut(to target: FocusedTextTargetSnapshot) -> Bool {
        postCount += 1
        if postSucceeds { pendingText = board.string(forType: .string) }
        onPost?()
        return postSucceeds
    }
}
