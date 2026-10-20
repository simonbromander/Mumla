import AVFAudio
import Combine
import MumlaCore
import MumlaUI
import SwiftUI

@MainActor
final class VoiceNotes: ObservableObject {
    @Published private(set) var notes: [VoiceNote] = []
    @Published var error: String?
    let store: VoiceNoteStore
    private var connectivity: VoiceNoteConnectivity?

    init() {
        #if DEBUG
        if CommandLine.arguments.contains("--ui-testing") {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MumlaVoiceNotesUITests")
            if CommandLine.arguments.contains("--reset-ui-data") { try? FileManager.default.removeItem(at: directory) }
            store = VoiceNoteStore(directory: directory)
            if CommandLine.arguments.contains("--seed-voice-notes") { seedFixture() }
        } else { store = .defaultStore() }
        #else
        store = .defaultStore()
        #endif
        refresh()
        #if DEBUG
        if CommandLine.arguments.contains("--ui-testing") { return }
        #endif
        connectivity = VoiceNoteConnectivity(store: store) { [weak self] message in
            Task { @MainActor in self?.refresh(message) }
        }
    }

    func refresh(_ message: String? = nil) {
        do { notes = try store.load() } catch { self.error = error.localizedDescription }
        if let message { error = message }
    }

    func delete(_ note: VoiceNote) {
        do { try store.delete(id: note.id); refresh() } catch { self.error = error.localizedDescription }
    }

    #if DEBUG
    private func seedFixture() {
        do {
            try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
            let url = store.directory.appendingPathComponent("fixture.wav")
            let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
            try autoreleasepool {
                let audio = try AVAudioFile(forWriting: url, settings: format.settings)
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160_000)!
                buffer.frameLength = 160_000
                buffer.floatChannelData![0].initialize(repeating: 0, count: 160_000)
                try audio.write(from: buffer)
            }
            let note = try store.saveRecording(from: url, duration: 10, language: "sv")
            try store.setTranscript("Vi ses klockan två. Kom ihåg att boka mötesrummet.", for: note.id)
            try FileManager.default.removeItem(at: url)
        } catch { self.error = error.localizedDescription }
    }
    #endif
}

struct VoiceNotesSection: View {
    @ObservedObject var inbox: VoiceNotes
    var playbackAllowed: Bool
    @State private var query = ""
    @State private var selected: VoiceNote?
    private var filtered: [VoiceNote] {
        inbox.notes.filter { query.isEmpty || ($0.transcript ?? "").localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(mText("Röstanteckningar", "Voice Notes"))
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .accessibilityAddTraits(.isHeader)
                Label(mText("Från din Apple Watch", "From your Apple Watch"), systemImage: "applewatch")
                    .font(.subheadline).foregroundStyle(MumlaStyle.secondary)
            }
            if let error = inbox.error {
                VStack(alignment: .leading, spacing: 10) {
                    Text(error)
                    Button(mText("Försök igen", "Try again")) { inbox.error = nil; inbox.refresh() }
                }.padding(16).mumlaSurface(radius: 10)
            }
            if inbox.notes.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "waveform").font(.system(size: 30)).foregroundStyle(MumlaStyle.secondary)
                    Text(mText("Din nästa tanke börjar på handleden.", "Your next thought starts on your wrist."))
                        .font(.title3.weight(.medium))
                        .accessibilityIdentifier("voiceNotes.empty")
                    Text(mText("Spela in i Mumla på din Apple Watch. Klockan transkriberar lokalt och skickar anteckningen hit när din iPhone är tillgänglig.",
                               "Record in Mumla on your Apple Watch. Your Watch transcribes locally and sends the note here when your iPhone is available."))
                        .foregroundStyle(MumlaStyle.secondary)
                    Text(mText("Upp till 60 sekunder per anteckning.", "Up to 60 seconds per note."))
                        .font(.caption).foregroundStyle(MumlaStyle.secondary)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading).mumlaSurface(radius: 10)
            } else {
                TextField(mText("Sök i röstanteckningar", "Search voice notes"), text: $query)
                    .textFieldStyle(.plain).padding(14).mumlaRecess(radius: 10)
                    .accessibilityIdentifier("voiceNotes.search")
                Text("\(inbox.notes.count) " + mText("sparade", "saved"))
                    .font(.caption).foregroundStyle(MumlaStyle.secondary)
                if filtered.isEmpty { Text(mText("Inga träffar", "No matches")) }
                ForEach(filtered) { note in
                    Button { selected = note } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                Text("\(Int(note.duration.rounded())) s")
                                Image(systemName: "arrow.up.right")
                            }.font(.caption).foregroundStyle(MumlaStyle.secondary)
                            Text(note.transcript ?? "").lineLimit(3).multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(20).mumlaSurface(radius: 10)
                    }.buttonStyle(.plain).accessibilityIdentifier("voiceNotes.note")
                }
            }
        }.padding(.top, 8)
            .sheet(item: $selected) { note in VoiceNoteSheet(note: note, inbox: inbox, playbackAllowed: playbackAllowed) }
    }
}

private struct VoiceNoteSheet: View {
    let note: VoiceNote
    @ObservedObject var inbox: VoiceNotes
    var playbackAllowed: Bool
    @StateObject private var player = VoiceNotePlayer()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmDelete = false
    @State private var copied = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label(note.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "applewatch")
                        .font(.caption).foregroundStyle(MumlaStyle.secondary)
                    HStack {
                        Button {
                            player.toggle(inbox.store.audioURL(for: note.id))
                        } label: {
                            Label(player.playing ? mText("Pausa", "Pause") : mText("Spela upp", "Play recording"),
                                  systemImage: player.playing ? "pause.fill" : "play.fill")
                                .padding(.horizontal, 14).frame(minHeight: 44)
                        }.buttonStyle(MumlaKeyStyle()).accessibilityIdentifier("voiceNotes.play").disabled(!playbackAllowed)
                        Spacer()
                        Text("\(Int(note.duration.rounded())) s").monospacedDigit().foregroundStyle(MumlaStyle.secondary)
                    }
                    if !playbackAllowed { Text(mText("Avsluta dikteringen för att spela upp.", "Finish dictation to play the recording.")).font(.caption) }
                    if let error = player.error { Text(error).foregroundStyle(.red) }
                    Text(note.transcript ?? "").textSelection(.enabled).lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("voiceNotes.transcript")
                    HStack {
                        Button {
                            UIPasteboard.general.string = note.transcript
                            copied = true
                        } label: {
                            Label(copied ? mText("Kopierat", "Copied") : mText("Kopiera", "Copy"), systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                            .accessibilityIdentifier("voiceNotes.copy")
                        Spacer()
                        ShareLink(item: note.transcript ?? "") {
                            Label(mText("Dela text", "Share text"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }.font(.subheadline).buttonStyle(MumlaKeyStyle())
                    ShareLink(item: inbox.store.audioURL(for: note.id)) {
                        Label(mText("Dela inspelning", "Share recording"), systemImage: "waveform")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(MumlaKeyStyle())
                    Button(mText("Radera anteckning", "Delete note"), role: .destructive) { confirmDelete = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("voiceNotes.delete")
                }.padding(24)
            }.background(MumlaStyle.background).navigationTitle(mText("Röstanteckning", "Voice note"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(mText("Klart", "Done")) { dismiss() } } }
                .confirmationDialog(mText("Radera inspelningen och texten från denna iPhone?", "Delete the recording and text from this iPhone?"),
                                    isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button(mText("Radera", "Delete"), role: .destructive) {
                        player.stop(); inbox.delete(note)
                        if !inbox.notes.contains(where: { $0.id == note.id }) { dismiss() }
                    }
                }
        }.fontDesign(.monospaced).tint(MumlaStyle.accent).mumlaAppearance().onDisappear { player.stop() }
            .onChange(of: scenePhase) { _, phase in if phase == .background { player.stop() } }
            .onChange(of: playbackAllowed) { _, allowed in if !allowed { player.stop() } }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in player.stop() }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
                if notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    player.stop()
                }
            }
    }
}

@MainActor
private final class VoiceNotePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playing = false
    @Published var error: String?
    private var player: AVAudioPlayer?
    private var ownsAudioSession = false
    func toggle(_ url: URL) {
        do {
            if player == nil { player = try AVAudioPlayer(contentsOf: url); player?.delegate = self }
            if playing { player?.pause(); playing = false }
            else {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                ownsAudioSession = true
                guard player?.play() == true else { throw VoiceNoteError.invalidAudio }
                playing = true
            }
        } catch { stop(); self.error = mText("Inspelningen kunde inte spelas upp.", "The recording could not play.") }
    }
    func stop() {
        player?.stop(); player = nil; playing = false
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in stop() }
    }
}
