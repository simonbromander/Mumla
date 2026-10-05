import SwiftUI

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
    public init() {}
    public var body: some View {
        LinearGradient(colors: [MumlaStyle.backdropTop, MumlaStyle.background], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea().accessibilityHidden(true)
    }
}

public extension View {
    func mumlaSurface(radius: CGFloat = 12) -> some View { modifier(MachinedSurface(radius: radius, inset: false)) }
    func mumlaRecess(radius: CGFloat = 10) -> some View { modifier(MachinedSurface(radius: radius, inset: true)) }
}

private struct MachinedSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat
    var inset: Bool
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                shape.fill(LinearGradient(
                    colors: inset ? [MumlaStyle.recessTop, MumlaStyle.recessBottom] : [MumlaStyle.surfaceTop, MumlaStyle.surfaceBottom],
                    startPoint: .top, endPoint: .bottom
                ).shadow(.inner(color: .black.opacity(inset ? (scheme == .light ? 0.18 : 0.8) : 0.1), radius: inset ? 3 : 1, y: 2)))
            }
            .overlay {
                shape.strokeBorder(LinearGradient(
                    colors: inset ? [.black.opacity(scheme == .light ? 0.25 : 0.85), .white.opacity(scheme == .light ? 0.8 : 0.12)] : [.white.opacity(scheme == .light ? 0.9 : 0.20), .black.opacity(scheme == .light ? 0.22 : 0.7)],
                    startPoint: .top, endPoint: .bottom
                ), lineWidth: 1).allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(inset ? 0 : scheme == .light ? 0.09 : 0.22), radius: 4, y: 3)
    }
}

public struct MumlaKeyStyle: ButtonStyle {
    public var radius: CGFloat
    public var feedback: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(radius: CGFloat = 9, feedback: Bool = true) { self.radius = radius; self.feedback = feedback }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .foregroundStyle(enabled ? MumlaStyle.ink : MumlaStyle.secondary.opacity(0.45))
            .background {
                shape.fill(LinearGradient(
                    colors: configuration.isPressed ? [MumlaStyle.buttonPressedTop, MumlaStyle.buttonPressedBottom] : [MumlaStyle.buttonTop, MumlaStyle.buttonBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).shadow(.inner(color: .white.opacity(configuration.isPressed ? 0 : 0.045), radius: 1, y: 1)))
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(configuration.isPressed ? 0.05 : scheme == .light ? 0.6 : 0.20), .black.opacity(scheme == .light ? 0.3 : 0.95)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.1 : scheme == .light ? 0.20 : 0.65), radius: configuration.isPressed ? 1 : 2, y: configuration.isPressed ? 0 : 3)
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && feedback && enabled { MumlaFeedback.press() }
            }
    }
}

public struct MumlaWordmark: View {
    public init() {}
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text("mumla").font(.system(size: 28, weight: .semibold, design: .monospaced))
            Text("/ 01").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
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
            Image(systemName: symbol).font(.system(size: 17, weight: .regular, design: .monospaced))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(MumlaKeyStyle()).accessibilityLabel(label).help(label)
    }
}

public struct MumlaRecorderDisplay: View {
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
        VStack(alignment: .leading, spacing: compact ? 8 : 16) {
            HStack {
                HStack(spacing: 6) {
                    MumlaRecordingLight(recording: recording)
                    Text(status).fontWeight(.semibold)
                }
                Spacer()
                Image(systemName: "lock.fill")
                Text(language)
            }.font(.system(size: 11, design: .monospaced))
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60))
                    .font(.system(size: 56, weight: .light, design: .monospaced)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text("MIN / SEC").font(.system(size: 9, design: .monospaced))
                Spacer(minLength: 0)
            }.frame(minHeight: 64)
            Text(detail).font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1).truncationMode(.tail)
            if !compact {
                HStack {
                    Text("16 kHz")
                    Spacer()
                    Text("MONO / PCM")
                }
                .font(.system(size: 10, design: .monospaced))
                .padding(.top, 10)
                .overlay(alignment: .top) { Rectangle().fill(MumlaStyle.lcdInk.opacity(0.25)).frame(height: 1) }
            }
        }
        .foregroundStyle(MumlaStyle.lcdInk)
        .padding(compact ? 14 : 20)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: [MumlaStyle.lcd, MumlaStyle.lcdEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .shadow(.inner(color: .black.opacity(0.45), radius: 5, x: 0, y: 3)))
        }
        .overlay {
            Canvas { context, size in
                var lines = Path()
                for y in stride(from: 0.0, to: size.height, by: 3) {
                    lines.move(to: CGPoint(x: 0, y: y))
                    lines.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(lines, with: .color(MumlaStyle.lcdInk.opacity(0.035)), lineWidth: 0.5)
            }.clipShape(RoundedRectangle(cornerRadius: 7)).allowsHitTesting(false).accessibilityHidden(true)
        }
        .padding(7).mumlaRecess(radius: 12)
    }
}

public struct MumlaWaveform: View {
    public var samples: [Double]
    public var active: Bool
    public var ink: Color
    public init(samples: [Double] = [], active: Bool = false, ink: Color = MumlaStyle.accent) {
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
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(active ? ink : MumlaStyle.secondary.opacity(0.4)))
            }
        }.accessibilityHidden(true)
    }
}

public struct MumlaInputMeter: View {
    public var level: Double
    public var active: Bool
    public var compact: Bool
    public init(level: Double, active: Bool, compact: Bool = false) { self.level = level; self.active = active; self.compact = compact }
    public var body: some View {
        let decibels = max(-60, 30 * log10(max(0.01, level)))
        let fraction = (decibels + 60) / 60
        VStack(spacing: 9) {
            HStack(spacing: 12) {
                Text("MIC").font(.system(size: 10, weight: .medium, design: .monospaced))
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(0..<32, id: \.self) { index in
                            Rectangle().fill(active && Double(index) / 32 < fraction ? (index > 27 ? MumlaStyle.recording : MumlaStyle.accent) : MumlaStyle.meterOff)
                        }
                    }.frame(width: geometry.size.width, height: 12)
                }.frame(height: 12)
                Text(active ? String(format: "%.0f dB", 30 * log10(max(0.01, level))) : "-- dB")
                    .font(.system(size: 10, design: .monospaced)).monospacedDigit().frame(width: 46, alignment: .trailing)
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
                }.font(.system(size: 9, design: .monospaced)).padding(.leading, 32).padding(.trailing, 54)
            }
        }
        .foregroundStyle(MumlaStyle.secondary).padding(15).mumlaRecess(radius: 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mText("Mikrofonnivå", "Microphone level"))
        .accessibilityValue(active ? String(format: "%.0f dB", 30 * log10(max(0.01, level))) : mText("Inaktiv", "Inactive"))
    }
}

public struct MumlaTransportKey: View {
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
        VStack(spacing: compact ? 8 : 13) {
            Button(action: action) {
                ZStack {
                    if busy { ProgressView().tint(MumlaStyle.accent) }
                    else {
                        Image(systemName: symbol).font(.system(size: primary ? 27 : 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(!enabled ? MumlaStyle.secondary.opacity(0.35) : primary && !active ? MumlaStyle.recording : MumlaStyle.ink)
                    }
                }
                .frame(width: primary ? (compact ? 66 : 88) : 48, height: primary ? (compact ? 66 : 88) : 48)
                .contentShape(Circle())
            }
            .buttonStyle(MumlaKeyStyle(radius: 50, feedback: false))
            .padding(4)
            .background(Circle().fill(MumlaStyle.socket.shadow(.inner(color: .black.opacity(0.4), radius: 2, y: 1))))
            .overlay(Circle().strokeBorder(.white.opacity(0.065), lineWidth: 1))
            .accessibilityLabel(title).help(title)
            Text(title.uppercased()).font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(MumlaStyle.secondary).lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityHidden(true)
        }.frame(maxWidth: .infinity)
    }
}

public struct MumlaEmptyState: View {
    private var symbol: String
    private var title: String
    public init(_ title: String, symbol: String) { self.title = title; self.symbol = symbol }
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17, weight: .light, design: .monospaced))
            Text(title).font(.system(size: 13, design: .monospaced))
        }.foregroundStyle(MumlaStyle.secondary).frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}
