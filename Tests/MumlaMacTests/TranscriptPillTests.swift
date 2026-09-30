import AppKit
import MumlaAudio
import MumlaCore
import XCTest
@testable import MumlaMac

final class TranscriptPillTests: XCTestCase {
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
    private func makeCoordinator(directory: URL, pasteboard: NSPasteboard) -> AppCoordinator {
        AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
                       historyStore: DictationHistoryStore(directory: directory),
                       dictionaryStore: DictionaryStore(directory: directory),
                       settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil, pasteboard: pasteboard)
    }
}
