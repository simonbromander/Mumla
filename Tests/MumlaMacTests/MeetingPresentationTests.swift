import AppKit
import MumlaAudio
import MumlaCore
import SwiftUI
import XCTest
@testable import MumlaMac

@MainActor
final class MeetingPresentationTests: XCTestCase {
    func testCompactLayoutPreservesAtLeastFourHundredPointsForTheDocument() {
        XCTAssertFalse(MeetingsView.showsLibrary(at: 542))
        XCTAssertFalse(MeetingsView.showsLibrary(at: 682))
        XCTAssertTrue(MeetingsView.showsLibrary(at: 720))
        XCTAssertTrue(MeetingsView.showsLibrary(at: 1002))
    }

    func testCorrectionRequiresNonemptyTextAndRespectsStoreLimits() {
        XCTAssertTrue(MeetingCorrectionSheet.canSave(text: "A correction.", speaker: "Name"))
        XCTAssertFalse(MeetingCorrectionSheet.canSave(text: " \n", speaker: "Name"))
        XCTAssertFalse(MeetingCorrectionSheet.canSave(text: String(repeating: "a", count: 20_001), speaker: "Name"))
        XCTAssertFalse(MeetingCorrectionSheet.canSave(text: "Text", speaker: String(repeating: "a", count: 101)))
    }

    func testCorrectionStalePreviewDoesNotOverwriteAndAudioDeletionKeepsText() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = MeetingCoordinator(directory: directory, modelDirectory: { nil })
        let record = try MeetingDesignFixtures.seed(model)
        let segment = record.segments[0]
        try model.applyCorrection(segment, text: "Corrected.", speakerName: "Correct name", meetingID: record.id)
        XCTAssertThrowsError(try model.applyCorrection(segment, text: "Stale.", speakerName: "Other", meetingID: record.id))
        model.deleteAudio(record.id)
        let saved = try model.store.load(record.id)
        XCTAssertTrue(saved.audioDeleted); XCTAssertEqual(saved.segments[0].text, "Corrected.")
        XCTAssertEqual(saved.speakerName(segment.speaker), "Correct name")
    }

    func testSpeakerAssignmentChangesOnlyOnePassageAndRetainsItsOriginalIdentity() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = MeetingCoordinator(directory: directory, modelDirectory: { nil })
        let seeded = try MeetingDesignFixtures.seed(model)
        let record = try model.store.update(seeded.id) {
            $0.segments[1].words = [.init(text: "Bra.", start: 21, end: 21.5)]
            $0.speakerNames.removeValue(forKey: "system-0")
            $0.segments.append(.init(id: "other-remote", chunkID: "example", track: .system,
                start: 40, end: 42, speaker: "system-1", text: "Another person."))
        }
        let passage = record.segments[1]
        try model.reassignSpeaker(passage, to: "system-1", meetingID: record.id)
        var expected = record
        expected.segments[1].speaker = "system-1"
        expected.speakerNames["system-0"] = ""
        let saved = try model.store.load(record.id)
        XCTAssertEqual(saved, expected)
        XCTAssertTrue(saved.speakerKeys(for: .system).contains("system-0"))
        XCTAssertFalse(saved.speakerKeys(for: .system).contains("microphone"))
        try model.reassignSpeaker(saved.segments[1], to: "system-0", meetingID: record.id)
        XCTAssertEqual(try model.store.load(record.id).segments, record.segments)
    }

    func testSpeakerAssignmentRejectsUnknownOrCrossTrackTargetsAndStalePreviews() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = MeetingCoordinator(directory: directory, modelDirectory: { nil })
        let record = try MeetingDesignFixtures.seed(model)
        let passage = record.segments[1]
        for target in ["system-99", "microphone"] {
            XCTAssertThrowsError(try model.reassignSpeaker(passage, to: target, meetingID: record.id))
            XCTAssertEqual(try model.store.load(record.id), record)
        }
        try model.reassignSpeaker(passage, to: "system", meetingID: record.id)
        XCTAssertThrowsError(try model.reassignSpeaker(passage, to: "system-0", meetingID: record.id))
        let current = try model.store.load(record.id)
        XCTAssertEqual(current.speakerName("system-0"), "Anna")
        try model.applyCorrection(current.segments[1], text: "A new correction.", speakerName: "", meetingID: record.id)
        XCTAssertThrowsError(try model.reassignSpeaker(current.segments[1], to: "system-0", meetingID: record.id))
        XCTAssertEqual(try model.store.load(record.id).segments[1].text, "A new correction.")
    }

    func testBrandedPanelsRenderAtTheirDeclaredSizesInBothAppearances() throws {
        _ = NSApplication.shared
        let segment = MeetingSegment(id: "fixture", chunkID: "fixture", track: .microphone, start: 0, end: 1, speaker: "microphone", text: String(repeating: "A long editable transcript. ", count: 40))
        let record = MeetingRecord(title: String(repeating: "A long meeting title ", count: 9), sourceName: "Synthetic", microphoneOnly: true)
        let panels: [(AnyView, NSSize)] = [
            (AnyView(MeetingCorrectionSheet(segment: segment, speaker: "A long speaker name", save: { _, _ in })), NSSize(width: 520, height: 480)),
            (AnyView(MeetingDeletionSheet(meeting: record, audioOnly: false, delete: { nil })), NSSize(width: 520, height: 400)),
            (AnyView(MeetingDeletionSheet(meeting: record, audioOnly: true, delete: { "A recoverable error." })), NSSize(width: 520, height: 400)),
            (AnyView(MeetingExitSheet(reason: .recording, confirm: {}, cancel: {})), NSSize(width: 520, height: 340)),
            (AnyView(MeetingExitSheet(reason: .transcribing, confirm: {}, cancel: {})), NSSize(width: 520, height: 340))]
        for scheme in [ColorScheme.light, .dark] {
            for (panel, size) in panels {
                let view = NSHostingView(rootView: panel.environment(\.colorScheme, scheme))
                view.frame = NSRect(origin: .zero, size: size); view.layoutSubtreeIfNeeded()
                XCTAssertLessThanOrEqual(view.fittingSize.width, size.width)
                XCTAssertLessThanOrEqual(view.fittingSize.height, size.height)
                let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                XCTAssertGreaterThan(bitmap.pixelsWide, 0); XCTAssertGreaterThan(bitmap.pixelsHigh, 0)
            }
        }
    }

    func testMeetingSuggestionFitsLongTitlesInBothAppearances() {
        _ = NSApplication.shared
        for scheme in [ColorScheme.light, .dark] {
            let view = NSHostingView(rootView: MeetingSuggestionView(suggestion: MeetingDesignFixtures.suggestion(long: true), start: {}, dismiss: {})
                .environment(\.colorScheme, scheme))
            let size = view.fittingSize
            XCTAssertEqual(size.width, 380)
            XCTAssertGreaterThan(size.height, 200)
            XCTAssertLessThan(size.height, 500)
            view.frame = NSRect(origin: .zero, size: size); view.layoutSubtreeIfNeeded()
            XCTAssertLessThanOrEqual(view.fittingSize.height, size.height)
        }
    }

    func testSuggestionPanelAppearsWithoutTakingKeyFocus() throws {
        _ = NSApplication.shared
        let model = MeetingDesignFixtures.detection { _, _ in XCTFail("Must not start from presentation") }
        let previous = NSApp.keyWindow
        let controller = MeetingPromptWindowController(detection: model)
        defer { controller.hide(); model.stop() }
        let window = try XCTUnwrap(NSApp.windows.first { $0.title == "Mumla - Transcribe?" && $0.isVisible })
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(window.frame.width, 380)
        XCTAssertTrue(NSApp.keyWindow === previous)
        XCTAssertTrue((window as? NSPanel)?.styleMask.contains(.nonactivatingPanel) == true)
    }
}
