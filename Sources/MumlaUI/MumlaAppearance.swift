import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public enum MumlaAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    public var id: String { rawValue }
    public var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
    public var title: String {
        switch self {
        case .system: mText("System", "System")
        case .light: mText("Ljust", "Light")
        case .dark: mText("Mörkt", "Dark")
        }
    }
}

public struct MumlaAppearancePicker: View {
    @AppStorage("mumla.appearance") private var appearance = MumlaAppearance.system.rawValue
    private var selection: MumlaAppearance { MumlaAppearance(rawValue: appearance) ?? .system }
    public init() {}
    public var body: some View {
        HStack(spacing: 5) {
            ForEach(MumlaAppearance.allCases) { option in
                Button {
                    appearance = option.rawValue
                    MumlaFeedback.latch()
                } label: {
                    Text(option.title).font(.system(size: 11, weight: .medium, design: .monospaced))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .buttonStyle(MumlaStereoKeyStyle(isLatched: selection == option, height: 48))
                .accessibilityIdentifier("appearance.\(option.rawValue)")
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }.frame(maxWidth: 330)
    }
}

public extension View {
    func mumlaAppearance() -> some View { modifier(MumlaAppearanceModifier()) }
}

private struct MumlaAppearanceModifier: ViewModifier {
    @AppStorage("mumla.appearance") private var rawAppearance = MumlaAppearance.system.rawValue
    private var appearance: MumlaAppearance { MumlaAppearance(rawValue: rawAppearance) ?? .system }
    func body(content: Content) -> some View {
        content.preferredColorScheme(appearance.colorScheme)
            .foregroundStyle(MumlaStyle.ink)
            .onAppear { applyNativeAppearance() }
            .onChange(of: rawAppearance) { _, _ in applyNativeAppearance() }
    }
    private func applyNativeAppearance() {
        #if os(macOS)
        NSApp.appearance = appearance == .system ? nil : NSAppearance(named: appearance == .light ? .aqua : .darkAqua)
        #endif
    }
}

func mumlaAdaptive(_ light: (Double, Double, Double), _ dark: (Double, Double, Double)) -> Color {
    #if os(macOS)
    Color(nsColor: NSColor(name: nil) { appearance in
        let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    })
    #else
    Color(uiColor: UIColor { traits in
        let rgb = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    })
    #endif
}
