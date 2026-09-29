import SwiftUI

public struct MumlaRecordingLight: View {
    private let recording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(recording: Bool) { self.recording = recording }
    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !recording || reduceMotion)) { context in
            let opacity = recording && !reduceMotion ? 0.72 + 0.28 * sin(context.date.timeIntervalSinceReferenceDate * .pi / 0.85) : 1
            Circle().fill(recording ? MumlaStyle.recording : MumlaStyle.lcdInk.opacity(0.65)).opacity(opacity)
        }.frame(width: 7, height: 7).accessibilityHidden(true)
    }
}

public struct MumlaPanelHeader: View {
    private let title: String
    private let closeLabel: String
    private let closeIdentifier: String
    private let close: () -> Void

    public init(_ title: String, closeLabel: String, closeIdentifier: String = "panel.close", close: @escaping () -> Void) {
        self.title = title
        self.closeLabel = closeLabel
        self.closeIdentifier = closeIdentifier
        self.close = close
    }

    public var body: some View {
        HStack(spacing: 16) {
            Text(title).font(.system(.title2, design: .monospaced).weight(.semibold)).accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            MumlaIconButton("xmark", label: closeLabel, action: close)
                .accessibilityIdentifier(closeIdentifier)
        }
        .padding(24)
        .background(MumlaStyle.background)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .overlay(alignment: .bottom) { Divider().overlay(.white.opacity(0.04)) }
    }
}

public struct MumlaTextField: View {
    private let title: String
    @Binding private var text: String

    public init(_ title: String, text: Binding<String>) {
        self.title = title
        _text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(.caption, design: .monospaced).weight(.medium)).foregroundStyle(MumlaStyle.secondary)
            TextField(title, text: $text)
                .textFieldStyle(.plain).font(.system(.body, design: .monospaced))
                .padding(16).mumlaRecess(radius: 8)
        }
    }
}

public struct MumlaReadout: View {
    private let value: String
    public init(_ value: String) { self.value = value }
    public var body: some View {
        Text(value).font(.system(.subheadline, design: .monospaced)).foregroundStyle(MumlaStyle.accent)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 10).mumlaRecess(radius: 6)
    }
}

public struct MumlaSwitchStyle: ToggleStyle {
    private let showsLabel: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled

    public init(showsLabel: Bool = true) { self.showsLabel = showsLabel }

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
            MumlaFeedback.press()
        } label: {
            HStack(spacing: 16) {
                if showsLabel {
                    configuration.label.foregroundStyle(.primary).multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                }
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    HStack {
                        Image(systemName: "power").foregroundStyle(configuration.isOn ? MumlaStyle.accent : MumlaStyle.secondary)
                        Spacer()
                        Circle().strokeBorder(MumlaStyle.secondary, lineWidth: 1).frame(width: 8, height: 8)
                    }.font(.system(size: 10, weight: .bold, design: .monospaced)).padding(.horizontal, 8)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [Color(white: 0.40), Color(white: 0.21)], startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        .overlay {
                            HStack(spacing: 3) {
                                ForEach(0..<3) { _ in
                                    Capsule().fill(.black.opacity(0.5)).frame(width: 1, height: 12)
                                        .shadow(color: .white.opacity(0.2), radius: 0, x: 1)
                                }
                            }
                        }
                        .shadow(color: .black.opacity(0.8), radius: 2, y: 2)
                        .frame(width: 28, height: 28).padding(4)
                }
                .frame(width: 68, height: 36).mumlaRecess(radius: 7)
                .padding(.vertical, 4).opacity(enabled ? 1 : 0.5)
                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.8), value: configuration.isOn)
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
        }
    }
}

public struct MumlaDownloadGauge: View {
    private let fraction: Double
    public init(fraction: Double) { self.fraction = min(1, max(0, fraction.isFinite ? fraction : 0)) }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<24) { index in
                Rectangle().fill(Double(index) / 24 < fraction ? MumlaStyle.accent : Color(white: 0.22))
                    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.12)).frame(height: 1) }
            }
        }
        .frame(height: 10).padding(8).mumlaRecess(radius: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mText("Hämtar språkmodell", "Downloading language model"))
        .accessibilityValue("\(Int(fraction * 100)) %")
    }
}
