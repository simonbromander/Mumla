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
        }
        .frame(minWidth: 760, minHeight: 520)
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
                    LiquidGlass.aqua.opacity(0.15),
                    Color.white.opacity(0.06),
                    LiquidGlass.mint.opacity(0.08),
                    LiquidGlass.iris.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
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
