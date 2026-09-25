import SwiftUI

struct MumlaHomeView: View {
    var body: some View {
        ZStack {
            LiquidBackdrop()

            VStack(spacing: 30) {
                Spacer(minLength: 32)

                IconHalo()

                VStack(spacing: 8) {
                    Text("Mumla")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Privat diktering")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                StatusGlass()

                Spacer(minLength: 24)

                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(width: 118, height: 5)
                    .overlay {
                        Capsule().stroke(.white.opacity(0.45), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }
}

private struct LiquidBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.91, green: 0.99, blue: 1.00),
                    Color(red: 0.74, green: 0.94, blue: 0.93),
                    Color(red: 0.72, green: 0.78, blue: 1.00),
                    Color(red: 0.91, green: 0.86, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                LiquidBand(opacity: 0.34)
                    .frame(height: 280)
                    .offset(y: -48)

                Spacer()

                LiquidBand(opacity: 0.22)
                    .frame(height: 250)
                    .rotationEffect(.degrees(180))
                    .offset(y: 42)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
    }
}

private struct LiquidBand: View {
    var opacity: Double

    var body: some View {
        LinearGradient(
            colors: [
                .white.opacity(opacity),
                Color(red: 0.49, green: 0.97, blue: 0.90).opacity(opacity * 0.8),
                Color(red: 0.54, green: 0.62, blue: 1.00).opacity(opacity * 0.7),
                .white.opacity(opacity * 0.6)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask {
            RoundedRectangle(cornerRadius: 92, style: .continuous)
                .rotationEffect(.degrees(-12))
                .padding(.horizontal, -56)
        }
        .blur(radius: 18)
    }
}

private struct IconHalo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(.thinMaterial)
                .frame(width: 166, height: 166)
                .overlay {
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .stroke(.white.opacity(0.62), lineWidth: 1)
                }
                .shadow(color: Color(red: 0.28, green: 0.68, blue: 0.82).opacity(0.22), radius: 34, y: 18)

            Image(systemName: "waveform")
                .font(.system(size: 62, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 0.28, green: 0.82, blue: 0.88), Color(red: 0.56, green: 0.48, blue: 0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .white.opacity(0.75), radius: 12)
        }
        .accessibilityLabel("Mumla")
    }
}

private struct StatusGlass: View {
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                StatusChip(systemName: "lock.shield.fill", title: "On-device")
                StatusChip(systemName: "waveform", title: "SV + EN")
            }

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 110, height: 110)
                    .overlay {
                        Circle().stroke(.white.opacity(0.58), lineWidth: 1)
                    }

                Image(systemName: "mic.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.72, blue: 0.78), Color(red: 0.54, green: 0.44, blue: 0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: Color(red: 0.32, green: 0.74, blue: 0.86).opacity(0.22), radius: 24, y: 12)

            Text("Redo")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: 330)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.40), lineWidth: 1)
        }
    }
}

private struct StatusChip: View {
    var systemName: String
    var title: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color(red: 0.17, green: 0.45, blue: 0.55))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.48), lineWidth: 1)
        }
    }
}

#Preview {
    MumlaHomeView()
}
