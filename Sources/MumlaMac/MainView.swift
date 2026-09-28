import AppKit
import MumlaAudio
import MumlaCore
import MumlaUI
import SwiftUI

struct MainView: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = MainSection.dictate
    @State private var query = ""
    @State private var original = ""
    @State private var replacement = ""
    @State private var selectedRecord: DictationRecord?
    @State private var copied = false

    var body: some View {
        ZStack {
            MumlaBackdrop()
            HStack(spacing: 0) {
                sidebar.frame(width: 210)
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selection.title).font(.system(size: 28, weight: .semibold))
                            Text(subtitle).font(.subheadline).foregroundStyle(MumlaStyle.secondary)
                        }
                        Spacer()
                        if selection == .history {
                            Button {
                                Task { await coordinator.toggleHandsFreeDictation() }
                            } label: {
                                Label(mText("Diktera", "Dictate"), systemImage: "mic")
                                    .padding(.horizontal, 14).frame(height: 38)
                            }
                            .buttonStyle(.plain).mumlaSurface(radius: 8)
                            .disabled(coordinator.modelDirectory == nil)
                        }
                    }
                    switch selection {
                    case .dictate: recorder
                    case .history: history
                    case .dictionary: dictionary
                    case .settings: settings
                    }
                }
                .padding(.horizontal, 34).padding(.top, 48).padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .tint(MumlaStyle.accent)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: selection)
        .sheet(isPresented: $coordinator.isOnboardingVisible) { OnboardingView(coordinator: coordinator) }
        .sheet(item: $selectedRecord) { record in
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(MumlaStyle.secondary)
                    Spacer()
                    MumlaIconButton("xmark", label: mText("Stäng", "Close")) { selectedRecord = nil }
                }
                ScrollView { Text(record.text).font(.system(size: 18)).lineSpacing(6).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                HStack {
                    ShareLink(item: record.text) { Label(mText("Dela", "Share"), systemImage: "square.and.arrow.up") }
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.text, forType: .string)
                        copied = true
                    } label: { Label(copied ? mText("Kopierat", "Copied") : mText("Kopiera", "Copy"), systemImage: copied ? "checkmark" : "doc.on.doc") }
                }.buttonStyle(.bordered)
            }.padding(28).frame(width: 540, height: 400).background { MumlaBackdrop() }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 36) {
            MumlaWordmark().padding(.leading, 10)
            VStack(spacing: 6) {
                ForEach(MainSection.allCases) { section in
                    Button { selection = section } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.symbol).frame(width: 20)
                            Text(section.title).font(.system(size: 14, weight: selection == section ? .semibold : .regular))
                            Spacer()
                        }
                        .padding(.horizontal, 13).frame(height: 44)
                        .background { if selection == section { RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.24)) } }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(selection == section ? Color.primary : MumlaStyle.secondary)
                    .accessibilityAddTraits(selection == section ? .isSelected : [])
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Label(mText("På den här Macen", "On this Mac"), systemImage: "lock")
                    .font(.system(size: 12)).foregroundStyle(MumlaStyle.secondary)
                HStack(spacing: 7) {
                    Image(systemName: coordinator.modelDirectory == nil ? "arrow.down.circle" : "checkmark.circle")
                    Text(coordinator.modelDirectory == nil ? mText("Modell saknas", "Model needed") : mText("Redo att lyssna", "Ready to listen"))
                }.font(.system(size: 12)).foregroundStyle(MumlaStyle.secondary)
            }.padding(.horizontal, 10)
        }
        .padding(.horizontal, 16).padding(.top, 50).padding(.bottom, 26)
        .background(MumlaStyle.panel)
        .overlay(alignment: .trailing) { Rectangle().fill(.primary.opacity(0.06)).frame(width: 1) }
    }

    private var recorder: some View {
        ScrollView {
            VStack(spacing: 18) {
                MumlaRecorderDisplay(
                    status: isRecording ? "REC" : coordinator.pillState == .transcribing ? mText("BEARBETAR", "PROCESSING") : coordinator.isInstallingModel ? mText("HÄMTAR", "LOADING") : coordinator.modelDirectory == nil ? mText("EJ REDO", "NOT READY") : "STANDBY",
                    detail: recorderDetail,
                    elapsed: elapsed,
                    language: coordinator.languageMode == .english ? "EN" : coordinator.languageMode == .automatic ? "AUTO" : "SV",
                    recording: isRecording
                )
                MumlaInputMeter(level: coordinator.inputLevel, active: isRecording)
                HStack(alignment: .center, spacing: 16) {
                    MumlaTransportKey("xmark", title: mText("Avbryt", "Cancel")) { coordinator.cancelDictation() }
                        .disabled(!isRecording)
                    MumlaTransportKey(isRecording ? "stop.fill" : "circle.fill", title: isRecording ? mText("Stoppa", "Stop") : mText("Spela in", "Record"), primary: true, active: isRecording, busy: coordinator.pillState == .transcribing) {
                        Task { await coordinator.toggleHandsFreeDictation() }
                    }.disabled(coordinator.modelDirectory == nil || coordinator.pillState == .transcribing)
                    MumlaTransportKey("text.alignleft", title: mText("Senaste", "Latest")) {
                        copied = false
                        selectedRecord = coordinator.history.first
                    }.disabled(coordinator.history.isEmpty)
                }.padding(18).mumlaSurface(radius: 14)
                if coordinator.modelDirectory == nil { modelDownload }
                if let record = coordinator.history.first {
                    HStack(spacing: 12) {
                        Image(systemName: "text.alignleft").foregroundStyle(MumlaStyle.secondary)
                        Text(record.text).lineLimit(2).font(.system(size: 13))
                        Spacer()
                        Button { selectedRecord = record } label: { Image(systemName: "arrow.up.right") }.buttonStyle(.plain)
                            .help(mText("Öppna diktering", "Open dictation"))
                    }.padding(.vertical, 8)
                }
            }.frame(maxWidth: 560).padding(.bottom, 12).padding(.horizontal, 2)
                .frame(maxWidth: .infinity)
        }.scrollIndicators(.hidden)
    }

    private var isRecording: Bool {
        switch coordinator.pillState {
        case .listening, .handsFree: true
        default: false
        }
    }

    private var elapsed: TimeInterval {
        switch coordinator.pillState {
        case let .listening(elapsed), let .handsFree(elapsed): elapsed
        default: 0
        }
    }

    private var recorderDetail: String {
        switch coordinator.pillState {
        case .listening, .handsFree: mText("Lyssnar", "Listening")
        case .transcribing: mText("Skriver dina ord", "Transcribing")
        case let .preparing(progress): mText("Förbereder svenska", "Preparing Swedish") + " \(Int(progress * 100)) %"
        case let .message(message): message
        case .hidden: coordinator.modelDirectory == nil ? mText("Hämta svenska för att börja", "Download Swedish to begin") : mText("Redo att lyssna", "Ready to listen")
        }
    }

    private var history: some View {
        VStack(spacing: 24) {
            if coordinator.modelDirectory == nil { modelDownload }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(MumlaStyle.secondary)
                TextField(mText("Sök dikteringar", "Search dictations"), text: $query).textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel(mText("Rensa", "Clear"))
                }
            }.padding(13).mumlaSurface(radius: 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if records.isEmpty {
                        MumlaEmptyState(query.isEmpty ? mText("Inga dikteringar än", "No dictations yet") : mText("Inga träffar", "No results"), symbol: "text.alignleft")
                            .frame(minHeight: 220)
                    }
                    ForEach(records) { record in
                        Button {
                            copied = false
                            selectedRecord = record
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    Spacer()
                                    Text(record.language == .swedish ? "SV" : "EN")
                                    Image(systemName: "arrow.up.right").padding(.leading, 12)
                                }.font(.system(size: 11)).foregroundStyle(MumlaStyle.secondary)
                                Text(record.text).font(.system(size: 15)).lineSpacing(4).lineLimit(3).multilineTextAlignment(.leading)
                            }
                            .padding(.vertical, 20).padding(.horizontal, 2)
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider().opacity(0.6)
                    }
                }
            }.scrollIndicators(.hidden)
        }
    }

    private var dictionary: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                TextField(mText("Ersätt", "Replace"), text: $original).textFieldStyle(.plain)
                Image(systemName: "arrow.right").foregroundStyle(MumlaStyle.secondary)
                TextField(mText("Med", "With"), text: $replacement).textFieldStyle(.plain)
                MumlaIconButton("plus", label: mText("Lägg till ord", "Add word")) {
                    coordinator.addDictionaryEntry(original: original, replacement: replacement)
                    original = ""; replacement = ""
                }.disabled(original.trimmingCharacters(in: .whitespaces).isEmpty || replacement.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(14).mumlaRecess(radius: 10)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if coordinator.dictionaryEntries.isEmpty {
                        MumlaEmptyState(mText("Din ordlista är tom", "Your dictionary is empty"), symbol: "text.book.closed").frame(minHeight: 200)
                    }
                    ForEach(coordinator.dictionaryEntries) { entry in
                        HStack(spacing: 20) {
                            Text(entry.original).foregroundStyle(MumlaStyle.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.right").foregroundStyle(MumlaStyle.secondary)
                            Text(entry.replacement).fontWeight(.medium).frame(maxWidth: .infinity, alignment: .leading)
                            Button { coordinator.deleteDictionaryEntry(entry) } label: { Image(systemName: "trash").frame(width: 32, height: 32) }
                                .buttonStyle(.plain).help(mText("Ta bort", "Delete"))
                        }.padding(.vertical, 14)
                        Divider().opacity(0.6)
                    }
                }
            }
        }
    }

    private var settings: some View {
        ScrollView {
            VStack(spacing: 0) {
                settingRow(mText("Språk", "Language"), symbol: "globe") {
                    Picker("", selection: Binding(get: { coordinator.languageMode }, set: { coordinator.setLanguageMode($0) })) {
                        Text("Auto").tag(LanguageMode.automatic)
                        Text("Svenska").tag(LanguageMode.swedish)
                        Text("English").tag(LanguageMode.english)
                    }.labelsHidden().frame(width: 170)
                }
                settingRow(mText("Mikrofon", "Microphone"), symbol: "mic") {
                    Button(mText("Tillåt", "Allow")) { Task { await coordinator.requestMicrophonePermission() } }
                }
                settingRow(mText("Hjälpmedel", "Accessibility"), symbol: "hand.point.up.left") {
                    Button(AccessibilityPermission.isTrusted ? mText("Tillåtet", "Allowed") : mText("Öppna inställningar", "Open Settings")) { coordinator.requestAccessibilityPermission() }
                }
                settingRow(mText("Starta vid inloggning", "Launch at login"), symbol: "power") {
                    Toggle("", isOn: Binding(get: { coordinator.isLaunchAtLoginRequested }, set: { coordinator.setLaunchAtLoginEnabled($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                settingRow(mText("Introduktion", "Introduction"), symbol: "sparkles") {
                    Button(mText("Visa", "Show")) { coordinator.showOnboarding() }
                }
                settingRow(mText("Språkmodell", "Language model"), symbol: "waveform") {
                    if coordinator.modelDirectory != nil {
                        Label(mText("Installerad", "Installed"), systemImage: "checkmark.circle").foregroundStyle(MumlaStyle.secondary)
                    } else {
                        Button(mText("Hämta", "Download")) { coordinator.installModel() }.disabled(coordinator.isInstallingModel)
                    }
                }
                if coordinator.isInstallingModel { ProgressView(value: coordinator.modelInstallProgress.fraction).padding(.top, 16) }
                Text(coordinator.statusText).font(.caption).foregroundStyle(MumlaStyle.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 24)
            }.buttonStyle(.bordered)
        }
    }

    private var modelDownload: some View {
        HStack(spacing: 18) {
            Image(systemName: "arrow.down.circle").font(.system(size: 26, weight: .light)).foregroundStyle(MumlaStyle.accent)
            VStack(alignment: .leading, spacing: 6) {
                Text(coordinator.isInstallingModel ? mText("Förbereder svenska", "Preparing Swedish") : mText("Hämta svenska", "Download Swedish")).font(.headline)
                if coordinator.isInstallingModel {
                    ProgressView(value: coordinator.modelInstallProgress.fraction).frame(maxWidth: 260)
                } else { Text("688 MB").font(.caption).foregroundStyle(MumlaStyle.secondary) }
            }
            Spacer()
            Button { coordinator.installModel() } label: {
                Image(systemName: "arrow.down").frame(width: 36, height: 36)
            }.buttonStyle(.plain).mumlaSurface(radius: 8).disabled(coordinator.isInstallingModel)
                .help(mText("Hämta språkmodell", "Download language model"))
        }.padding(22).mumlaSurface(radius: 12)
    }

    private func settingRow<Content: View>(_ title: String, symbol: String, @ViewBuilder accessory: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 22).foregroundStyle(MumlaStyle.secondary)
                Text(title)
                Spacer()
                accessory()
            }.frame(minHeight: 66)
            Divider().opacity(0.6)
        }
    }
    private var records: [DictationRecord] { coordinator.history.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) } }
    private var subtitle: String {
        switch selection {
        case .dictate: mText("PÅ DEN HÄR MACEN", "ON THIS MAC")
        case .history: "\(coordinator.history.count) " + mText("dikteringar", "dictations")
        case .dictionary: "\(coordinator.dictionaryEntries.count) " + mText("sparade ord", "saved words")
        case .settings: mText("Ditt Mumla", "Your Mumla")
        }
    }
}

private enum MainSection: CaseIterable, Identifiable {
    case dictate, history, dictionary, settings
    var id: Self { self }
    var title: String {
        switch self {
        case .dictate: mText("Diktera", "Dictate")
        case .history: mText("Historik", "History")
        case .dictionary: mText("Ordlista", "Dictionary")
        case .settings: mText("Inställningar", "Settings")
        }
    }
    var symbol: String {
        switch self {
        case .dictate: "record.circle"
        case .history: "clock"
        case .dictionary: "text.book.closed"
        case .settings: "slider.horizontal.3"
        }
    }
}

private struct OnboardingView: View {
    @ObservedObject var coordinator: AppCoordinator
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                MumlaWordmark()
                Spacer()
                Text("\(coordinator.onboardingStep.rawValue + 1) / 5").font(.caption).foregroundStyle(MumlaStyle.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.system(size: 30, weight: .semibold))
                Text(detail).font(.system(size: 15)).foregroundStyle(MumlaStyle.secondary).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            HStack {
                Button(mText("Senare", "Later")) { coordinator.completeOnboarding() }.buttonStyle(.plain).foregroundStyle(MumlaStyle.secondary)
                Spacer()
                Button { advance() } label: {
                    Label(mText("Fortsätt", "Continue"), systemImage: "arrow.right").padding(.horizontal, 16).frame(height: 42)
                }.buttonStyle(.plain).mumlaSurface(radius: 8)
            }
        }.padding(36).frame(width: 470).background { MumlaBackdrop() }
    }
    private var title: String {
        switch coordinator.onboardingStep {
        case .value: mText("Dina ord. På din Mac.", "Your words. On your Mac.")
        case .microphone: mText("Din mikrofon", "Your microphone")
        case .accessibility: mText("Skriv där du är", "Write where you are")
        case .practice: mText("Prova Mumla", "Try Mumla")
        case .done: mText("Vi hörs.", "Ready when you are.")
        }
    }
    private var detail: String {
        switch coordinator.onboardingStep {
        case .value: mText("Privat diktering. Ljud och text stannar hos dig.", "Private dictation. Your audio and text stay with you.")
        case .microphone: mText("Ge Mumla tillgång till mikrofonen för att diktera.", "Give Mumla microphone access to dictate.")
        case .accessibility: mText("Tillåt Hjälpmedel för att klistra in i andra appar.", "Allow Accessibility to paste into other apps.")
        case .practice: mText("Håll Ctrl för att tala. Släpp för att skriva.", "Hold Ctrl to speak. Release to write.")
        case .done: mText("Mumla finns i menyraden. Hämta svenska för att börja.", "Mumla lives in the menu bar. Download Swedish to begin.")
        }
    }
    private func advance() {
        switch coordinator.onboardingStep {
        case .microphone: Task { await coordinator.requestMicrophonePermission(); coordinator.advanceOnboarding() }
        case .accessibility: coordinator.requestAccessibilityPermission(); coordinator.advanceOnboarding()
        case .practice: coordinator.showPracticePill(); coordinator.advanceOnboarding()
        case .done: coordinator.completeOnboarding()
        case .value: coordinator.advanceOnboarding()
        }
    }
}
