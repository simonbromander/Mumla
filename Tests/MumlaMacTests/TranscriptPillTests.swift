import AppKit
import MumlaAudio
import MumlaCore
import XCTest
@testable import MumlaMac

final class TranscriptPillTests: XCTestCase {
    @MainActor
    func testSettingsActionRequestsSettingsInsteadOfOnlyOpeningWindow() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var opened = 0
        coordinator.showMainWindow = { opened += 1 }
        coordinator.openMainWindow()
        XCTAssertNil(coordinator.settingsOpenRequest)
        coordinator.isOnboardingVisible = true
        coordinator.openSettings()
        let request = coordinator.settingsOpenRequest
        XCTAssertNotNil(request)
        XCTAssertFalse(coordinator.isOnboardingVisible)
        coordinator.openSettings()
        XCTAssertNotEqual(request, coordinator.settingsOpenRequest)
        XCTAssertEqual(opened, 3)
    }

    @MainActor
    func testHotkeyDiagnosticsExcludeTranscriptAndDictionaryText() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        coordinator.history = [DictationRecord(text: "private transcript", language: .swedish)]
        coordinator.hotkeyGestureStage = .holdStarted
        coordinator.copyHotkeyDiagnostics()
        let copied = board.string(forType: .string) ?? ""
        XCTAssertTrue(copied.contains("Gesture: holdStarted"))
        XCTAssertTrue(copied.contains("Input Monitoring:"))
        XCTAssertTrue(copied.contains("Paste: notAttempted"))
        XCTAssertFalse(copied.contains("private transcript"))
        XCTAssertFalse(copied.contains(directory.path))
    }

    @MainActor
    func testSuccessfulInsertionHidesPillWithoutPresentingCopyDialog() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var presentations = 0
        var dismissals = 0
        coordinator.showPill = { presentations += 1 }
        coordinator.hidePill = { dismissals += 1 }
        coordinator.pillState = .transcribing
        coordinator.presentInsertion(.inserted, record: DictationRecord(text: "Hej Mumla", language: .swedish))
        XCTAssertEqual(coordinator.pillState, .hidden)
        XCTAssertEqual(presentations, 0)
        XCTAssertEqual(dismissals, 1)
    }

    @MainActor
    func testFallbackPersistsPastOldHideDeadlineAndCopiesEntireTranscript() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        let record = DictationRecord(text: String(repeating: "A full transcript. ", count: 100), language: .english)
        coordinator.showPracticePill()
        coordinator.presentInsertion(.needsCopy(copied: false), record: record)
        try await Task.sleep(for: .milliseconds(1600))
        XCTAssertEqual(coordinator.pillState, .transcript(record, copied: false))
        coordinator.copyPillTranscript()
        XCTAssertEqual(board.string(forType: .string), record.text)
        XCTAssertEqual(coordinator.pillState, .transcript(record, copied: true))
        coordinator.dismissPill()
        XCTAssertEqual(coordinator.pillState, .hidden)
    }

    @MainActor
    func testSecureFallbackDoesNotAutoCopyAndEscapeDismisses() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        board.setString("Existing clipboard", forType: .string)
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        let record = DictationRecord(text: "My dictation", language: .english)
        coordinator.presentInsertion(.blockedSecureField, record: record)
        XCTAssertEqual(board.string(forType: .string), "Existing clipboard")
        XCTAssertEqual(coordinator.pillState, .transcript(record, copied: false))
        coordinator.cancelDictation()
        XCTAssertEqual(coordinator.pillState, .hidden)
    }

    @MainActor
    func testTriggerSelectionPersistsAndNotifiesMonitor() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var updated: DictationTriggerKey?
        coordinator.triggerKeyChanged = { updated = $0 }
        coordinator.setTriggerKey(.function)
        XCTAssertEqual(updated, .function)
        XCTAssertEqual(try AppSettingsStore(directory: directory).load().triggerKey, .function)
    }

    @MainActor
    func testHotkeyPermissionActionReachesMonitorWithoutChangingTriggerSetting() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        var requests = 0
        coordinator.requestHotkeyAccess = { requests += 1 }
        coordinator.requestHotkeyPermission()
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(coordinator.settings.triggerKey, .control)
    }

    @MainActor
    func testHotkeyFailureIsVisibleWithoutOverwritingRecordingStatus() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory, pasteboard: board)
        coordinator.statusText = "Downloading model"
        coordinator.updateHotkeyStatus(.inputMonitoringRequired)
        XCTAssertEqual(coordinator.hotkeyMonitorStatus, .inputMonitoringRequired)
        XCTAssertFalse(coordinator.hotkeyStatusText.isEmpty)
        XCTAssertEqual(coordinator.statusText, "Downloading model")
        coordinator.updateHotkeyStatus(.active)
        XCTAssertTrue(coordinator.hotkeyStatusText.contains("Ctrl"))
    }

    @MainActor
    private func makeCoordinator(directory: URL, pasteboard: NSPasteboard) -> AppCoordinator {
        AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
                       historyStore: DictationHistoryStore(directory: directory),
                       dictionaryStore: DictionaryStore(directory: directory),
                       settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil, pasteboard: pasteboard)
    }
}
