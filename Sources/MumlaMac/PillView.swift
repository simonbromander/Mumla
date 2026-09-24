import MumlaCore
import SwiftUI

struct PillView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        HStack(spacing: 12) {
            leading
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)

            if case .handsFree = coordinator.pillState {
                Button {
                    Task { @MainActor in await coordinator.finishDictation() }
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop")

                Button {
                    coordinator.cancelDictation()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Cancel")
            }

            languageBadge
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var leading: some View {
        switch coordinator.pillState {
        case .listening, .handsFree:
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("REC")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.red)
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 22)
        case .message:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .hidden:
            EmptyView()
        }
    }

    private var languageBadge: some View {
        Text(languageTitle)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Color.primary.opacity(0.09))
            .clipShape(Capsule())
    }

    private var title: String {
        switch coordinator.pillState {
        case let .listening(elapsed):
            return "Listening \(format(elapsed))"
        case let .handsFree(elapsed):
            return "Hands-free \(format(elapsed))"
        case .transcribing:
            return "Transcribing"
        case let .message(message):
            return message
        case .hidden:
            return ""
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
