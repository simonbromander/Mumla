import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public enum MumlaAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    public static let preferenceKey = "mumla.appearance"
    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
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

    public static func stored(in defaults: UserDefaults = .standard) -> MumlaAppearance {
        MumlaAppearance(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .system
    }

    @MainActor public func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.preferenceKey)
        applyNativeAppearance()
    }

    @MainActor public func applyNativeAppearance() {
        #if os(macOS)
        NSApp.appearance = self == .system ? nil : NSAppearance(named: self == .light ? .aqua : .darkAqua)
        #endif
    }
}

public struct MumlaAppearancePicker: View {
    @AppStorage(MumlaAppearance.preferenceKey) private var appearance = MumlaAppearance.system.rawValue
    @Environment(\.dynamicTypeSize) private var typeSize
    private var selection: MumlaAppearance { MumlaAppearance(rawValue: appearance) ?? .system }
    public init() {}
    public var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 5))
        layout {
            ForEach(MumlaAppearance.allCases) { option in
                Button {
                    guard selection != option else { return }
                    option.save()
                    MumlaFeedback.latch()
                } label: {
                    let labelLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 5))
                    labelLayout {
                        Image(systemName: option.symbol).font(.system(size: 15, weight: .medium))
                        Text(option.title).font(.system(.caption, design: .monospaced).weight(.medium))
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }.padding(.top, 8)
                }
                .buttonStyle(MumlaStereoKeyStyle(isLatched: selection == option, height: typeSize.isAccessibilitySize ? 76 : 64))
                .accessibilityLabel(option.title)
                .accessibilityIdentifier("appearance.\(option.rawValue)")
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }.frame(maxWidth: 330)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(mText("Utseende", "Appearance"))
    }
}

public extension View {
    func mumlaAppearance() -> some View { modifier(MumlaAppearanceModifier()) }
}

private struct MumlaAppearanceModifier: ViewModifier {
    @AppStorage(MumlaAppearance.preferenceKey) private var rawAppearance = MumlaAppearance.system.rawValue
    private var appearance: MumlaAppearance { MumlaAppearance(rawValue: rawAppearance) ?? .system }
    func body(content: Content) -> some View {
        content.preferredColorScheme(appearance.colorScheme)
            .foregroundStyle(MumlaStyle.ink)
            .onAppear { appearance.applyNativeAppearance() }
            .onChange(of: rawAppearance) { _, _ in appearance.applyNativeAppearance() }
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
