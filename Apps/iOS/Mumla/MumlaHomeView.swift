import MumlaCore
import MumlaUI
import SwiftUI

struct MumlaHomeView: View {
    @StateObject private var session = DictationSession()
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = HomeTab.dictate
    @State private var pressedTab: HomeTab?
    @State private var showSettings = false
    @State private var showAddWord = false
    @State private var query = ""

    var body: some View {
        ZStack {
            MumlaBackdrop()
            VStack(spacing: 12) {
                HStack {
                    MumlaWordmark()
                    Spacer()
                    if tab == .dictate && !session.modelReady {
                        MumlaIconButton("arrow.down", label: mText("Hämta språkmodell", "Download language model")) {
                            Task { await session.install() }
                        }.disabled(session.isInstalling)
                    }
                    MumlaIconButton("slider.horizontal.3", label: mText("Inställningar", "Settings")) { showSettings = true }
                }.frame(height: 44)
                if tab == .dictate {
                    dictate
                } else {
                    ScrollView {
                        Group {
                            if tab == .history { history } else { dictionary }
                        }.padding(.bottom, 16)
                    }.scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 8)
            .frame(maxWidth: tab == .dictate ? 900 : 640).frame(maxWidth: .infinity)

        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(MumlaStyle.background)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .tint(MumlaStyle.accent)
        .preferredColorScheme(.dark)
        .font(.system(.body, design: .monospaced)).fontDesign(.monospaced)
        .onChange(of: tab) { _, _ in MumlaFeedback.latch() }
        .onChange(of: session.error) { _, error in if error != nil { MumlaFeedback.error() } }
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
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height * 1.3
            let compact = geometry.size.height < 560
            Group {
                if wide {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(spacing: 10) {
                            display(compact: true)
                            MumlaInputMeter(level: session.samples.last ?? 0, active: session.state == .recording, compact: true)
                        }
                        VStack(spacing: 12) {
                            transport(compact: true)
                            latestTranscript
                        }
                    }
                } else {
                    VStack(spacing: compact ? 12 : 18) {
                        display(compact: compact)
                        MumlaInputMeter(level: session.samples.last ?? 0, active: session.state == .recording, compact: compact)
                        Spacer(minLength: 0)
                        transport(compact: compact)
                        latestTranscript
                    }.frame(maxWidth: 640, maxHeight: 630)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func display(compact: Bool) -> some View {
        MumlaRecorderDisplay(
            status: displayStatus,
            detail: session.elapsed >= 540 && session.state == .recording
                ? mText("Stopp vid 10 minuter", "Stops at 10 minutes") : recordingTitle,
            elapsed: session.elapsed,
            recording: session.state == .recording,
            compact: compact
        )
    }

    private func transport(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            MumlaTransportKey("xmark", title: mText("Avbryt", "Cancel"), compact: compact) { session.cancel() }
                .disabled(session.state != .recording)
            MumlaTransportKey(
                session.state == .recording ? "stop.fill" : session.hasPendingAudio ? "arrow.clockwise" : "circle.fill",
                title: session.state == .recording ? mText("Stoppa", "Stop") : session.hasPendingAudio ? mText("Fortsätt", "Resume") : mText("Spela in", "Record"),
                primary: true, active: session.state == .recording,
                busy: session.state == .transcribing || session.state == .requestingPermission,
                compact: compact
            ) {
                Task {
                    if session.state == .recording { await session.finish() }
                    else if session.hasPendingAudio { await session.transcribePending() }
                    else { await session.record() }
                }
            }
            .disabled(!session.modelReady || session.state == .transcribing || session.state == .requestingPermission)
            .accessibilityIdentifier("recorder.record")
            MumlaTransportKey("text.alignleft", title: mText("Senaste", "Latest"), compact: compact) {
                MumlaFeedback.press()
                session.selectedRecord = session.history.first
            }
            .disabled(session.history.isEmpty)
            .accessibilityIdentifier("showLatestTranscript")
        }
        .padding(.horizontal, 10).padding(.vertical, compact ? 12 : 20).mumlaSurface(radius: 16)
    }

    private var latestTranscript: some View {
        MumlaTranscriptStrip(
            preview: session.history.first?.compactPreview,
            text: session.history.first?.text,
            copied: session.history.first.map { session.copiedID == $0.id } ?? false
        ) {
            if let record = session.history.first { session.copy(record) }
        }
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
                        Text(entry.replacement).font(.system(.headline, design: .monospaced))
                        Text(entry.original).font(.system(.subheadline, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) { session.deleteWord(entry) } label: {
                        Image(systemName: "trash").font(.system(size: 18, design: .monospaced)).frame(width: 44, height: 44)
                    }
                        .buttonStyle(MumlaKeyStyle())
                        .accessibilityLabel(mText("Ta bort", "Delete") + " " + entry.replacement)
                }.padding(.vertical, 8)
                Divider()
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 5) {
            ForEach(HomeTab.allCases) { item in
                Button { tab = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.system(size: 16, weight: .medium, design: .monospaced))
                        if verticalSizeClass != .compact {
                            Text(item.title.uppercased()).font(.system(size: 10, weight: .medium, design: .monospaced))
                                .lineLimit(1).minimumScaleFactor(0.85)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MumlaStereoKeyStyle(isLatched: (pressedTab ?? tab) == item, height: verticalSizeClass == .compact ? 48 : 72) { pressed in
                    if pressed {
                        MumlaFeedback.press()
                        pressedTab = item
                        if tab != item { MumlaFeedback.prepareLatch() }
                    } else if pressedTab == item {
                        pressedTab = nil
                    }
                })
                .accessibilityLabel(item.title)
                .accessibilityIdentifier("tab.\(item.rawValue)")
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(8).mumlaRecess(radius: 13).frame(maxWidth: 520)
        .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 6)
        .background(MumlaStyle.background)
    }

    private func sectionHeading(_ title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 32, weight: .semibold, design: .monospaced))
            Text("\(count) " + mText("sparade", "saved")).font(.system(.subheadline, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
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
                }.font(.system(.caption, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                Text(record.text).font(.system(size: 16, design: .monospaced)).lineSpacing(4).lineLimit(3).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(20).mumlaSurface(radius: 10)
        }.buttonStyle(.plain)
    }
}
