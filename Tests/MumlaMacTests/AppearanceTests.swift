import AppKit
import SwiftUI
import MumlaUI
import XCTest

@MainActor
final class AppearanceTests: XCTestCase {
    func testAppearanceOptionsMapToSystemLightAndDark() {
        XCTAssertNil(MumlaAppearance.system.colorScheme)
        XCTAssertEqual(MumlaAppearance.light.colorScheme, .light)
        XCTAssertEqual(MumlaAppearance.dark.colorScheme, .dark)
        XCTAssertEqual(MumlaAppearance.allCases.map(\.id), ["system", "light", "dark"])
        XCTAssertEqual(MumlaAppearance.allCases.map(\.symbol), ["circle.lefthalf.filled", "sun.max", "moon"])
    }

    func testMissingAndUnknownPreferencesFollowSystem() throws {
        let suite = "MumlaAppearanceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(MumlaAppearance.stored(in: defaults), .system)
        defaults.set("obsolete-theme", forKey: MumlaAppearance.preferenceKey)
        XCTAssertEqual(MumlaAppearance.stored(in: defaults), .system)
    }

    func testAllModesPersistAndSystemClearsNativeOverride() throws {
        _ = NSApplication.shared
        let previous = NSApp.appearance
        let suite = "MumlaAppearanceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            NSApp.appearance = previous
        }
        for appearance in [MumlaAppearance.light, .dark, .system] {
            appearance.save(to: defaults)
            let reloaded = try XCTUnwrap(UserDefaults(suiteName: suite))
            XCTAssertEqual(MumlaAppearance.stored(in: reloaded), appearance)
            switch appearance {
            case .system: XCTAssertNil(NSApp.appearance)
            case .light: XCTAssertEqual(NSApp.appearance?.name, .aqua)
            case .dark: XCTAssertEqual(NSApp.appearance?.name, .darkAqua)
            }
        }
    }

    func testReadingColorsHaveAccessibleContrastInBothAppearances() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            appearance.performAsCurrentDrawingAppearance {
                let surfaces = [MumlaStyle.background, MumlaStyle.panel, MumlaStyle.surfaceTop, MumlaStyle.surfaceBottom]
                for surface in surfaces {
                    XCTAssertGreaterThanOrEqual(contrast(MumlaStyle.ink, surface), 4.5, "\(name): primary text")
                    XCTAssertGreaterThanOrEqual(contrast(MumlaStyle.secondary, surface), 4.5, "\(name): secondary text")
                    XCTAssertGreaterThanOrEqual(contrast(MumlaStyle.accent, surface), 4.5, "\(name): accent text")
                }
                XCTAssertGreaterThanOrEqual(contrast(MumlaStyle.lcdInk, MumlaStyle.lcd), 4.5)
                XCTAssertGreaterThanOrEqual(contrast(MumlaStyle.lcdInk, MumlaStyle.lcdEnd), 4.5)
            }
        }
    }

    private func contrast(_ foreground: Color, _ background: Color) -> Double {
        let values = [foreground, background].map { color in
            let rgb = NSColor(color).usingColorSpace(.sRGB)!
            let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { value in
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
        }
        return (values.max()! + 0.05) / (values.min()! + 0.05)
    }
}
