import MumlaCore
import MumlaUI
import SwiftUI

struct KeyboardSetupSheet: View {
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardAudio = false
    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Mumla-tangentbord", "Mumla keyboard"), closeLabel: mText("Klart", "Done")) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Image(systemName: "keyboard").font(.system(size: 28))
                        Spacer()
                        MumlaReadout(session.keyboardSnapshot.isAlive() ? mText("PÅ", "ON") : mText("AV", "OFF"))
                    }
                    Text(mText("Diktera där du skriver.", "Dictate where you write."))
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                    VStack(alignment: .leading, spacing: 16) {
                        step("01", mText("Lägg till Mumla under Inställningar → Allmänt → Tangentbord → Tangentbord.", "Add Mumla in Settings → General → Keyboard → Keyboards."))
                        step("02", mText("Aktivera Full åtkomst för Mumla. Det låter tangentbordet prata med appen på den här enheten. Ingenting skickas till en server.", "Enable Full Access for Mumla. This lets the keyboard communicate with the app on this device. Nothing is sent to a server."))
                        step("03", mText("Starta en session här, gå tillbaka till din app och välj Mumla med jordgloben.", "Start a session here, switch back to your app and choose Mumla with the globe key."))
                    }
                    if session.keyboardSnapshot.isAlive() {
                        Label(mText("Mikrofonen är aktiv tills sessionen avslutas. Ljud sparas bara när du trycker på inspelningsknappen.", "The microphone stays active until the session ends. Audio is saved only while the recording key is on."), systemImage: "mic.fill")
                            .font(.system(.subheadline, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                        Text(session.keyboardSnapshot.expiresAt, style: .time)
                            .font(.system(.headline, design: .monospaced)).accessibilityLabel(mText("Sessionen slutar", "Session ends"))
                    } else {
                        Text(mText("Sessionen varar i 15 minuter. iOS kräver att den startas i Mumla. Vanlig textinmatning fungerar även utan Full åtkomst.", "The session lasts 15 minutes. iOS requires starting it in Mumla. Regular typing works without Full Access."))
                            .font(.system(.subheadline, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                    }
                    if !session.modelReady {
                        Button { Task { await session.install() } } label: {
                            Label(mText("Hämta svenska", "Download Swedish"), systemImage: "arrow.down")
                                .frame(maxWidth: .infinity).padding(16)
                        }.buttonStyle(MumlaKeyStyle()).disabled(session.isInstalling)
                        if session.isInstalling { MumlaDownloadGauge(fraction: session.progress.fraction) }
                    }
                    if session.hasPendingAudio && !session.keyboardSnapshot.isAlive() {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(mText("Osparat klipp", "Unsaved clip"), systemImage: "waveform")
                                .font(.system(.headline, design: .monospaced))
                            Text(mText("Ett tidigare klipp väntar på transkribering. Spara eller radera det innan du startar en ny session.", "A previous clip is waiting for transcription. Save or discard it before starting a new session."))
                                .font(.system(.subheadline, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                            Button { Task { await session.transcribePending() } } label: {
                                Label(mText("Spara transkript", "Save transcript"), systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity).padding(14)
                            }.buttonStyle(MumlaKeyStyle())
                                .disabled(!session.modelReady || session.state != .idle || session.isStartingKeyboard)
                                .accessibilityIdentifier("keyboard.recoverClip")
                            Button(role: .destructive) { showDiscardAudio = true } label: {
                                Label(mText("Radera klipp", "Discard clip"), systemImage: "trash")
                                    .frame(maxWidth: .infinity).padding(14)
                            }.buttonStyle(MumlaKeyStyle())
                                .disabled(session.state != .idle || session.isStartingKeyboard)
                                .accessibilityIdentifier("keyboard.discardClip")
                        }.padding(18).mumlaRecess(radius: 8)
                    }
                    if let error = session.error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.system(.subheadline, design: .monospaced))
                            .accessibilityIdentifier("keyboard.error")
                    }
                    if !session.keyboardSnapshot.isAlive(), let reason = session.keyboardSnapshot.error {
                        Label(reason, systemImage: "exclamationmark.triangle")
                            .font(.system(.subheadline, design: .monospaced))
                            .accessibilityIdentifier("keyboard.connectionError")
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Label(mText("Öppna Inställningar", "Open Settings"), systemImage: "gearshape")
                            .frame(maxWidth: .infinity).padding(16)
                    }.buttonStyle(MumlaKeyStyle()).accessibilityIdentifier("keyboard.settings")
                }.padding(24)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                if session.keyboardSnapshot.isAlive() { session.endKeyboardSession() }
                else { Task { await session.startKeyboardSession() } }
            } label: {
                Label(session.isStartingKeyboard ? mText("Förbereder", "Preparing") : session.keyboardSnapshot.isAlive() ? mText("Avsluta session", "End session") : mText("Starta session", "Start session"),
                      systemImage: session.keyboardSnapshot.isAlive() ? "power" : "mic.fill")
                    .frame(maxWidth: .infinity).padding(18)
            }
            .buttonStyle(MumlaStereoKeyStyle(isLatched: session.keyboardSnapshot.isAlive(), height: 60))
            .disabled(!session.keyboardSnapshot.isAlive() && (!session.modelReady || session.hasPendingAudio || session.state != .idle || session.isStartingKeyboard))
            .accessibilityIdentifier("keyboard.session")
            .padding(24).background(MumlaStyle.background)
        }
        .background { MumlaBackdrop() }.mumlaAppearance()
        .font(.system(.body, design: .monospaced))
        .presentationBackground(MumlaStyle.background)
        .alert(mText("Radera osparat ljud?", "Discard unsaved audio?"), isPresented: $showDiscardAudio) {
            Button(mText("Radera", "Discard"), role: .destructive) { session.discardPendingAudio() }
            Button(mText("Avbryt", "Cancel"), role: .cancel) {}
        } message: { Text(mText("Det här klippet har inget sparat transkript än.", "This clip does not have a saved transcript yet.")) }
    }
    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).foregroundStyle(MumlaStyle.accent).font(.system(.caption, design: .monospaced).weight(.semibold))
            Text(text).font(.system(.subheadline, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
