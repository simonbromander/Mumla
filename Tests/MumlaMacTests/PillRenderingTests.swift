import AppKit
import MumlaAudio
import MumlaCore
import XCTest
@testable import MumlaMac

@MainActor
final class PillRenderingTests: XCTestCase {
    func testPanelUsesTransparentRoundedHostingWithoutTakingFocus() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = PillWindowController(coordinator: makeCoordinator(directory: directory))
        defer { controller.window.close() }
        let panel = controller.window
        let view = try XCTUnwrap(panel.contentView)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertFalse(view.isOpaque)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertTrue(panel.hasShadow)
        XCTAssertTrue(try XCTUnwrap(view.layer).masksToBounds)
        XCTAssertEqual(view.layer?.cornerRadius, PillView.cornerRadius)
        XCTAssertEqual(view.layer?.cornerCurve, .continuous)
    }

    func testRecordingAndTranscriptCornersDoNotRenderSquareBottomEdges() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory)
        let states: [PillState] = [
            .listening(elapsedSeconds: 17),
            .transcript(DictationRecord(text: "Funkar det här nu då?", language: .swedish), copied: false),
            .transcript(DictationRecord(text: String(repeating: "En längre anteckning. ", count: 100), language: .swedish), copied: true)
        ]
        for state in states {
            coordinator.pillState = state
            let controller = PillWindowController(coordinator: coordinator)
            defer { controller.window.close() }
            let size = NSSize(width: PillView.width, height: PillView.height(for: state))
            controller.window.setContentSize(size)
            let view = try XCTUnwrap(controller.window.contentView)
            view.frame = NSRect(origin: .zero, size: size)
            view.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            XCTAssertTrue(bitmap.hasAlpha)
            for x in [1, bitmap.pixelsWide - 2] {
                for y in [1, bitmap.pixelsHigh - 2] {
                    XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent, 0.02,
                                      "The pill's corners must remain transparent in \(state)")
                }
            }
            XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)).alphaComponent, 0.98)
            XCTAssertEqual(view.bounds.size, size)
        }
    }

    private func makeCoordinator(directory: URL) -> AppCoordinator {
        AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
                       historyStore: DictationHistoryStore(directory: directory),
                       dictionaryStore: DictionaryStore(directory: directory),
                       settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil)
    }
}
