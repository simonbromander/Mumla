import MumlaUI
import SwiftUI
import UIKit
import XCTest

@MainActor
final class SkinTests: XCTestCase {
    func testStylePreferenceDefaultsAndIndependentPersistence() throws {
        let suite = "MumlaIOSSkinTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(MumlaSkin.stored(in: defaults), .classic)
        defaults.set("unknown", forKey: MumlaSkin.preferenceKey)
        XCTAssertEqual(MumlaSkin.stored(in: defaults), .classic)
        for style in MumlaSkin.allCases {
            for appearance in MumlaAppearance.allCases {
                style.save(to: defaults)
                appearance.save(to: defaults)
                XCTAssertEqual(MumlaSkin.stored(in: defaults), style)
                XCTAssertEqual(MumlaAppearance.stored(in: defaults), appearance)
            }
        }
    }

    func testSharedControlsRenderAtCompactWidthInBothStyles() throws {
        for style in MumlaSkin.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let view = VStack {
                    MumlaRecorderDisplay(status: "STANDBY", detail: "Ready to listen", elapsed: 17, compact: true)
                    HStack {
                        MumlaTransportKey("circle.fill", title: "Record", primary: true, compact: true) {}
                        MumlaIconButton("square.and.arrow.up", label: "Share") {}
                    }
                    Toggle("Feedback", isOn: .constant(true)).toggleStyle(MumlaSwitchStyle())
                }.padding(20).frame(width: 320, height: 400)
                    .background(MumlaPalette(skin: style).background)
                    .environment(\.mumlaSkin, style).environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: view)
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size, CGSize(width: 320, height: 400))
            }
        }
    }
}
