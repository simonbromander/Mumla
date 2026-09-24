import MumlaCore
import SwiftUI

struct PillView: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            stateGlyph

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            if case .handsFree = coordinator.pillState {
                iconButton(systemName: "stop.fill", help: "Stop") {
                    Task { @MainActor in await coordinator.finishDictation() }
                }

                iconButton(systemName: "xmark", help: "Cancel") {
                    coordinator.cancelDictation()
                }
            }

            languageBadge
        }
        .padding(.leading, 9)
        .padding(.trailing, 10)
        .frame(width: 482, height: 62)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.34),
                                    LiquidGlass.aqua.opacity(0.15),
                                    LiquidGlass.iris.opacity(0.10),
                                    Color.black.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(LiquidGlass.edgeHighlight, lineWidth: 1)
                .blendMode(.screen)
        }
        .overlay(alignment: .topLeading) {
            Capsule(style: .continuous)
                .trim(from: 0.03, to: 0.37)
                .stroke(Color.white.opacity(0.82), lineWidth: 1.4)
                .blur(radius: 0.2)
        }
        .shadow(color: LiquidGlass.aqua.opacity(0.18), radius: 18, y: 8)
        .shadow(color: .black.opacity(0.26), radius: 30, y: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: coordinator.pillState)
    }

    @ViewBuilder
    private var stateGlyph: some View {
        switch coordinator.pillState {
        case let .preparing(progress):
            ZStack {
                Circle()
                    .fill(LiquidGlass.aqua.opacity(0.16))
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .padding(8)
            }
            .frame(width: 46, height: 46)
        case .listening, .handsFree:
            ZStack {
                Circle()
                    .fill(LiquidGlass.coral.opacity(0.16))
                    .frame(width: 42, height: 42)
                Circle()
                    .fill(LiquidGlass.coral)
                    .frame(width: 12, height: 12)
                Text("REC")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .offset(y: 16)
            }
            .foregroundStyle(LiquidGlass.coral)
            .frame(width: 46, height: 46)
        case .transcribing:
            ProgressView()
                .controlSize(.regular)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.white.opacity(0.12)))
        case .message:
            ZStack {
                Circle()
                    .fill(LiquidGlass.mint.opacity(0.18))
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LiquidGlass.mint)
            }
            .frame(width: 46, height: 46)
        case .hidden:
            EmptyView()
        }
    }

    private var languageBadge: some View {
        Text(languageTitle)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(0.7)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(Capsule(style: .continuous).fill(LiquidGlass.aqua.opacity(0.10)))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.36), lineWidth: 1)
            }
    }

    private func iconButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.white.opacity(0.10)))
                }
                .overlay {
                    Circle().stroke(Color.white.opacity(0.34), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var title: String {
        switch coordinator.pillState {
        case .preparing:
            return "Getting ready"
        case .listening:
            return "Listening"
        case .handsFree:
            return "Hands-free"
        case .transcribing:
            return "Transcribing"
        case let .message(message):
            return message
        case .hidden:
            return ""
        }
    }

    private var subtitle: String? {
        switch coordinator.pillState {
        case let .preparing(progress):
            return "\(Int((progress * 100).rounded()))%"
        case let .listening(elapsed), let .handsFree(elapsed):
            return format(elapsed)
        case .transcribing:
            return "On device"
        case .message, .hidden:
            return nil
        }
    }

    private var accessibilityLabel: String {
        "Mumla, \(title)"
    }

    private var languageTitle: String {
        switch coordinator.languageMode {
        case .automatic:
            return "AUTO"
        case .swedish:
            return "SV"
        case .english:
            return "EN"
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
