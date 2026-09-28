import MumlaCore
import MumlaUI
import SwiftUI

struct MumlaHomeView: View {
    @StateObject private var session = DictationSession()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = HomeTab.dictate
    @State private var showSettings = false
    @State private var showAddWord = false
    @State private var query = ""

    var body: some View {
        ZStack {
            MumlaBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        MumlaWordmark()
                        Spacer()
                        MumlaIconButton("slider.horizontal.3", label: mText("Inställningar", "Settings")) { showSettings = true }
                    }
                    switch tab {
                    case .dictate: dictate
                    case .history: history
                    case .dictionary: dictionary
                    }
                }
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 24)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }.scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .tint(MumlaStyle.accent)
        .preferredColorScheme(.dark)
        .onChange(of: tab) { _, _ in MumlaFeedback.selection() }
        .onChange(of: session.error) { _, error in if error != nil { MumlaFeedback.error() } }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: tab)
        .sheet(isPresented: $showSettings) { MumlaSettingsSheet(session: session) }
        .sheet(isPresented: $showAddWord) { AddWordSheet(session: session) }
        .sheet(item: $session.selectedRecord) { record in TranscriptSheet(record: record, session: session) }
        .alert("Mumla", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
            Button("OK", role: .cancel) { session.error = nil }
        } message: { Text(session.error ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && session.state == .recording { Task { await session.finish() } }
        }
    }

    private var dictate: some View {
        VStack(alignment: .leading, spacing: 22) {
            recorder
            if !session.modelReady { modelDownload }
            if session.hasPendingAudio && session.state == .idle {
                Button { Task { await session.transcribePending() } } label: {
                    Label(mText("Fortsätt sparad inspelning", "Resume saved recording"), systemImage: "arrow.clockwise")
                }
            }
            HStack {
                Text(mText("Senaste", "Recent")).font(.headline)
                Spacer()
                if !session.history.isEmpty {
                    Button { tab = .history } label: { Image(systemName: "arrow.right").frame(width: 44, height: 32) }
                        .accessibilityLabel(mText("Visa historik", "Show history"))
                }
            }.padding(.top, 4)
            if session.history.isEmpty {
                MumlaEmptyState(mText("Inga dikteringar än", "No dictations yet"), symbol: "text.alignleft").padding(.top, -24)
            } else {
                ForEach(session.history.prefix(2)) { record in TranscriptRow(record: record) { session.selectedRecord = record } }
            }
        }
    }

    private var recorder: some View {
        VStack(spacing: 14) {
            MumlaRecorderDisplay(
                status: displayStatus,
                detail: recordingTitle,
                elapsed: session.elapsed,
                recording: session.state == .recording
            )
            MumlaInputMeter(level: session.samples.last ?? 0, active: session.state == .recording)
            HStack(alignment: .center, spacing: 12) {
                MumlaTransportKey("xmark", title: mText("Avbryt", "Cancel")) { session.cancel() }
                    .disabled(session.state != .recording)
                MumlaTransportKey(
                    session.state == .recording ? "stop.fill" : "circle.fill",
                    title: session.state == .recording ? mText("Stoppa", "Stop") : mText("Spela in", "Record"),
                    primary: true, active: session.state == .recording,
                    busy: session.state == .transcribing || session.state == .requestingPermission
                ) {
                    Task {
                        if session.state == .recording { await session.finish() }
                        else { await session.record() }
                    }
                }
                .disabled(!session.modelReady || session.state == .transcribing || session.state == .requestingPermission || session.hasPendingAudio)
                MumlaTransportKey("text.alignleft", title: mText("Senaste", "Latest")) {
                    MumlaFeedback.press()
                    session.selectedRecord = session.history.first
                }.disabled(session.history.isEmpty)
            }
            .padding(.horizontal, 10).padding(.vertical, 20).mumlaSurface(radius: 16)
            if session.elapsed >= 540 && session.state == .recording {
                Text(mText("Stoppas automatiskt vid 10 minuter", "Automatically stops at 10 minutes"))
                    .font(.caption).foregroundStyle(MumlaStyle.recording)
            }
        }
    }

    private var modelDownload: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle").font(.title2).foregroundStyle(MumlaStyle.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.isInstalling ? mText("Förbereder svenska", "Preparing Swedish") : mText("Hämta svenska", "Download Swedish")).font(.subheadline.weight(.medium))
                    Text(session.isInstalling ? "\(Int(session.progress.fraction * 100)) %" : session.downloadSize).font(.caption).foregroundStyle(MumlaStyle.secondary)
                }
                Spacer()
                if !session.isInstalling {
                    Button { Task { await session.install() } } label: { Image(systemName: "arrow.down").frame(width: 44, height: 44) }
                        .buttonStyle(MumlaKeyStyle())
                        .accessibilityLabel(mText("Hämta språkmodell", "Download language model"))
                }
            }
            if session.isInstalling { ProgressView(value: session.progress.fraction) }
        }.padding(.horizontal, 2)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading(mText("Historik", "History"), count: session.history.count)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(MumlaStyle.secondary)
                TextField(mText("Sök dikteringar", "Search dictations"), text: $query).textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel(mText("Rensa sökning", "Clear search"))
                }
            }.padding(16).mumlaRecess(radius: 10)
            if filteredHistory.isEmpty {
                MumlaEmptyState(query.isEmpty ? mText("Inga dikteringar än", "No dictations yet") : mText("Inga träffar", "No results"), symbol: "text.magnifyingglass")
            }
            ForEach(filteredHistory) { record in TranscriptRow(record: record) { session.selectedRecord = record } }
        }
    }

    private var dictionary: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                sectionHeading(mText("Dina ord", "Your words"), count: session.dictionary.count)
                Spacer()
                MumlaIconButton("plus", label: mText("Lägg till ord", "Add word")) { showAddWord = true }
            }
            if session.dictionary.isEmpty {
                MumlaEmptyState(mText("Din ordlista är tom", "Your dictionary is empty"), symbol: "text.book.closed")
            }
            ForEach(session.dictionary) { entry in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.replacement).font(.headline)
                        Text(entry.original).font(.subheadline).foregroundStyle(MumlaStyle.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) { session.deleteWord(entry) } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                        .accessibilityLabel(mText("Ta bort", "Delete") + " " + entry.replacement)
                }.padding(.vertical, 8)
                Divider()
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 7) {
            ForEach(HomeTab.allCases) { item in
                Button { tab = item } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.symbol).font(.system(size: 15, weight: .medium))
                        Text(item.title).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(tab == item ? MumlaStyle.accent : MumlaStyle.secondary)
                    .frame(maxWidth: .infinity).frame(minHeight: 48)
                    .overlay(alignment: .bottom) {
                        if tab == item { Capsule().fill(MumlaStyle.accent).frame(width: 12, height: 2).padding(.bottom, 5) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MumlaKeyStyle(feedback: false))
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(8).mumlaRecess(radius: 13).frame(maxWidth: 520)
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 10)
        .background(MumlaStyle.background)
    }

    private func sectionHeading(_ title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 32, weight: .semibold))
            Text("\(count) " + mText("sparade", "saved")).font(.subheadline).foregroundStyle(MumlaStyle.secondary)
        }
    }
    private var filteredHistory: [DictationRecord] { session.history.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) } }
    private var displayStatus: String {
        if session.isInstalling { return mText("HÄMTAR", "LOADING") }
        switch session.state {
        case .recording: return "REC"
        case .transcribing: return mText("BEARBETAR", "PROCESSING")
        case .requestingPermission: return mText("MIKROFON", "MICROPHONE")
        case .idle: return session.modelReady ? "STANDBY" : mText("EJ REDO", "NOT READY")
        }
    }
    private var recordingTitle: String {
        if session.isInstalling { return mText("Förbereder svenska", "Preparing Swedish") + " \(Int(session.progress.fraction * 100)) %" }
        switch session.state {
        case .recording: return mText("Lyssnar", "Listening")
        case .transcribing: return mText("Skriver dina ord", "Transcribing")
        case .requestingPermission: return mText("Väntar på mikrofonen", "Waiting for microphone")
        case .idle: return session.modelReady ? mText("Redo att lyssna", "Ready to listen") : mText("Hämta svenska för att börja", "Download Swedish to begin")
        }
    }
}

private enum HomeTab: String, CaseIterable, Identifiable {
    case dictate, history, dictionary
    var id: Self { self }
    var title: String {
        switch self {
        case .dictate: mText("Diktera", "Dictate")
        case .history: mText("Historik", "History")
        case .dictionary: mText("Ordlista", "Dictionary")
        }
    }
    var symbol: String {
        switch self {
        case .dictate: "waveform"
        case .history: "clock"
        case .dictionary: "text.book.closed"
        }
    }
}

private struct TranscriptRow: View {
    var record: DictationRecord
    var open: () -> Void
    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }.font(.caption).foregroundStyle(MumlaStyle.secondary)
                Text(record.text).font(.system(size: 16)).lineSpacing(4).lineLimit(3).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(20).mumlaSurface(radius: 10)
        }.buttonStyle(.plain)
    }
}
