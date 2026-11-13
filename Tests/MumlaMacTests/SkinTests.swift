import AppKit
import MumlaUI
import SwiftUI
import XCTest

@MainActor
final class SkinTests: XCTestCase {
    func testExistingAndUnknownPreferencesKeepClassic() throws {
        try withDefaults { defaults in
            XCTAssertEqual(MumlaSkin.stored(in: defaults), .classic)
            defaults.set("future-skin", forKey: MumlaSkin.preferenceKey)
            XCTAssertEqual(MumlaSkin.stored(in: defaults), .classic)
            XCTAssertEqual(MumlaSkin.allCases.map(\.rawValue), ["classic", "native"])
        }
    }

    func testStyleAndAppearancePersistIndependently() throws {
        _ = NSApplication.shared
        let previous = NSApp.appearance
        defer { NSApp.appearance = previous }
        try withDefaults { defaults in
            for style in MumlaSkin.allCases {
                for appearance in MumlaAppearance.allCases {
                    appearance.save(to: defaults)
                    style.save(to: defaults)
                    XCTAssertEqual(MumlaAppearance.stored(in: defaults), appearance)
                    XCTAssertEqual(MumlaSkin.stored(in: defaults), style)
                    appearance.save(to: defaults)
                    XCTAssertEqual(MumlaSkin.stored(in: defaults), style)
                }
            }
        }
    }

    func testBothStylesRenderInBothAppearancesAndHighContrast() throws {
        _ = NSApplication.shared
        for style in MumlaSkin.allCases {
            for scheme in [ColorScheme.light, .dark] {
                for accessible in [false, true] {
                    let root = VStack(spacing: 12) {
                        MumlaRecorderDisplay(status: "REC", detail: "Listening", elapsed: 77, recording: true, compact: true)
                        MumlaInputMeter(level: 0.4, active: true, compact: true)
                        HStack {
                            MumlaTransportKey("stop.fill", title: "Stop", primary: true, active: true, compact: true) {}
                            MumlaIconButton("doc.on.doc", label: "Copy") {}
                        }
                        Toggle("Enabled", isOn: .constant(true)).toggleStyle(MumlaSwitchStyle())
                        MumlaTextField("Word", text: .constant("Mumla"))
                    }
                    .padding(20).frame(width: 380, height: 480)
                    .background(MumlaPalette(skin: style).background)
                    .environment(\.mumlaSkin, style)
                    .environment(\.colorScheme, scheme)
                    let host = NSHostingView(rootView: root)
                    host.appearance = NSAppearance(named: accessible
                        ? (scheme == .light ? .accessibilityHighContrastAqua : .accessibilityHighContrastDarkAqua)
                        : (scheme == .light ? .aqua : .darkAqua))
                    host.frame = NSRect(x: 0, y: 0, width: 380, height: 480)
                    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.contentView = host
                    defer { window.close() }
                    host.layoutSubtreeIfNeeded()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    XCTAssertGreaterThan(bitmap.pixelsWide, 0)
                    // AppKit-backed glass buttons have their own layers; sample the reading backdrop.
                    XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: 8, y: 8)).alphaComponent, 0.98)
                }
            }
        }
    }

    private func withDefaults(_ action: (UserDefaults) throws -> Void) throws {
        let suite = "MumlaSkinTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try action(defaults)
    }
}
