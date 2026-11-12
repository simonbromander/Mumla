import SwiftUI

public enum MumlaSkin: String, CaseIterable, Identifiable, Sendable {
    case classic, native
    public static let preferenceKey = "mumla.interfaceStyle"
    public var id: String { rawValue }
    public var title: String {
        self == .classic ? mText("Klassisk", "Classic") : mText("Inbyggd", "Native")
    }
    public var fontDesign: Font.Design { self == .classic ? .monospaced : .default }

    public static func stored(in defaults: UserDefaults = .standard) -> Self {
        Self(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .classic
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.preferenceKey)
    }
}

private struct MumlaSkinKey: EnvironmentKey {
    static let defaultValue: MumlaSkin? = nil
}

public extension EnvironmentValues {
    var mumlaSkin: MumlaSkin {
        get { self[MumlaSkinKey.self] ?? .classic }
        set { self[MumlaSkinKey.self] = newValue }
    }
    var mumlaSkinOverride: MumlaSkin? { self[MumlaSkinKey.self] }
}

/// Independent hosting roots also observe the preference, before an environment exists.
@propertyWrapper public struct MumlaTheme: DynamicProperty {
    @AppStorage(MumlaSkin.preferenceKey) private var rawSkin = MumlaSkin.classic.rawValue
    @Environment(\.mumlaSkinOverride) private var override
    public init() {}
    public var wrappedValue: MumlaPalette {
        MumlaPalette(skin: override ?? MumlaSkin(rawValue: rawSkin) ?? .classic)
    }
}

/// Semantic colors shared by app windows, sheets, and the keyboard host.
public struct MumlaPalette {
    public let skin: MumlaSkin
    public init(skin: MumlaSkin) { self.skin = skin }
    public var background: Color {
        guard skin == .native else { return MumlaStyle.background }
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemGroupedBackground)
        #endif
    }
    public var panel: Color {
        guard skin == .native else { return MumlaStyle.panel }
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
    public var ink: Color { skin == .native ? .primary : MumlaStyle.ink }
    public var secondary: Color { skin == .native ? .secondary : MumlaStyle.secondary }
    public var accent: Color {
        guard skin == .native else { return MumlaStyle.accent }
        #if os(macOS)
        return Color(nsColor: .systemBlue)
        #else
        return Color(uiColor: .systemBlue)
        #endif
    }
    public var recording: Color { skin == .native ? .red : MumlaStyle.recording }
    public var lcd: Color { skin == .native ? panel : MumlaStyle.lcd }
    public var lcdEnd: Color { skin == .native ? panel : MumlaStyle.lcdEnd }
    public var lcdInk: Color { skin == .native ? ink : MumlaStyle.lcdInk }
    public var backdropTop: Color { skin == .native ? background : MumlaStyle.backdropTop }
    public var surfaceTop: Color { skin == .native ? panel : MumlaStyle.surfaceTop }
    public var surfaceBottom: Color { skin == .native ? panel : MumlaStyle.surfaceBottom }
    public var recessTop: Color { skin == .native ? panel : MumlaStyle.recessTop }
    public var recessBottom: Color { skin == .native ? panel : MumlaStyle.recessBottom }
    public var keyTop: Color { skin == .native ? panel : MumlaStyle.keyTop }
    public var keyBottom: Color { skin == .native ? panel : MumlaStyle.keyBottom }
    public var keyPressed: Color { skin == .native ? background : MumlaStyle.keyPressed }
    public var buttonTop: Color { skin == .native ? panel : MumlaStyle.buttonTop }
    public var buttonBottom: Color { skin == .native ? panel : MumlaStyle.buttonBottom }
    public var buttonPressedTop: Color { skin == .native ? background : MumlaStyle.buttonPressedTop }
    public var buttonPressedBottom: Color { skin == .native ? background : MumlaStyle.buttonPressedBottom }
    public var socket: Color { skin == .native ? background : MumlaStyle.socket }
    public var meterOff: Color { skin == .native ? secondary.opacity(0.2) : MumlaStyle.meterOff }
    public var activeKey: Color { skin == .native ? accent : MumlaStyle.activeKey }
}

public struct MumlaSkinPicker: View {
    @AppStorage(MumlaSkin.preferenceKey) private var rawSkin = MumlaSkin.classic.rawValue
    public init() {}
    public var body: some View {
        Picker(mText("Stil", "Style"), selection: Binding(
            get: { MumlaSkin(rawValue: rawSkin) ?? .classic }, set: { rawSkin = $0.rawValue }
        )) {
            ForEach(MumlaSkin.allCases) { skin in
                Text(skin.title).tag(skin).accessibilityIdentifier("style.\(skin.rawValue)")
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 330)
        .accessibilityIdentifier("settings.interface-style")
    }
}

public extension View {
    func mumlaFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(MumlaFontModifier(textStyle: style, weight: weight))
    }
    func mumlaFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(MumlaFontModifier(size: size, weight: weight))
    }
    func mumlaChrome<S: Shape>(in shape: S) -> some View { modifier(MumlaChrome(shape: shape)) }
}

private struct MumlaFontModifier: ViewModifier {
    @MumlaTheme private var palette
    var textStyle: Font.TextStyle = .body
    var size: CGFloat?
    var weight: Font.Weight?
    func body(content: Content) -> some View {
        let base = size.map { Font.system(size: $0, design: palette.skin.fontDesign) }
            ?? .system(textStyle, design: palette.skin.fontDesign)
        content.font(weight.map { base.weight($0) } ?? base)
    }
}

private struct MumlaChrome<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @MumlaTheme private var palette
    var shape: S
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(palette.panel, in: shape)
        } else if #available(macOS 26, iOS 26, *) {
            content.background { shape.fill(.clear).glassEffect(.regular, in: shape) }
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}
