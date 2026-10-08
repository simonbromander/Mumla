import AppKit
import ApplicationServices
import MumlaAudio
import MumlaCore
import XCTest
@testable import MumlaMac

@MainActor
final class TranscriptMenuTests: XCTestCase {
    func testLastTranscriptAndTenRecentItemsUpdateAfterPublishedHistoryChanges() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(status); board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = coordinator(directory, board: board)
        let controller = StatusMenuController(coordinator: coordinator, updater: MacUpdateController(), statusItem: status)
        let last = try XCTUnwrap(status.menu?.items.first { $0.identifier?.rawValue == "history.pasteLast" })
        XCTAssertFalse(last.isEnabled)
        let records = (0..<12).map { DictationRecord(text: "Transcript \($0)\nnext line", language: .english) }
        coordinator.history = records
        try await Task.sleep(for: .milliseconds(50))
        let updated = try XCTUnwrap(status.menu)
        XCTAssertTrue(try XCTUnwrap(updated.items.first { $0.identifier?.rawValue == "history.pasteLast" }).isEnabled)
        let recent = try XCTUnwrap(updated.items.first { $0.identifier?.rawValue == "history.recent" }?.submenu)
        XCTAssertEqual(recent.items.count, 10)
        XCTAssertEqual(recent.items.first?.representedObject as? String, records.first?.id.uuidString)
        XCTAssertEqual(recent.items.first?.title, "Transcript 0 next line")
        XCTAssertEqual(recent.items.last?.representedObject as? String, records[9].id.uuidString)
        coordinator.setAppUpdateInstallationInProgress(true)
        coordinator.statusText = "Updating"
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(try XCTUnwrap(status.menu?.items.first { $0.identifier?.rawValue == "history.pasteLast" }).isEnabled)
        XCTAssertTrue(status.menu?.items.first { $0.identifier?.rawValue == "history.recent" }?.submenu?.items.allSatisfy { !$0.isEnabled } == true)
        withExtendedLifetime(controller) {}
    }

    func testMenuPasteKeepsCapturedTargetAndHidesPillOnSuccess() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(status); board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        board.setString("Previous clipboard", forType: .string)
        let system = MenuPasteSystem(board: board)
        let service = ClipboardTextInserter(system: system, pasteboard: board, verificationDelays: [.zero])
        let coordinator = coordinator(directory, board: board, inserter: service)
        let record = DictationRecord(text: "Hej Mumla", language: .swedish)
        let older = DictationRecord(text: "An older transcript", language: .english)
        coordinator.history = [record, older]
        var hideCount = 0
        coordinator.hidePill = { hideCount += 1 }
        let target = FocusedTextTargetSnapshot(element: AXUIElementCreateApplication(getpid()), processID: getpid())
        var captureCount = 0
        let controller = StatusMenuController(coordinator: coordinator, updater: MacUpdateController(), statusItem: status, captureTarget: {
            captureCount += 1
            return target
        })
        let menu = try XCTUnwrap(status.menu)
        controller.menuWillOpen(menu)
        let lastIndex = try XCTUnwrap(menu.items.firstIndex { $0.identifier?.rawValue == "history.pasteLast" })
        menu.performActionForItem(at: lastIndex)
        for _ in 0..<100 {
            if hideCount > 0 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(captureCount, 1)
        XCTAssertEqual(system.postCount, 1)
        XCTAssertTrue(system.pastedTarget.map { CFEqual($0.element, target.element) && $0.processID == target.processID } == true)
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(hideCount, 1)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
        let recent = try XCTUnwrap(status.menu?.items.first { $0.identifier?.rawValue == "history.recent" }?.submenu)
        controller.menuWillOpen(try XCTUnwrap(status.menu))
        recent.performActionForItem(at: 1)
        for _ in 0..<100 {
            if hideCount == 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(captureCount, 2)
        XCTAssertEqual(system.postCount, 2)
        XCTAssertEqual(system.value(for: target), older.text)
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(hideCount, 2)
        XCTAssertEqual(board.string(forType: .string), "Previous clipboard")
    }

    func testDelayedConfirmationDismissesFallbackAfterSuccess() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let system = MenuPasteSystem(board: board)
        system.exposePastedValue = false
        let service = ClipboardTextInserter(system: system, pasteboard: board, verificationDelays: [.zero],
                                           lateVerificationDelays: [.milliseconds(20), .milliseconds(20)])
        let coordinator = coordinator(directory, board: board, inserter: service)
        let record = DictationRecord(text: "Hej Mumla", language: .swedish)
        let target = FocusedTextTargetSnapshot(element: AXUIElementCreateApplication(getpid()), processID: getpid())
        let result = await service.insert(record.text, target: target)
        coordinator.presentInsertion(result, record: record)
        XCTAssertEqual(coordinator.pillState, .transcript(record, copied: false))
        system.exposePastedValue = true
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(system.postCount, 1)
    }

    func testDismissedFallbackCannotReopenOrHideANewerPanel() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let system = MenuPasteSystem(board: board)
        system.exposePastedValue = false
        let service = ClipboardTextInserter(system: system, pasteboard: board, verificationDelays: [.zero],
                                           lateVerificationDelays: [.milliseconds(20), .milliseconds(20)])
        let coordinator = coordinator(directory, board: board, inserter: service)
        let record = DictationRecord(text: "Hej Mumla", language: .swedish)
        let target = FocusedTextTargetSnapshot(element: AXUIElementCreateApplication(getpid()), processID: getpid())
        coordinator.presentInsertion(await service.insert(record.text, target: target), record: record)
        coordinator.dismissPill()
        coordinator.pillState = .message("New panel")
        system.exposePastedValue = true
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(coordinator.pillState, .message("New panel"))
        XCTAssertEqual(system.postCount, 1)
    }

    private func coordinator(_ directory: URL, board: NSPasteboard, inserter: ClipboardTextInserter? = nil) -> AppCoordinator {
        AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
                       historyStore: DictationHistoryStore(directory: directory), dictionaryStore: DictionaryStore(directory: directory),
                       settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil, pasteboard: board, inserter: inserter)
    }
}

@MainActor
private final class MenuPasteSystem: TextInsertionSystem {
    let board: NSPasteboard
    var isSecureInput = false
    var canPostEvents = true
    var areModifiersReleased = true
    var exposePastedValue = true
    var postCount = 0
    var pastedTarget: FocusedTextTargetSnapshot?
    private var pastedText = ""
    init(board: NSPasteboard) { self.board = board }
    func isFocused(_ target: FocusedTextTargetSnapshot) -> Bool { true }
    func value(for target: FocusedTextTargetSnapshot) -> String? { exposePastedValue ? pastedText : "" }
    func selectedRange(for target: FocusedTextTargetSnapshot) -> NSRange? { NSRange(location: 0, length: (pastedText as NSString).length) }
    func postPasteShortcut(to target: FocusedTextTargetSnapshot) -> Bool {
        postCount += 1
        pastedTarget = target
        pastedText = board.string(forType: .string) ?? ""
        return true
    }
}
