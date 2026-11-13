import SwiftUI

public struct MumlaStereoKeyStyle: PrimitiveButtonStyle {
    @MumlaTheme private var palette
    public var isLatched: Bool
    public var height: CGFloat
    public var onPressChanged: (Bool) -> Void

    public init(isLatched: Bool, height: CGFloat = 72, onPressChanged: @escaping (Bool) -> Void = { _ in }) {
        self.isLatched = isLatched
        self.height = max(44, height)
        self.onPressChanged = onPressChanged
    }

    @ViewBuilder public func makeBody(configuration: Configuration) -> some View {
        if palette.skin == .native {
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(.bordered)
                .background(isLatched ? palette.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 32)
                .accessibilityAddTraits(isLatched ? .isSelected : [])
        } else {
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(ClassicStereoKeyStyle(isLatched: isLatched, height: height, onPressChanged: onPressChanged))
        }
    }
}

private struct ClassicStereoKeyStyle: ButtonStyle {
    @MumlaTheme private var palette
    public var isLatched: Bool
    public var height: CGFloat
    public var onPressChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    public init(isLatched: Bool, height: CGFloat = 72, onPressChanged: @escaping (Bool) -> Void = { _ in }) {
        self.isLatched = isLatched
        self.height = max(44, height)
        self.onPressChanged = onPressChanged
    }

    public func makeBody(configuration: Configuration) -> some View {
        let down = isLatched || configuration.isPressed
        let cap = RoundedRectangle(cornerRadius: 7, style: .continuous)
        let travel: CGFloat = down ? 8 : 0
        #if os(macOS)
        // AppKit bitmap/layer hosting mispositions perspective-transformed caps.
        let tilt = 0.0
        #else
        let tilt = reduceMotion || down ? 0.0 : -7.0
        #endif

        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(palette.socket.shadow(.inner(color: .black.opacity(scheme == .light ? 0.28 : 1), radius: 3, y: 2)))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }

            // The lower key wall stays in the socket as the face travels into it.
            cap.fill(LinearGradient(
                colors: [palette.panel, palette.socket],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay(alignment: .bottom) {
                cap.strokeBorder(.black.opacity(0.85), lineWidth: 1)
            }
            .padding(.horizontal, 2).padding(.top, 7).padding(.bottom, 2)

            configuration.label
                .frame(maxWidth: .infinity).frame(height: height - 14)
                .foregroundStyle(palette.ink)
                .background {
                    cap.fill(LinearGradient(
                        colors: down
                            ? [palette.keyPressed, palette.panel]
                            : [palette.keyTop, palette.keyBottom],
                        startPoint: .top, endPoint: .bottom
                    ).shadow(.inner(color: down ? .black.opacity(scheme == .light ? 0.12 : 0.38) : .white.opacity(0.10), radius: down ? 3 : 1, y: down ? 2 : 1)))
                }
                .overlay {
                    cap.strokeBorder(LinearGradient(
                        colors: down
                            ? [.black.opacity(scheme == .light ? 0.28 : 0.85), .white.opacity(0.5)]
                            : [.white.opacity(0.8), .white.opacity(0.05), .black.opacity(scheme == .light ? 0.30 : 0.85)],
                        startPoint: .top, endPoint: .bottom
                    ), lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: down ? [Color(red: 1, green: 0.62, blue: 0.28), palette.activeKey] : [palette.meterOff, palette.socket], startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.black.opacity(0.45), lineWidth: 0.5))
                        .frame(width: height > 48 ? 30 : 22, height: 5)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }
                .compositingGroup()
                .shadow(color: .black.opacity(down ? 0.12 : scheme == .light ? 0.28 : 0.75), radius: down ? 1 : 2, y: down ? 0 : 5)
                .rotation3DEffect(.degrees(tilt), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.35)
                .offset(y: travel + (configuration.isPressed && !reduceMotion ? 1 : 0))
                .padding(.horizontal, 2).padding(.top, 2)
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : .spring(response: 0.19, dampingFraction: 0.78), value: isLatched)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
        .onChange(of: configuration.isPressed) { _, pressed in onPressChanged(pressed) }
    }
}
