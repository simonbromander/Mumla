import AppKit
import MumlaAudio
import MumlaCore
import SwiftUI
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
            let minimal = PillView.usesMinimalLayout(for: state, style: style)
            XCTAssertGreaterThan(centerAlpha, minimal ? 0.70 : 0.98)
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency && !NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
                // Sample the chassis above the opaque display/text well, away from its border.
                let scale = CGFloat(bitmap.pixelsHigh) / size.height
                let chassis = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: Int(4 * scale)))
                XCTAssertGreaterThan(chassis.alphaComponent, minimal ? 0.60 : 0.75)
                XCTAssertLessThan(chassis.alphaComponent, minimal ? 0.85 : 0.96)
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
        XCTAssertEqual(controller.window.frame.size, NSSize(width: 104, height: 30))
        XCTAssertEqual(controller.window.contentView?.layer?.cornerRadius, 15)
        XCTAssertTrue(controller.window.ignoresMouseEvents)
        XCTAssertFalse(controller.window.canBecomeKey)
        XCTAssertFalse(controller.window.canBecomeMain)
        coordinator.pillState = .transcript(DictationRecord(text: "A saved transcript", language: .english), copied: false)
        controller.show()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(controller.window.frame.size, NSSize(width: 380, height: 208))
        XCTAssertEqual(controller.window.contentView?.layer?.cornerRadius, PillView.cornerRadius)
        XCTAssertFalse(controller.window.ignoresMouseEvents)
    }

    func testMinimalRecordingSizeIsStableAndOtherStatesRemainReadable() {
        for state in [PillState.listening(elapsedSeconds: 0), .listening(elapsedSeconds: 599), .handsFree(elapsedSeconds: 600)] {
            XCTAssertEqual(PillView.size(for: state, style: .minimal), NSSize(width: 104, height: 30))
            XCTAssertEqual(PillView.size(for: state, style: .recorder), NSSize(width: 380, height: 92))
        }
        XCTAssertEqual(PillView.size(for: .transcribing, style: .minimal), NSSize(width: 156, height: 30))
        XCTAssertEqual(PillView.size(for: .preparing(progress: 0.45), style: .minimal), NSSize(width: 156, height: 30))
        XCTAssertEqual(PillView.size(for: .message("Microphone permission needed"), style: .minimal), NSSize(width: 256, height: 56))
    }

    func testMinimalRecordingRendersInBothAppearancesWithSystemAccessibilitySettings() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory)
        coordinator.settings.dictationOverlayStyle = .minimal
        coordinator.pillState = .handsFree(elapsedSeconds: 600)
        for scheme in [ColorScheme.light, .dark] {
            let view = NSHostingView(rootView: PillView(coordinator: coordinator).environment(\.colorScheme, scheme))
            view.frame = NSRect(x: 0, y: 0, width: 104, height: 30)
            view.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let scale = CGFloat(bitmap.pixelsHigh) / view.bounds.height
            let chassis = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: Int(4 * scale)))
            if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
                XCTAssertGreaterThan(chassis.alphaComponent, 0.98)
            } else {
                XCTAssertGreaterThan(chassis.alphaComponent, 0.60)
                XCTAssertLessThan(chassis.alphaComponent, 0.85)
            }
        }
    }

    func testSwitchingToFullRecorderRestoresMouseInteraction() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = makeCoordinator(directory: directory)
        coordinator.settings.dictationOverlayStyle = .minimal
        coordinator.pillState = .handsFree(elapsedSeconds: 17)
        let controller = PillWindowController(coordinator: coordinator)
        defer { controller.window.close() }
        controller.show()
        XCTAssertTrue(controller.window.ignoresMouseEvents)
        coordinator.settings.dictationOverlayStyle = .recorder
        controller.show()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertFalse(controller.window.ignoresMouseEvents)
        XCTAssertEqual(controller.window.frame.size, NSSize(width: 380, height: 92))
    }

    private func makeCoordinator(directory: URL) -> AppCoordinator {
        AppCoordinator(recorder: MicrophoneRecorder(), transcriber: nil,
                       historyStore: DictationHistoryStore(directory: directory),
                       dictionaryStore: DictionaryStore(directory: directory),
                       settingsStore: AppSettingsStore(directory: directory), modelDirectory: nil)
    }
}
