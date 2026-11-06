import AppKit
import ApplicationServices
import MumlaAudio
import MumlaCore
import MumlaFormatting
import XCTest
@testable import MumlaMac

@MainActor
final class DictationFormattingTests: XCTestCase {
    func testDefaultOffBypassesModelAndPastesOriginal() async throws {
        let probe = FormattingProbe(output: "Hej Anna. Vi ses imorgon.")
        let fixture = Fixture(formatter: probe.formatter)
        defer { fixture.cleanUp() }
        try await fixture.coordinator.completeDictation(fixture.original, target: fixture.target)
        let requests = await probe.requests
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(fixture.system.text, fixture.original.text)
        XCTAssertNil(fixture.coordinator.history.first?.originalText)
        XCTAssertEqual(fixture.coordinator.pillState, .hidden)
    }

    func testEnabledFormatsBeforePasteKeepsOriginalAndUsesSavedPrompt() async throws {
        let formatted = "Hej Anna. Vi ses imorgon."
        let probe = FormattingProbe(output: formatted)
        let fixture = Fixture(formatter: probe.formatter)
        defer { fixture.cleanUp() }
        fixture.coordinator.setFormatDictationBeforePasting(true)
        fixture.preferences.set("Use short paragraphs.", forKey: LocalTextPreferences.formattingKey)
        try await fixture.coordinator.completeDictation(fixture.original, target: fixture.target)
        let requests = await probe.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.stylePrompt, "Use short paragraphs.")
        XCTAssertEqual(requests.first?.language, .swedish)
        XCTAssertEqual(fixture.system.text, formatted)
        let saved = try XCTUnwrap(fixture.history.load().first)
        XCTAssertEqual(saved.text, formatted)
        XCTAssertEqual(saved.originalText, fixture.original.text)
        XCTAssertNil(saved.summary)
        XCTAssertEqual(fixture.system.postCount, 1)
        XCTAssertEqual(fixture.board.string(forType: .string), "Previous clipboard")
        XCTAssertEqual(fixture.coordinator.pillState, .hidden)
        XCTAssertFalse(fixture.coordinator.isBusyForAppUpdate)
        XCTAssertNotNil(fixture.coordinator.dictationFormattingStatus)
        fixture.coordinator.restoreOriginal(saved)
        XCTAssertEqual(fixture.coordinator.history.first?.text, fixture.original.text)
    }

    func testSavedPromptChangesAreUsedOnTheNextDictation() async throws {
        let probe = FormattingProbe(output: "Hej Anna. Vi ses imorgon.")
        let fixture = Fixture(formatter: probe.formatter)
        defer { fixture.cleanUp() }
        fixture.coordinator.setFormatDictationBeforePasting(true)
        fixture.preferences.set("First style", forKey: LocalTextPreferences.formattingKey)
        try await fixture.coordinator.completeDictation(fixture.original, target: nil)
        fixture.preferences.set("Second style", forKey: LocalTextPreferences.formattingKey)
        try await fixture.coordinator.completeDictation(DictationRecord(text: fixture.original.text, language: .swedish), target: nil)
        let requests = await probe.requests
        XCTAssertEqual(requests.map(\.stylePrompt), ["First style", "Second style"])
    }

    func testUnavailableUnsafeAndFailedModelsFallBackToSavedOriginal() async throws {
        let formatters = [
            LocalTranscriptFormatter(availability: { _ in .modelNotInstalled }, generate: { _ in XCTFail("Unavailable model ran"); return "" }),
            LocalTranscriptFormatter(availability: { _ in .available }, generate: { _ in "Completely different words." }),
            LocalTranscriptFormatter(availability: { _ in .available }, generate: { _ in throw CocoaError(.fileReadUnknown) })
        ]
        for formatter in formatters {
            let fixture = Fixture(formatter: formatter)
            defer { fixture.cleanUp() }
            fixture.coordinator.setFormatDictationBeforePasting(true)
            try await fixture.coordinator.completeDictation(fixture.original, target: fixture.target)
            XCTAssertEqual(fixture.system.text, fixture.original.text)
            XCTAssertEqual(try fixture.history.load(), [fixture.original])
            XCTAssertNotNil(fixture.coordinator.dictationFormattingStatus)
            XCTAssertEqual(fixture.coordinator.pillState, .hidden)
        }
    }

    func testCancelDiscardsLateOutputWithoutPastingOrTouchingClipboard() async throws {
        let probe = FormattingProbe(output: "Hej Anna. Vi ses imorgon.", suspend: true)
        let fixture = Fixture(formatter: probe.formatter)
        defer { fixture.cleanUp() }
        fixture.coordinator.setFormatDictationBeforePasting(true)
        let operation = Task { try await fixture.coordinator.completeDictation(fixture.original, target: fixture.target) }
        for _ in 0..<100 {
            if await !probe.requests.isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(fixture.coordinator.isFormattingDictation)
        XCTAssertTrue(fixture.coordinator.isBusyForAppUpdate)
        XCTAssertFalse(fixture.coordinator.canPasteFromHistory)
        XCTAssertEqual(try fixture.history.load(), [fixture.original], "Save before starting generation")
        fixture.coordinator.cancelDictation()
        await probe.resume()
        try await operation.value
        XCTAssertEqual(fixture.system.postCount, 0)
        XCTAssertEqual(fixture.board.string(forType: .string), "Previous clipboard")
        XCTAssertEqual(try fixture.history.load(), [fixture.original])
        XCTAssertFalse(fixture.coordinator.isFormattingDictation)
        XCTAssertFalse(fixture.coordinator.isBusyForAppUpdate)
    }

    func testMissingTargetCopiesFormattedTextWithoutDialogInSilentMode() async throws {
        let probe = FormattingProbe(output: "Hej Anna. Vi ses imorgon.")
        let fixture = Fixture(formatter: probe.formatter)
        defer { fixture.cleanUp() }
        fixture.coordinator.setFormatDictationBeforePasting(true)
        fixture.coordinator.setShowPasteDialog(false)
        try await fixture.coordinator.completeDictation(fixture.original, target: nil)
        XCTAssertEqual(fixture.board.string(forType: .string), "Hej Anna. Vi ses imorgon.")
        XCTAssertEqual(fixture.coordinator.pillState, .hidden)
        XCTAssertEqual(fixture.system.postCount, 0)
    }

    func testHistoryRepasteDoesNotRunFormattingAgain() async throws {
        let probe = FormattingProbe(output: "Hej Anna. Vi ses imorgon.")
        let fixture = Fixture(formatter: probe.formatter)
        defer { fixture.cleanUp() }
        fixture.coordinator.setFormatDictationBeforePasting(true)
        let saved = try fixture.history.append(fixture.original)[0]
        fixture.coordinator.pasteRecord(saved, target: fixture.target)
        for _ in 0..<100 {
            if fixture.system.postCount > 0, fixture.coordinator.canPasteFromHistory { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let requests = await probe.requests
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(fixture.system.text, saved.text)
    }

    func testSettingsPersistAndFailedSaveDoesNotChangeEitherPreference() throws {
        let fixture = Fixture(formatter: LocalTranscriptFormatter(availability: { _ in .modelNotInstalled }, generate: { _ in "" }))
        defer { fixture.cleanUp() }
        fixture.coordinator.setFormatDictationBeforePasting(true)
        fixture.coordinator.setDictationOverlayStyle(.minimal)
        let saved = try AppSettingsStore(directory: fixture.directory).load()
        XCTAssertTrue(saved.formatDictationBeforePasting)
        XCTAssertEqual(saved.dictationOverlayStyle, .minimal)
        let url = fixture.directory.appendingPathComponent("settings.json")
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        fixture.coordinator.setFormatDictationBeforePasting(false)
        fixture.coordinator.setDictationOverlayStyle(.recorder)
        XCTAssertTrue(fixture.coordinator.settings.formatDictationBeforePasting)
        XCTAssertEqual(fixture.coordinator.settings.dictationOverlayStyle, .minimal)
    }

    func testHistorySaveFailureNeverGeneratesOrPastes() async throws {
        let probe = FormattingProbe(output: "Hej Anna. Vi ses imorgon.")
        let fixture = Fixture(formatter: probe.formatter)
        defer { fixture.cleanUp() }
        fixture.coordinator.setFormatDictationBeforePasting(true)
        try FileManager.default.createDirectory(at: fixture.directory.appendingPathComponent("history.json"), withIntermediateDirectories: true)
        do {
            try await fixture.coordinator.completeDictation(fixture.original, target: fixture.target)
            XCTFail("History write must fail")
        } catch { }
        let requests = await probe.requests
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(fixture.system.postCount, 0)
        XCTAssertFalse(fixture.coordinator.isBusyForAppUpdate)
    }

    func testFormattingSaveFailurePastesTheAlreadySavedOriginal() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let formatter = LocalTranscriptFormatter(availability: { _ in .available }, generate: { _ in
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
            return "Hej Anna. Vi ses imorgon."
        })
        let fixture = Fixture(formatter: formatter, directory: directory)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            fixture.cleanUp()
        }
        fixture.coordinator.setFormatDictationBeforePasting(true)
        try await fixture.coordinator.completeDictation(fixture.original, target: fixture.target)
        XCTAssertEqual(fixture.system.text, fixture.original.text)
        XCTAssertEqual(try fixture.history.load(), [fixture.original])
        XCTAssertFalse(fixture.coordinator.isBusyForAppUpdate)
    }

    func testFocusChangeDuringFormattingDoesNotPasteIntoAnotherField() async throws {
        let probe = FormattingProbe(output: "Hej Anna. Vi ses imorgon.", suspend: true)
        let fixture = Fixture(formatter: probe.formatter)
        defer { fixture.cleanUp() }
        fixture.coordinator.setFormatDictationBeforePasting(true)
        let operation = Task { try await fixture.coordinator.completeDictation(fixture.original, target: fixture.target) }
        for _ in 0..<100 {
            if await !probe.requests.isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        fixture.system.focused = false
        await probe.resume()
        try await operation.value
        XCTAssertEqual(fixture.system.postCount, 0)
        XCTAssertEqual(fixture.board.string(forType: .string), "Previous clipboard")
        guard case let .transcript(record, copied) = fixture.coordinator.pillState else { return XCTFail("Offer the saved formatted text") }
        XCTAssertEqual(record.text, "Hej Anna. Vi ses imorgon.")
        XCTAssertFalse(copied)
    }
}

private actor FormattingProbe {
    let output: String
    let suspend: Bool
    var requests: [LocalTextGenerationRequest] = []
    private var continuation: CheckedContinuation<String, Never>?
    init(output: String, suspend: Bool = false) { self.output = output; self.suspend = suspend }
    nonisolated var formatter: LocalTranscriptFormatter {
        LocalTranscriptFormatter(availability: { _ in .available }, generate: { await self.generate($0) })
    }
    func generate(_ request: LocalTextGenerationRequest) async -> String {
        requests.append(request)
        if suspend { return await withCheckedContinuation { continuation = $0 } }
        return output
    }
    func resume() { continuation?.resume(returning: output); continuation = nil }
}

@MainActor
private final class Fixture {
    let directory: URL
    let board = NSPasteboard.withUniqueName()
    let suite = "MumlaDictationFormattingTests.\(UUID().uuidString)"
    let preferences: UserDefaults
    let coordinator: AppCoordinator
    let history: DictationHistoryStore
    let system: FormattingPasteSystem
    let original = DictationRecord(text: "hej Anna vi ses imorgon", language: .swedish)
    let target = FocusedTextTargetSnapshot(element: AXUIElementCreateApplication(getpid()), processID: getpid())

    init(formatter: LocalTranscriptFormatter, directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)) {
        self.directory = directory
        preferences = UserDefaults(suiteName: suite)!
        history = DictationHistoryStore(directory: directory)
        board.setString("Previous clipboard", forType: .string)
        system = FormattingPasteSystem(board: board)
        let inserter = ClipboardTextInserter(system: system, pasteboard: board, verificationDelays: [.zero], lateVerificationDelays: [])
        coordinator = AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil, historyStore: history,
            dictionaryStore: DictionaryStore(directory: directory), settingsStore: AppSettingsStore(directory: directory),
            modelDirectory: nil, pasteboard: board, inserter: inserter,
            textModel: QwenTextModel(directory: directory.appendingPathComponent("model")),
            dictationFormatter: formatter, textPreferences: preferences)
    }
    func cleanUp() {
        coordinator.dismissPill()
        board.releaseGlobally()
        preferences.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
private final class FormattingPasteSystem: TextInsertionSystem {
    let board: NSPasteboard
    var isSecureInput = false
    var canPostEvents = true
    var areModifiersReleased = true
    var text = ""
    var focused = true
    var postCount = 0
    init(board: NSPasteboard) { self.board = board }
    func isFocused(_ target: FocusedTextTargetSnapshot) -> Bool { focused }
    func value(for target: FocusedTextTargetSnapshot) -> String? { text }
    func selectedRange(for target: FocusedTextTargetSnapshot) -> NSRange? { NSRange(location: 0, length: text.utf16.count) }
    func postPasteShortcut(to target: FocusedTextTargetSnapshot) -> Bool {
        postCount += 1
        text = board.string(forType: .string) ?? ""
        return true
    }
}
