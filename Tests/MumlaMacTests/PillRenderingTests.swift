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

    func testDialogStatesKeepRoundedCornersAndReadableContents() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory)
        let states: [PillState] = [
            .preparing(progress: 0.45),
            .listening(elapsedSeconds: 17),
            .handsFree(elapsedSeconds: 87),
            .transcribing,
            .message("Microphone permission needed"),
            .transcript(DictationRecord(text: "Funkar det här nu då?", language: .swedish), copied: false),
            .transcript(DictationRecord(text: String(repeating: "En längre anteckning. ", count: 100), language: .swedish), copied: true)
        ]
        for (style, state) in DictationOverlayStyle.allCases.flatMap({ style in states.map { (style, $0) } }) {
            coordinator.settings.dictationOverlayStyle = style
            coordinator.pillState = state
            let controller = PillWindowController(coordinator: coordinator)
            defer { controller.window.close() }
            let size = PillView.size(for: state, style: style)
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
            let centerAlpha = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)).alphaComponent
            // Minimal mode has a translucent chassis, not the recorder's opaque LCD well.
            XCTAssertGreaterThan(centerAlpha, size.height == 56 ? 0.88 : 0.98)
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency && !NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
                // Sample the chassis above the opaque display/text well, away from its border.
                let scale = CGFloat(bitmap.pixelsHigh) / size.height
                let chassis = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: Int(4 * scale)))
                XCTAssertGreaterThan(chassis.alphaComponent, 0.75)
                XCTAssertLessThan(chassis.alphaComponent, 0.96)
            }
            XCTAssertEqual(view.bounds.size, size)
        }
    }

    func testMinimalOverlayKeepsCopyFallbackReadableAndNeverTakesFocus() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory)
        coordinator.setDictationOverlayStyle(.minimal)
        coordinator.pillState = .listening(elapsedSeconds: 17)
        let controller = PillWindowController(coordinator: coordinator)
        defer { controller.window.close() }
        controller.show()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(controller.window.frame.size, NSSize(width: 256, height: 56))
        XCTAssertEqual(controller.window.contentView?.layer?.cornerRadius, 28)
        XCTAssertFalse(controller.window.canBecomeKey)
        XCTAssertFalse(controller.window.canBecomeMain)
        coordinator.pillState = .transcript(DictationRecord(text: "A saved transcript", language: .english), copied: false)
        controller.show()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(controller.window.frame.size, NSSize(width: 380, height: 208))
        XCTAssertEqual(controller.window.contentView?.layer?.cornerRadius, PillView.cornerRadius)
    }

    private func makeCoordinator(directory: URL) -> AppCoordinator {
        AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
                       historyStore: DictationHistoryStore(directory: directory),
                       dictionaryStore: DictionaryStore(directory: directory),
                       settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil)
    }
}
