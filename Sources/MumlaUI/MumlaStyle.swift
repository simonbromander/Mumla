import SwiftUI
#if os(macOS)
import AppKit
#endif

public func mText(_ swedish: String, _ english: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("sv") == true ? swedish : english
}

public enum MumlaStyle {
    public static let background = mumlaAdaptive((0.96, 0.965, 0.95), (0.075, 0.082, 0.078))
    public static let backdropTop = mumlaAdaptive((0.995, 0.995, 0.98), (0.13, 0.13, 0.13))
    public static let panel = mumlaAdaptive((0.90, 0.91, 0.89), (0.15, 0.16, 0.15))
    public static let ink = mumlaAdaptive((0.12, 0.14, 0.12), (0.92, 0.93, 0.91))
    public static let secondary = mumlaAdaptive((0.32, 0.34, 0.32), (0.66, 0.69, 0.66))
    public static let accent = mumlaAdaptive((0.69, 0.23, 0.035), (0.69, 0.81, 0.66))
    public static let lcd = mumlaAdaptive((0.85, 0.89, 0.79), (0.63, 0.76, 0.59))
    public static let lcdEnd = mumlaAdaptive((0.94, 0.96, 0.89), (0.72, 0.83, 0.67))
    public static let lcdInk = Color(red: 0.10, green: 0.18, blue: 0.11)
    public static let recording = mumlaAdaptive((0.83, 0.25, 0.05), (0.91, 0.36, 0.28))
    public static let activeKey = Color(red: 0.96, green: 0.40, blue: 0.15)
    public static let surfaceTop = mumlaAdaptive((0.995, 0.995, 0.98), (0.19, 0.19, 0.19))
    public static let surfaceBottom = mumlaAdaptive((0.89, 0.90, 0.88), (0.13, 0.13, 0.13))
    public static let recessTop = mumlaAdaptive((0.82, 0.84, 0.81), (0.045, 0.045, 0.045))
    public static let recessBottom = mumlaAdaptive((0.94, 0.95, 0.92), (0.08, 0.08, 0.08))
    public static let keyTop = mumlaAdaptive((1, 1, 0.99), (0.34, 0.34, 0.34))
    public static let keyBottom = mumlaAdaptive((0.86, 0.88, 0.85), (0.22, 0.22, 0.22))
    public static let keyPressed = mumlaAdaptive((0.82, 0.84, 0.81), (0.16, 0.16, 0.16))
    public static let buttonTop = mumlaAdaptive((1, 1, 0.99), (0.23, 0.23, 0.23))
    public static let buttonBottom = mumlaAdaptive((0.86, 0.88, 0.85), (0.15, 0.15, 0.15))
    public static let buttonPressedTop = mumlaAdaptive((0.82, 0.84, 0.81), (0.10, 0.10, 0.10))
    public static let buttonPressedBottom = mumlaAdaptive((0.90, 0.91, 0.89), (0.14, 0.14, 0.14))
    public static let socket = mumlaAdaptive((0.69, 0.71, 0.68), (0.035, 0.035, 0.035))
    public static let meterOff = mumlaAdaptive((0.68, 0.70, 0.66), (0.23, 0.23, 0.23))
}

public struct MumlaBackdrop: View {
    @MumlaTheme private var palette
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    public init() {}
    public var body: some View {
        ZStack {
            if palette.skin == .native || reduceTransparency || contrast == .increased {
                palette.background
            } else {
                #if os(macOS)
                WindowGlass()
                #else
                Rectangle().fill(.regularMaterial)
                #endif
                LinearGradient(colors: [palette.backdropTop.opacity(scheme == .light ? 0.60 : 0.54),
                                        palette.background.opacity(0.80)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Frosted chrome for navigation, kept separate from the opaque reading wells.
public struct MumlaGlassPanel: View {
    @MumlaTheme private var palette
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    public init() {}
    public var body: some View {
        Group {
            if reduceTransparency || contrast == .increased {
                palette.panel
            } else if palette.skin == .native {
                Rectangle().fill(.regularMaterial)
            } else {
                Rectangle().fill(.regularMaterial)
                    .overlay(palette.panel.opacity(scheme == .light ? 0.40 : 0.34))
                    .overlay {
                        LinearGradient(colors: [.white.opacity(scheme == .light ? 0.22 : 0.05), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

#if os(macOS)
private struct WindowGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
#endif

public extension View {
    func mumlaSurface(radius: CGFloat = 12, opacity: Double = 1) -> some View {
        modifier(MachinedSurface(radius: radius, inset: false, opacity: opacity))
    }
    func mumlaRecess(radius: CGFloat = 10) -> some View { modifier(MachinedSurface(radius: radius, inset: true)) }
    func mumlaDisplayLens(radius: CGFloat = 7) -> some View { modifier(DisplayLens(radius: radius)) }
}

private struct MachinedSurface: ViewModifier {
    @MumlaTheme private var palette
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var radius: CGFloat
    var inset: Bool
    var opacity: Double = 1
    @ViewBuilder func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if palette.skin == .native {
            if inset {
                content.background(palette.panel, in: shape)
                    .overlay { shape.strokeBorder(.primary.opacity(contrast == .increased ? 0.35 : 0.08)) }
            } else {
                content.mumlaChrome(in: shape)
            }
        } else {
        content
            .background {
                Group {
                    if inset || reduceTransparency || contrast == .increased {
                        shape.fill(LinearGradient(
                            colors: inset ? [palette.recessTop, palette.recessBottom] : [palette.surfaceTop, palette.surfaceBottom],
                            startPoint: .top, endPoint: .bottom
                        ).shadow(.inner(color: .black.opacity(inset ? (scheme == .light ? 0.18 : 0.8) : 0.1), radius: inset ? 3 : 1, y: 2)))
                    } else {
                        shape.fill(.regularMaterial)
                            .overlay {
                                shape.fill(LinearGradient(colors: [palette.surfaceTop.opacity(scheme == .light ? 0.58 : 0.34),
                                                                   palette.surfaceBottom.opacity(scheme == .light ? 0.42 : 0.48)],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                    }
                }.opacity(reduceTransparency || contrast == .increased ? 1 : opacity)
            }
            .overlay {
                shape.strokeBorder(LinearGradient(
                    colors: inset ? [.black.opacity(scheme == .light ? 0.25 : 0.85), .white.opacity(scheme == .light ? 0.8 : 0.12)] : [.white.opacity(scheme == .light ? 0.95 : 0.30), .white.opacity(scheme == .light ? 0.22 : 0.06), .black.opacity(scheme == .light ? 0.15 : 0.5)],
                    startPoint: .top, endPoint: .bottom
                ), lineWidth: 1).allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(inset ? 0 : scheme == .light ? 0.07 : 0.20), radius: 7, y: 4)
        }
    }
}

private struct DisplayLens: ViewModifier {
    @Environment(\.mumlaSkin) private var skin
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var radius: CGFloat
    func body(content: Content) -> some View {
        content.overlay {
            if skin == .classic && !reduceTransparency && contrast != .increased {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.20), .white.opacity(0.02), .clear],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.05)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    }
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

public struct MumlaKeyStyle: PrimitiveButtonStyle {
    @Environment(\.mumlaSkin) private var skin
    public var radius: CGFloat
    public var feedback: Bool
    public init(radius: CGFloat = 9, feedback: Bool = true) { self.radius = radius; self.feedback = feedback }

    @ViewBuilder public func makeBody(configuration: Configuration) -> some View {
        if skin == .native {
            if #available(macOS 26, iOS 26, *) {
                Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                    .buttonStyle(.glass).tint(nil).controlSize(.small)
            } else {
                Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                    .buttonStyle(.bordered)
            }
        } else {
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(ClassicKeyStyle(radius: radius, feedback: feedback))
        }
    }
}

private struct ClassicKeyStyle: ButtonStyle {
    @MumlaTheme private var palette
    public var radius: CGFloat
    public var feedback: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(radius: CGFloat = 9, feedback: Bool = true) { self.radius = radius; self.feedback = feedback }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .foregroundStyle(enabled ? palette.ink : palette.secondary.opacity(0.45))
            .background {
                shape.fill(LinearGradient(
                    colors: configuration.isPressed ? [palette.buttonPressedTop, palette.buttonPressedBottom] : [palette.buttonTop, palette.buttonBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).shadow(.inner(color: .white.opacity(configuration.isPressed ? 0 : 0.045), radius: 1, y: 1)))
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(configuration.isPressed ? 0.05 : scheme == .light ? 0.6 : 0.20), .black.opacity(scheme == .light ? 0.3 : 0.95)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : scheme == .light ? 0.14 : 0.45), radius: configuration.isPressed ? 1 : 3, y: configuration.isPressed ? 0 : 2)
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && feedback && enabled { MumlaFeedback.press() }
            }
    }
}

public struct MumlaWordmark: View {
    @MumlaTheme private var palette
    public init() {}
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(palette.skin == .native ? "Mumla" : "mumla").mumlaFont(size: 28, weight: .semibold)
            if palette.skin == .classic {
                Text("/ 01").mumlaFont(size: 11, weight: .medium).foregroundStyle(palette.secondary)
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("Mumla")
    }
}

public struct MumlaIconButton: View {
    private var symbol: String
    private var label: String
    private var action: () -> Void
    public init(_ symbol: String, label: String, action: @escaping () -> Void) {
        self.symbol = symbol; self.label = label; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol).mumlaFont(size: 17, weight: .regular)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(MumlaKeyStyle()).accessibilityLabel(label).help(label)
    }
}

public struct MumlaRecorderDisplay: View {
    @MumlaTheme private var palette
    public var status: String
    public var detail: String
    public var elapsed: TimeInterval
    public var language: String
    public var recording: Bool
    public var compact: Bool

    public init(status: String, detail: String, elapsed: TimeInterval, language: String = "SV", recording: Bool = false, compact: Bool = false) {
        self.status = status; self.detail = detail; self.elapsed = elapsed; self.language = language; self.recording = recording
        self.compact = compact
    }

    public var body: some View {
        if palette.skin == .native { nativeDisplay } else { classicDisplay }
    }

    private var nativeDisplay: some View {
        VStack(spacing: compact ? 12 : 20) {
            HStack(spacing: 7) {
                MumlaRecordingLight(recording: recording)
                Text(status).mumlaFont(.caption, weight: .semibold)
                Spacer()
                Label(language, systemImage: "lock.fill").mumlaFont(.caption)
                    .foregroundStyle(palette.secondary)
            }
            Text(String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60))
                .font(.system(size: compact ? 56 : 72, weight: .light, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
            Text(detail).mumlaFont(.subheadline).foregroundStyle(palette.secondary)
                .lineLimit(2).multilineTextAlignment(.center)
        }
        .padding(compact ? 16 : 24)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityIdentifier("recorder.native-display")
    }

    private var classicDisplay: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            HStack {
                HStack(spacing: 6) {
                    MumlaRecordingLight(recording: recording)
                    Text(status).fontWeight(.semibold)
                }
                Spacer()
                Image(systemName: "lock.fill")
                Text(language)
            }.mumlaFont(size: 11)
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60))
                    .mumlaFont(size: 56, weight: .light).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text("MIN / SEC").mumlaFont(size: 9)
                Spacer(minLength: 0)
            }.frame(minHeight: 64)
            Text(detail).mumlaFont(size: 12, weight: .medium)
                .lineLimit(1).truncationMode(.tail)
            if !compact {
                HStack {
                    Text("16 kHz")
                    Spacer()
                    Text("MONO / PCM")
                }
                .mumlaFont(size: 10)
                .padding(.top, 10)
                .overlay(alignment: .top) { Rectangle().fill(palette.lcdInk.opacity(0.25)).frame(height: 1) }
            }
        }
        .foregroundStyle(palette.lcdInk)
        .padding(compact ? 14 : 20)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: [palette.lcd, palette.lcdEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .shadow(.inner(color: .black.opacity(0.45), radius: 5, x: 0, y: 3)))
        }
        .overlay {
            Canvas { context, size in
                var lines = Path()
                for y in stride(from: 0.0, to: size.height, by: 3) {
                    lines.move(to: CGPoint(x: 0, y: y))
                    lines.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(lines, with: .color(palette.lcdInk.opacity(0.035)), lineWidth: 0.5)
            }.clipShape(RoundedRectangle(cornerRadius: 7)).allowsHitTesting(false).accessibilityHidden(true)
        }
        .mumlaDisplayLens()
        .padding(7).mumlaRecess(radius: 12)
    }
}

public struct MumlaWaveform: View {
    @MumlaTheme private var palette
    public var samples: [Double]
    public var active: Bool
    public var ink: Color?
    public init(samples: [Double] = [], active: Bool = false, ink: Color? = nil) {
        self.samples = samples; self.active = active; self.ink = ink
    }
    public var body: some View {
        Canvas { context, size in
            let count = 43
            let spacing = size.width / CGFloat(count)
            for index in 0..<count {
                let value = samples.indices.contains(index) ? samples[index] : 0
                let height = max(2, CGFloat(value) * size.height)
                let rect = CGRect(x: CGFloat(index) * spacing, y: (size.height - height) / 2, width: max(1, spacing - 3), height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(active ? (ink ?? palette.accent) : palette.secondary.opacity(0.4)))
            }
        }.accessibilityHidden(true)
    }
}

public struct MumlaInputMeter: View {
    @MumlaTheme private var palette
    public var level: Double
    public var active: Bool
    public var compact: Bool
    public init(level: Double, active: Bool, compact: Bool = false) { self.level = level; self.active = active; self.compact = compact }
    public var body: some View {
        if palette.skin == .native {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill").foregroundStyle(palette.secondary)
                MumlaWaveform(samples: Array(repeating: active ? min(1, max(0, level)) : 0, count: 43), active: active)
                    .frame(height: compact ? 20 : 32)
            }
            .padding(.horizontal, 16).frame(height: compact ? 44 : 56)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(mText("Mikrofonnivå", "Microphone level"))
            .accessibilityValue(active ? String(format: "%.0f dB", 30 * log10(max(0.01, level))) : mText("Inaktiv", "Inactive"))
        } else { classicMeter }
    }
    @ViewBuilder private var classicMeter: some View {
        let decibels = max(-60, 30 * log10(max(0.01, level)))
        let fraction = (decibels + 60) / 60
        VStack(spacing: 9) {
            HStack(spacing: 12) {
                Text("MIC").mumlaFont(size: 10, weight: .medium)
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(0..<32, id: \.self) { index in
                            Rectangle().fill(active && Double(index) / 32 < fraction ? (index > 27 ? palette.recording : palette.accent) : palette.meterOff)
                        }
                    }.frame(width: geometry.size.width, height: 12)
                }.frame(height: 12)
                Text(active ? String(format: "%.0f dB", 30 * log10(max(0.01, level))) : "-- dB")
                    .mumlaFont(size: 10).monospacedDigit().frame(width: 46, alignment: .trailing)
            }
            if !compact {
                HStack {
                    Text("-60")
                    Spacer()
                    Text("-40")
                    Spacer()
                    Text("-20")
                    Spacer()
                    Text("0")
                }.mumlaFont(size: 9).padding(.leading, 32).padding(.trailing, 54)
            }
        }
        .foregroundStyle(palette.secondary).padding(15).mumlaRecess(radius: 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mText("Mikrofonnivå", "Microphone level"))
        .accessibilityValue(active ? String(format: "%.0f dB", 30 * log10(max(0.01, level))) : mText("Inaktiv", "Inactive"))
    }
}

public struct MumlaTransportKey: View {
    @MumlaTheme private var palette
    @Environment(\.isEnabled) private var enabled
    public var symbol: String
    public var title: String
    public var primary: Bool
    public var active: Bool
    public var busy: Bool
    public var compact: Bool
    public var action: () -> Void
    public init(_ symbol: String, title: String, primary: Bool = false, active: Bool = false, busy: Bool = false, compact: Bool = false, action: @escaping () -> Void) {
        self.symbol = symbol; self.title = title; self.primary = primary; self.active = active; self.busy = busy; self.action = action
        self.compact = compact
    }
    public var body: some View {
        if palette.skin == .native { nativeKey } else { classicKey }
    }
    private var nativeKey: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Group {
                    if busy { ProgressView() }
                    else { Image(systemName: symbol).font(.system(size: primary ? 28 : 19, weight: .medium)) }
                }
                .frame(width: primary ? 64 : 44, height: primary ? 64 : 44)
                .foregroundStyle(primary ? palette.recording : palette.ink)
            }
            .buttonStyle(MumlaKeyStyle(feedback: false))
            .buttonBorderShape(.circle)
            .tint(primary ? palette.recording : palette.accent)
            .accessibilityLabel(title).help(title)
            Text(title).mumlaFont(.caption).foregroundStyle(palette.secondary)
                .lineLimit(1).minimumScaleFactor(0.75).accessibilityHidden(true)
        }.frame(maxWidth: .infinity).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    private var classicKey: some View {
        VStack(spacing: compact ? 8 : 13) {
            Button(action: action) {
                ZStack {
                    if busy { ProgressView().tint(palette.accent) }
                    else {
                        Image(systemName: symbol).mumlaFont(size: primary ? 27 : 18, weight: .medium)
                            .foregroundStyle(!enabled ? palette.secondary.opacity(0.35) : primary && !active ? palette.recording : palette.ink)
                    }
                }
                .frame(width: primary ? (compact ? 66 : 88) : 48, height: primary ? (compact ? 66 : 88) : 48)
                .contentShape(Circle())
            }
            .buttonStyle(MumlaKeyStyle(radius: 50, feedback: false))
            .padding(4)
            .background(Circle().fill(palette.socket.shadow(.inner(color: .black.opacity(0.4), radius: 2, y: 1))))
            .overlay(Circle().strokeBorder(.white.opacity(0.065), lineWidth: 1))
            .accessibilityLabel(title).help(title)
            Text(title.uppercased()).mumlaFont(size: 9, weight: .medium)
                .foregroundStyle(palette.secondary).lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityHidden(true)
        }.frame(maxWidth: .infinity)
    }
}

public struct MumlaEmptyState: View {
    @MumlaTheme private var palette
    private var symbol: String
    private var title: String
    public init(_ title: String, symbol: String) { self.title = title; self.symbol = symbol }
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).mumlaFont(size: 17, weight: .light)
            Text(title).mumlaFont(size: 13)
        }.foregroundStyle(palette.secondary).frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}
