import MumlaCore
import SwiftUI

struct MainView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        TabView {
            historyView
                .tabItem { Label("History", systemImage: "clock") }
            dictionaryView
                .tabItem { Label("Dictionary", systemImage: "text.book.closed") }
            settingsView
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .frame(minWidth: 620, minHeight: 420)
        .padding(18)
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.title2.weight(.semibold))
            List(coordinator.history) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.text)
                        .lineLimit(3)
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contextMenu {
                    Button("Paste Again") {
                        coordinator.pasteRecord(record)
                    }
                }
            }
            .overlay {
                if coordinator.history.isEmpty {
                    ContentUnavailableView("No Dictations", systemImage: "mic")
                }
            }
        }
    }

    private var dictionaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dictionary")
                .font(.title2.weight(.semibold))
            List(coordinator.dictionaryEntries) { entry in
                HStack {
                    Text(entry.original)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Text(entry.replacement)
                        .fontWeight(.semibold)
                }
            }
            .overlay {
                if coordinator.dictionaryEntries.isEmpty {
                    ContentUnavailableView("No Learned Words", systemImage: "text.badge.plus")
                }
            }
        }
    }

    private var settingsView: some View {
        Form {
            Picker("Language", selection: Binding(
                get: { coordinator.languageMode },
                set: { coordinator.setLanguageMode($0) }
            )) {
                Text("Auto").tag(LanguageMode.automatic)
                Text("Svenska").tag(LanguageMode.swedish)
                Text("English").tag(LanguageMode.english)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Microphone")
                Spacer()
                Button("Allow") {
                    Task { @MainActor in await coordinator.requestMicrophonePermission() }
                }
            }

            HStack {
                Text("Accessibility")
                Spacer()
                Button("Open Settings") {
                    coordinator.requestAccessibilityPermission()
                }
            }

            HStack {
                Text("Model")
                Spacer()
                Text(coordinator.modelDirectory?.path ?? "Not staged")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Status")
                Spacer()
                Text(coordinator.statusText)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
