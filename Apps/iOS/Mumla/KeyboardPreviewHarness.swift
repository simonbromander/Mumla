#if DEBUG
import MumlaCore
import MumlaUI
import SwiftUI

struct KeyboardPreviewHarness: View {
    @State private var snapshot: KeyboardSessionSnapshot = {
        var state = KeyboardSessionSnapshot()
        state.sessionID = UUID(); state.phase = .ready; state.heartbeat = Date()
        state.expiresAt = Date().addingTimeInterval(900); state.appearance = "light"
        return state
    }()
    @State private var fullAccess = true
    @State private var output = ""
    @State private var preview: String?
    @State private var samples = Array(repeating: 0.0, count: 43)
    var body: some View {
        VStack(spacing: 16) {
            Text("Mumla keyboard / UI test").font(.system(.headline, design: .monospaced))
            HStack {
                Button("Light") { snapshot.appearance = "light" }
                Button("Dark") { snapshot.appearance = "dark" }
                Button("Access") { fullAccess.toggle() }
                Button("Clear") { output = "" }
            }.buttonStyle(.bordered).font(.system(.caption, design: .monospaced))
            Text(output.isEmpty ? " " : output).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("keyboard.output").padding(20)
            Spacer(minLength: 0)
            MumlaKeyboardView(snapshot: snapshot, fullAccess: fullAccess, preview: preview, samples: samples,
                nextKeyboard: AnyView(Button {} label: { Image(systemName: "globe") }.accessibilityLabel("Next keyboard")),
                onRecord: {
                    if snapshot.phase == .recording { snapshot.phase = .result; preview = "Vi ses klockan nio." }
                    else {
                        snapshot.heartbeat = Date(); snapshot.phase = .recording; snapshot.recordingStartedAt = Date()
                        samples = (0..<43).map { 0.15 + abs(sin(Double($0) * 0.77)) * 0.65 }
                    }
                }, onCancel: { snapshot.phase = .ready; snapshot.recordingStartedAt = nil; preview = nil },
                onInsert: { output += preview ?? ""; preview = nil; snapshot.phase = .ready },
                onEnd: { snapshot = .init() }, onKey: { output += $0 },
                onDelete: { if !output.isEmpty { output.removeLast() } }, onReturn: { output += "\n" })
                .frame(height: UIDevice.current.orientation.isLandscape ? (preview == nil ? 266 : 306) : (preview == nil ? 344 : 384))
        }
        .padding(.top, 16).background(MumlaStyle.background)
        .preferredColorScheme(MumlaAppearance(rawValue: snapshot.appearance)?.colorScheme)
        .task {
            while !Task.isCancelled {
                snapshot.heartbeat = Date()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
}

struct KeyboardHostHarness: View {
    @State private var text = ""
    @FocusState private var focused: Bool
    private var literal: Bool { CommandLine.arguments.contains("--keyboard-literal-field") }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Mumla / keyboard host").font(.system(.headline, design: .monospaced))
            TextEditor(text: $text).focused($focused)
                .textInputAutocapitalization(literal ? .never : .sentences)
                .autocorrectionDisabled(literal)
                .keyboardType(literal ? .URL : .default)
                .accessibilityIdentifier("keyboard.hostField")
        }.padding(20).onAppear { focused = true }
            .task {
                guard (CommandLine.arguments.contains("--keyboard-session-fixture") || CommandLine.arguments.contains("--keyboard-stale-session-fixture")),
                      let store = KeyboardSessionStore.shared() else { return }
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MumlaUITests", isDirectory: true)
                let history = DictationHistoryStore(directory: directory)
                var state = KeyboardSessionSnapshot()
                state.sessionID = UUID(); state.phase = .ready; state.expiresAt = Date().addingTimeInterval(300)
                state.appearance = "light"
                if CommandLine.arguments.contains("--keyboard-stale-session-fixture") {
                    state.heartbeat = Date().addingTimeInterval(-10)
                    try? store.write(state)
                    return
                }
                var documentID: UUID?
                defer { try? store.write(KeyboardSessionSnapshot()); try? store.clearResult() }
                do {
                    try store.clearResult()
                    while !Task.isCancelled {
                        state.heartbeat = Date()
                        if let command = try store.command(), state.accepts(command) {
                            state.acknowledgedCommandID = command.id
                            switch command.action {
                            case .start:
                                state.phase = .recording; state.recordingStartedAt = Date(); state.requestID = command.id
                                documentID = command.documentID
                            case .stop:
                                guard let sessionID = state.sessionID, let requestID = state.requestID else { return }
                                let record = DictationRecord(text: "Hej från Mumla.", language: .swedish)
                                _ = try history.append(record)
                                try store.publish(KeyboardSessionResult(id: record.id, sessionID: sessionID,
                                    requestID: requestID, documentID: documentID, text: record.text))
                                state.phase = .result; state.resultID = record.id
                            case .cancel, .consume:
                                try store.clearResult(); state.phase = .ready; state.resultID = nil
                                state.requestID = nil; state.recordingStartedAt = nil
                            case .end: return
                            case .retry: break
                            }
                        }
                        try store.write(state)
                        try await Task.sleep(for: .milliseconds(150))
                    }
                } catch { return }
            }
    }
}
#endif
