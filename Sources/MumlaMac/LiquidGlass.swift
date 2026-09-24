import SwiftUI

enum LiquidGlass {
    static let ink = Color.primary
    static let mutedInk = Color.secondary
    static let pearl = Color(red: 0.96, green: 0.99, blue: 1.00)
    static let aqua = Color(red: 0.24, green: 0.83, blue: 0.88)
    static let mint = Color(red: 0.42, green: 0.92, blue: 0.64)
    static let iris = Color(red: 0.54, green: 0.48, blue: 0.96)
    static let coral = Color(red: 1.00, green: 0.43, blue: 0.39)

    static var surfaceTint: LinearGradient {
        LinearGradient(
            colors: [
                pearl.opacity(0.36),
                aqua.opacity(0.12),
                iris.opacity(0.09),
                Color.black.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var edgeHighlight: LinearGradient {
        LinearGradient(
            colors: [
                pearl.opacity(0.78),
                Color.white.opacity(0.26),
                aqua.opacity(0.24),
                Color.black.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 24, prominent: Bool = false) -> some View {
        modifier(LiquidGlassSurface(cornerRadius: cornerRadius, prominent: prominent))
    }

    func liquidControl(selected: Bool = false, cornerRadius: CGFloat = 14) -> some View {
        modifier(LiquidGlassControl(cornerRadius: cornerRadius, selected: selected))
    }
}

private struct LiquidGlassSurface: ViewModifier {
    var cornerRadius: CGFloat
    var prominent: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(prominent ? .thinMaterial : .ultraThinMaterial)
                    .overlay(shape.fill(LiquidGlass.surfaceTint))
                    .overlay(alignment: .topLeading) {
                        shape
                            .stroke(Color.white.opacity(prominent ? 0.48 : 0.34), lineWidth: 1)
                            .blur(radius: 0.6)
                            .offset(x: -0.4, y: -0.4)
                    }
            }
            .overlay(alignment: .topLeading) {
                shape
                    .stroke(LiquidGlass.edgeHighlight, lineWidth: 1)
                    .blendMode(.screen)
            }
            .overlay(alignment: .bottomTrailing) {
                shape
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    .blur(radius: 0.4)
            }
            .clipShape(shape)
            .shadow(color: LiquidGlass.aqua.opacity(prominent ? 0.10 : 0.05), radius: prominent ? 26 : 14, y: prominent ? 12 : 7)
            .shadow(color: Color.black.opacity(prominent ? 0.20 : 0.11), radius: prominent ? 34 : 18, y: prominent ? 20 : 10)
    }
}

private struct LiquidGlassControl: ViewModifier {
    var cornerRadius: CGFloat
    var selected: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay {
                        shape.fill(
                            LinearGradient(
                                colors: selected
                                    ? [LiquidGlass.aqua.opacity(0.26), LiquidGlass.iris.opacity(0.16)]
                                    : [Color.white.opacity(0.16), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
            }
            .overlay {
                shape.stroke(Color.white.opacity(selected ? 0.62 : 0.26), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                shape
                    .trim(from: 0.02, to: 0.34)
                    .stroke(Color.white.opacity(selected ? 0.82 : 0.46), lineWidth: 1)
                    .blur(radius: 0.15)
            }
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .shadow(color: selected ? LiquidGlass.aqua.opacity(0.16) : Color.clear, radius: 14, y: 7)
    }
}
