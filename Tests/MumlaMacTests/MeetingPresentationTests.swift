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
}
