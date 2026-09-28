import SwiftUI

public struct MumlaStereoKeyStyle: ButtonStyle {
    public var isLatched: Bool
    public var onPressChanged: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isLatched: Bool, onPressChanged: @escaping (Bool) -> Void) {
        self.isLatched = isLatched
        self.onPressChanged = onPressChanged
    }

    public func makeBody(configuration: Configuration) -> some View {
        let down = isLatched || configuration.isPressed
        let cap = RoundedRectangle(cornerRadius: 7, style: .continuous)
        let travel: CGFloat = down ? 6 : 0

        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(white: 0.035).shadow(.inner(color: .black, radius: 3, y: 2)))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }

            // The lower key wall stays in the socket as the face travels into it.
            cap.fill(LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.055)],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay(alignment: .bottom) {
                cap.strokeBorder(.black.opacity(0.85), lineWidth: 1)
            }
            .padding(.horizontal, 2).padding(.top, 7).padding(.bottom, 2)

            configuration.label
                .frame(maxWidth: .infinity).frame(height: 52)
                .foregroundStyle(down ? MumlaStyle.accent : Color(white: 0.84))
                .background {
                    cap.fill(LinearGradient(
                        colors: down
                            ? [Color(white: 0.16), Color(white: 0.20)]
                            : [Color(white: 0.34), Color(white: 0.22)],
                        startPoint: .top, endPoint: .bottom
                    ).shadow(.inner(color: down ? .black.opacity(0.38) : .white.opacity(0.10), radius: down ? 3 : 1, y: down ? 2 : 1)))
                }
                .overlay {
                    cap.strokeBorder(LinearGradient(
                        colors: down
                            ? [.black.opacity(0.85), .white.opacity(0.10)]
                            : [.white.opacity(0.38), .white.opacity(0.05), .black.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    ), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(down ? MumlaStyle.accent : Color(white: 0.08))
                        .frame(width: 4, height: 2)
                        .padding(8)
                        .accessibilityHidden(true)
                }
                .compositingGroup()
                .shadow(color: .black.opacity(down ? 0.20 : 0.75), radius: down ? 1 : 2, y: down ? 0 : 5)
                .rotation3DEffect(.degrees(reduceMotion || down ? 0 : -7), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.35)
                .offset(y: travel + (configuration.isPressed && !reduceMotion ? 1 : 0))
                .padding(.horizontal, 2).padding(.top, 2)
        }
        .frame(height: 64)
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.68), value: isLatched)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: configuration.isPressed)
        .onChange(of: configuration.isPressed) { _, pressed in onPressChanged(pressed) }
    }
}
