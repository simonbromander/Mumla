import SwiftUI
import MumlaCore

@main
struct MumlaWatchApp: App {
    @StateObject private var recorder = WatchRecorder()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            WatchRecorderView(recorder: recorder)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { recorder.background() }
                    if phase == .active { recorder.activate() }
                }
        }
    }
}

struct WatchRecorderView: View {
    @ObservedObject var recorder: WatchRecorder
    @State private var deleteRecovery = false
    @State private var deleteNote: VoiceNote?
    private let lcd = Color(red: 0.72, green: 0.79, blue: 0.62)
    private let orange = Color(red: 0.94, green: 0.31, blue: 0.12)
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(recorder.recording ? "REC" : recorder.busy ? "TRANSCRIBING" : "VOICE NOTE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text(String(format: "%02d:%02d", Int(recorder.elapsed) / 60, Int(recorder.elapsed) % 60))
                            .font(.system(size: 32, weight: .light, design: .monospaced)).monospacedDigit()
                        Text(recorder.recording ? "60 SECOND LIMIT" : "ON THIS WATCH")
                            .font(.system(size: 9, design: .monospaced))
                    }.foregroundStyle(Color.black.opacity(0.85)).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(lcd, in: RoundedRectangle(cornerRadius: 8))
                    Button {
                        if recorder.recording { recorder.stop() } else { Task { await recorder.start() } }
                    } label: {
                        Label(recorder.recording ? "Stop & save" : "Record", systemImage: recorder.recording ? "stop.fill" : "mic.fill")
                            .font(.system(.body, design: .monospaced).weight(.semibold)).frame(minHeight: 32)
                    }.tint(orange).buttonStyle(.borderedProminent)
                        .disabled(recorder.busy || recorder.installing).accessibilityIdentifier("watch.record")
                    if recorder.busy { ProgressView("Transcribing locally"); Button("Cancel") { recorder.cancelOperation() } }
                    if !recorder.modelReady {
                        if recorder.installing {
                            ProgressView(value: recorder.progress)
                            Text("Downloading speech model").font(.caption2)
                            Text("Keep Mumla open during download.").font(.caption2).foregroundStyle(.secondary)
                            Button("Cancel download") { recorder.cancelOperation() }
                        } else {
                            Text("Download once: 150 MB. Audio stays on your Watch until sent to your iPhone.")
                                .font(.caption2).foregroundStyle(.secondary)
                            Button("Download speech model") { recorder.install() }
                                .disabled(recorder.recording || recorder.busy)
                        }
                    }
                    if !recorder.recording && !recorder.busy && !recorder.installing {
                        Picker("Language", selection: $recorder.language) {
                            Text("Swedish").tag("sv")
                            Text("English").tag("en")
                        }.pickerStyle(.navigationLink)
                    }
                    if let error = recorder.error {
                        Text(error).font(.caption2).foregroundStyle(.orange)
                        if recorder.hasRecovery {
                            Button("Retry saving recording") { recorder.recoverCapture() }
                                .disabled(recorder.recording || recorder.busy)
                            Button("Discard interrupted recording", role: .destructive) { deleteRecovery = true }
                        }
                    }
                    ForEach(recorder.notes) { note in
                        NavigationLink {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(note.transcript ?? "Recording saved. Transcription pending.")
                                    Text(note.delivered ? "Saved on iPhone" : "Waiting to send to iPhone").font(.caption2).foregroundStyle(.secondary)
                                    if recorder.busy {
                                        ProgressView("Transcribing locally")
                                        Button("Cancel transcription") { recorder.cancelOperation() }
                                    }
                                    if let error = recorder.error { Text(error).font(.caption2).foregroundStyle(.orange) }
                                    if note.transcript == nil {
                                        Button("Transcribe on Watch") { recorder.retry(note.id) }
                                            .disabled(recorder.busy || recorder.recording || recorder.installing)
                                    } else { Button("Send again") { recorder.sendAgain() } }
                                    Button("Delete from Watch", role: .destructive) { deleteNote = note }
                                        .disabled(recorder.busy || recorder.recording || recorder.installing)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.transcript ?? "Transcription pending").lineLimit(2)
                                Text(note.createdAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                                Label(note.delivered ? "Saved on iPhone" : "On Watch", systemImage: note.delivered ? "checkmark" : "applewatch")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink("Open-source licenses") {
                        ScrollView {
                            Text((Bundle.main.url(forResource: "Watch-Licenses", withExtension: "txt")
                                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }) ?? "License resource unavailable.")
                                .font(.caption2)
                        }.navigationTitle("Licenses")
                    }.font(.caption2)
                }.padding(.horizontal, 4)
            }.navigationTitle("mumla").fontDesign(.monospaced)
        }.tint(orange)
            .confirmationDialog("Discard this interrupted recording?", isPresented: $deleteRecovery, titleVisibility: .visible) {
                Button("Discard recording", role: .destructive) { recorder.discardRecovery() }
            }
            .confirmationDialog("Delete this recording and text from the Watch?", isPresented: Binding(
                get: { deleteNote != nil }, set: { if !$0 { deleteNote = nil } }), titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        if let note = deleteNote { recorder.delete(note.id) }; deleteNote = nil
                    }
            }
    }
}
