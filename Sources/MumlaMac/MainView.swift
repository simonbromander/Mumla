import MumlaCore
import SwiftUI

struct MainView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var selection: MainSection = .history
    @State private var dictionaryOriginal = ""
    @State private var dictionaryReplacement = ""

    var body: some View {
        ZStack {
            WindowBackdrop()

            HStack(spacing: 18) {
                sidebar
                    .frame(width: 178)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(18)

            if coordinator.isOnboardingVisible {
                OnboardingOverlay(coordinator: coordinator)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .animation(.snappy(duration: 0.24), value: coordinator.isOnboardingVisible)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().fill(LiquidGlass.aqua.opacity(0.18)))
                        Image(systemName: "waveform")
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .frame(width: 34, height: 34)

                    Text("Mumla")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Text(coordinator.statusText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(spacing: 7) {
                navButton(.history)
                navButton(.dictionary)
                navButton(.settings)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text("Language")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 6) {
                    languageChip(.automatic, "Auto")
                    languageChip(.swedish, "SV")
                    languageChip(.english, "EN")
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 28, prominent: true)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .history:
            historyView
        case .dictionary:
            dictionaryView
        case .settings:
            settingsView
        }
    }

    private var historyView: some View {
        GlassPane(title: "History", subtitle: "\(coordinator.history.count) saved") {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if coordinator.history.isEmpty {
                        EmptyGlassState(systemName: "mic", title: "No dictations yet")
                            .frame(maxWidth: .infinity, minHeight: 290)
                    } else {
                        ForEach(coordinator.history) { record in
                            HistoryRow(record: record) {
                                coordinator.pasteRecord(record)
                            }
                        }
                    }
                }
                .padding(4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var dictionaryView: some View {
        GlassPane(title: "Dictionary", subtitle: "\(coordinator.dictionaryEntries.count) learned") {
            VStack(spacing: 12) {
                DictionaryEntryEditor(
                    original: $dictionaryOriginal,
                    replacement: $dictionaryReplacement
                ) {
                    coordinator.addDictionaryEntry(
                        original: dictionaryOriginal,
                        replacement: dictionaryReplacement
                    )
                    dictionaryOriginal = ""
                    dictionaryReplacement = ""
                }

                ScrollView {
                    LazyVStack(spacing: 10) {
                        if coordinator.dictionaryEntries.isEmpty {
                            EmptyGlassState(systemName: "text.badge.plus", title: "No learned words")
                                .frame(maxWidth: .infinity, minHeight: 254)
                        } else {
                            ForEach(coordinator.dictionaryEntries) { entry in
                                DictionaryEntryRow(entry: entry) {
                                    coordinator.deleteDictionaryEntry(entry)
                                }
                            }
                        }
                    }
                    .padding(4)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var settingsView: some View {
        GlassPane(title: "Settings", subtitle: "Local first") {
            VStack(spacing: 12) {
                SettingsGlassRow(title: "Language", value: languageTitle) {
                    Picker("", selection: Binding(
                        get: { coordinator.languageMode },
                        set: { coordinator.setLanguageMode($0) }
                    )) {
                        Text("Auto").tag(LanguageMode.automatic)
                        Text("Svenska").tag(LanguageMode.swedish)
                        Text("English").tag(LanguageMode.english)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }

                SettingsGlassRow(title: "Microphone", value: "Ask macOS") {
                    Button("Allow") {
                        Task { @MainActor in await coordinator.requestMicrophonePermission() }
                    }
                    .buttonStyle(.borderless)
                    .liquidControl()
                }

                SettingsGlassRow(title: "Accessibility", value: AccessibilityPermission.isTrusted ? "Allowed" : "Needed") {
                    Button("Open") {
                        coordinator.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderless)
                    .liquidControl()
                }

                SettingsGlassRow(title: "Model", value: coordinator.modelDirectory == nil ? "Not staged" : "Ready") {
                    modelAccessory
                }

                SettingsGlassRow(title: "Onboarding", value: coordinator.settings.onboardingCompleted ? "Done" : "Not finished") {
                    Button("Replay") {
                        coordinator.showOnboarding()
                    }
                    .buttonStyle(.borderless)
                    .liquidControl()
                }

                SettingsGlassRow(title: "Launch at Login", value: coordinator.launchAtLoginStatus.title) {
                    Toggle("", isOn: Binding(
                        get: { coordinator.isLaunchAtLoginRequested },
                        set: { coordinator.setLaunchAtLoginEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                SettingsGlassRow(title: "Status", value: coordinator.statusText) {
                    Image(systemName: coordinator.modelDirectory == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(coordinator.modelDirectory == nil ? LiquidGlass.coral : LiquidGlass.mint)
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var modelAccessory: some View {
        if coordinator.modelDirectory != nil {
            Text(coordinator.modelDirectory?.lastPathComponent ?? "Ready")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 260, alignment: .trailing)
        } else if coordinator.isInstallingModel {
            VStack(alignment: .trailing, spacing: 6) {
                ProgressView(value: coordinator.modelInstallProgress.fraction)
                    .frame(width: 180)
                Text(coordinator.modelInstallProgress.detail)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .frame(width: 180, alignment: .trailing)
            }
        } else {
            Button("Download") {
                coordinator.installModel()
            }
            .buttonStyle(.borderless)
            .liquidControl(selected: true)
        }
    }

    private func navButton(_ section: MainSection) -> some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.systemName)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 19)
                Text(section.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
            }
            .liquidControl(selected: selection == section, cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private func languageChip(_ mode: LanguageMode, _ title: String) -> some View {
        Button {
            coordinator.setLanguageMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .liquidControl(selected: coordinator.languageMode == mode, cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private var languageTitle: String {
        switch coordinator.languageMode {
        case .automatic:
            return "Auto"
        case .swedish:
            return "Svenska"
        case .english:
            return "English"
        }
    }
}

private enum MainSection: CaseIterable {
    case history
    case dictionary
    case settings

    var title: String {
        switch self {
        case .history:
            return "History"
        case .dictionary:
            return "Dictionary"
        case .settings:
            return "Settings"
        }
    }

    var systemName: String {
        switch self {
        case .history:
            return "clock"
        case .dictionary:
            return "text.book.closed"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

private struct WindowBackdrop: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    LiquidGlass.pearl.opacity(0.30),
                    LiquidGlass.aqua.opacity(0.16),
                    Color.white.opacity(0.07),
                    LiquidGlass.mint.opacity(0.10),
                    LiquidGlass.iris.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [
                    Color.white.opacity(0.30),
                    Color.white.opacity(0.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 210)
            .frame(maxHeight: .infinity, alignment: .top)
            LinearGradient(
                colors: [
                    LiquidGlass.aqua.opacity(0.00),
                    LiquidGlass.aqua.opacity(0.10),
                    LiquidGlass.iris.opacity(0.08),
                    LiquidGlass.aqua.opacity(0.00)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(-10))
            .blur(radius: 18)
            .opacity(0.78)
        }
        .ignoresSafeArea()
    }
}

private struct GlassPane<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .liquidGlass(cornerRadius: 30, prominent: true)
    }
}

private struct HistoryRow: View {
    var record: DictationRecord
    var paste: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(record.text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .lineLimit(4)
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(action: paste) {
                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
            .liquidControl(cornerRadius: 14)
            .help("Paste again")
        }
        .padding(14)
        .liquidGlass(cornerRadius: 18)
        .contextMenu {
            Button("Paste Again", action: paste)
        }
    }
}

private struct OnboardingOverlay: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.12))
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 22) {
                HStack {
                    OnboardingDots(step: coordinator.onboardingStep)
                    Spacer()
                    Text("\(coordinator.onboardingStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(LiquidGlass.aqua.opacity(0.14)))
                    Image(systemName: coordinator.onboardingStep.systemName)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(LiquidGlass.aqua)
                }
                .frame(width: 82, height: 82)
                .overlay {
                    Circle().stroke(Color.white.opacity(0.42), lineWidth: 1)
                }

                VStack(spacing: 7) {
                    Text(coordinator.onboardingStep.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text(coordinator.onboardingStep.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    if coordinator.onboardingStep.previous != nil {
                        Button {
                            coordinator.retreatOnboarding()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .heavy))
                        }
                        .buttonStyle(.plain)
                        .liquidControl(cornerRadius: 14)
                        .help("Back")
                    }

                    Button {
                        primaryAction()
                    } label: {
                        Label(coordinator.onboardingStep.primaryTitle, systemImage: coordinator.onboardingStep.primarySystemName)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .frame(minWidth: 164)
                    }
                    .buttonStyle(.plain)
                    .liquidControl(selected: true, cornerRadius: 16)

                    Button {
                        coordinator.completeOnboarding()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .liquidControl(cornerRadius: 16)
                }
            }
            .padding(28)
            .frame(width: 470)
            .liquidGlass(cornerRadius: 32, prominent: true)
            .shadow(color: LiquidGlass.aqua.opacity(0.16), radius: 28, y: 14)
            .accessibilityElement(children: .contain)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: coordinator.onboardingStep)
    }

    private func primaryAction() {
        switch coordinator.onboardingStep {
        case .value:
            coordinator.advanceOnboarding()
        case .microphone:
            Task { @MainActor in
                await coordinator.requestMicrophonePermission()
                coordinator.advanceOnboarding()
            }
        case .accessibility:
            coordinator.requestAccessibilityPermission()
            coordinator.advanceOnboarding()
        case .practice:
            coordinator.showPracticePill()
            coordinator.advanceOnboarding()
        case .done:
            coordinator.completeOnboarding()
        }
    }
}

private struct OnboardingDots: View {
    var step: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { candidate in
                Capsule(style: .continuous)
                    .fill(candidate.rawValue <= step.rawValue ? LiquidGlass.aqua : Color.white.opacity(0.24))
                    .frame(width: candidate == step ? 18 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct DictionaryEntryEditor: View {
    @Binding var original: String
    @Binding var replacement: String
    var add: () -> Void

    private var canAdd: Bool {
        !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            GlassTextField(title: "Original", text: $original)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(LiquidGlass.aqua)
                .frame(width: 20)

            GlassTextField(title: "Replacement", text: $replacement)

            Button(action: add) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .heavy))
            }
            .buttonStyle(.plain)
            .liquidControl(selected: canAdd, cornerRadius: 14)
            .disabled(!canAdd)
            .opacity(canAdd ? 1 : 0.48)
            .help("Add")
        }
        .padding(12)
        .liquidGlass(cornerRadius: 20)
    }
}

private struct DictionaryEntryRow: View {
    var entry: DictionaryEntry
    var delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.original)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LiquidGlass.aqua)

            Text(entry.replacement)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            Button(action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
            .liquidControl(cornerRadius: 14)
            .help("Delete")
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .padding(14)
        .liquidGlass(cornerRadius: 16)
    }
}

private struct GlassTextField: View {
    var title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LiquidGlass.pearl.opacity(0.10))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
    }
}

private extension OnboardingStep {
    var title: String {
        switch self {
        case .value:
            return "Mumla"
        case .microphone:
            return "Microphone"
        case .accessibility:
            return "Type Anywhere"
        case .practice:
            return "Practice"
        case .done:
            return "Ready"
        }
    }

    var subtitle: String {
        switch self {
        case .value:
            return "Private Swedish and English dictation, processed on this Mac."
        case .microphone:
            return "Allow the microphone before Mumla listens."
        case .accessibility:
            return "Allow Accessibility so Mumla can paste into the active app and restore the clipboard."
        case .practice:
            return "Show the floating pill, then try holding Ctrl in any text field."
        case .done:
            return "Mumla now lives in the menu bar."
        }
    }

    var systemName: String {
        switch self {
        case .value:
            return "waveform"
        case .microphone:
            return "mic"
        case .accessibility:
            return "cursorarrow.rays"
        case .practice:
            return "capsule.portrait"
        case .done:
            return "checkmark"
        }
    }

    var primaryTitle: String {
        switch self {
        case .value:
            return "Continue"
        case .microphone:
            return "Allow"
        case .accessibility:
            return "Open Settings"
        case .practice:
            return "Show Pill"
        case .done:
            return "Start"
        }
    }

    var primarySystemName: String {
        switch self {
        case .value, .done:
            return "arrow.right"
        case .microphone:
            return "mic"
        case .accessibility:
            return "gearshape"
        case .practice:
            return "sparkle.magnifyingglass"
        }
    }
}

private struct SettingsGlassRow<Accessory: View>: View {
    var title: String
    var value: String
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(value)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            accessory()
        }
        .padding(14)
        .liquidGlass(cornerRadius: 18)
    }
}

private struct EmptyGlassState: View {
    var systemName: String
    var title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(LiquidGlass.aqua)
                .frame(width: 70, height: 70)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(LiquidGlass.aqua.opacity(0.12)))
                }
                .overlay {
                    Circle().stroke(Color.white.opacity(0.42), lineWidth: 1)
                }

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
