import MumlaCore
import MumlaUI
import SwiftUI

struct KeyboardSetupSheet: View {
    @MumlaTheme private var palette
    @ObservedObject var session: DictationSession
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardAudio = false
    @AppStorage(KeyboardSessionDuration.preferenceKey) private var sessionMinutes = KeyboardSessionDuration.defaultValue.rawValue
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
                    VStack(alignment: .leading, spacing: 8) {
                        Label(session.keyboardPreparationTitle,
                              systemImage: session.keyboardSnapshot.isAlive() ? "checkmark.circle.fill" : "mic.fill")
                            .mumlaFont(.subheadline, weight: .semibold)
                        Text(session.isStartingKeyboard
                             ? mText("Stanna i Mumla tills sessionen är redo. Första starten kan ta längre tid.", "Stay in Mumla until the session is ready. The first start may take longer.")
                             : session.keyboardSnapshot.isAlive()
                             ? mText("Gå tillbaka till din app. Mikrofonknappen är redo i Mumla-tangentbordet.", "Return to your app. The microphone key is ready in the Mumla keyboard.")
                             : session.isPreparingModel
                             ? mText("Språkmodellen förbereds. Mikrofonen är av tills du startar sessionen.", "Preparing the language model. The microphone is off until you start the session.")
                             : mText("Starta en session nedan.", "Start a session below."))
                            .mumlaFont(.footnote).fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(palette.lcdInk).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.lcd).clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(4).mumlaRecess(radius: 8)
                    .accessibilityElement(children: .combine).accessibilityIdentifier("keyboard.preparation")
                    VStack(alignment: .leading, spacing: 10) {
                        Text(mText("Sessionstid", "Session duration")).mumlaFont(.subheadline)
                        HStack(spacing: 5) {
                            ForEach(KeyboardSessionDuration.allCases, id: \.rawValue) { duration in
                                Button {
                                    sessionMinutes = duration.rawValue
                                    MumlaFeedback.latch()
                                } label: {
                                    Text(durationTitle(duration)).mumlaFont(.subheadline)
                                        .frame(maxWidth: .infinity)
                                }.buttonStyle(MumlaStereoKeyStyle(isLatched: selectedDuration == duration, height: 48))
                                    .accessibilityIdentifier("keyboard.duration.\(duration.rawValue)")
                                    .accessibilityAddTraits(selectedDuration == duration ? .isSelected : [])
                            }
                        }.padding(4).mumlaRecess(radius: 7)
                            .disabled(session.keyboardSnapshot.sessionID != nil || session.isStartingKeyboard)
                    }
                    Text(mText("Diktera där du skriver.", "Dictate where you write."))
                        .mumlaFont(.title2, weight: .semibold)
                    VStack(alignment: .leading, spacing: 16) {
                        step("01", mText("Lägg till Mumla under Inställningar → Allmänt → Tangentbord → Tangentbord.", "Add Mumla in Settings → General → Keyboard → Keyboards."))
                        step("02", mText("Aktivera Full åtkomst för Mumla. Det låter tangentbordet prata med appen på den här enheten. Ingenting skickas till en server.", "Enable Full Access for Mumla. This lets the keyboard communicate with the app on this device. Nothing is sent to a server."))
                        step("03", mText("Starta en session här, gå tillbaka till din app och välj Mumla med jordgloben.", "Start a session here, switch back to your app and choose Mumla with the globe key."))
                    }
                    if session.keyboardSnapshot.isAlive() {
                        Label(mText("Mikrofonen är aktiv tills sessionen avslutas. Ljud sparas bara när du trycker på inspelningsknappen.", "The microphone stays active until the session ends. Audio is saved only while the recording key is on."), systemImage: "mic.fill")
                            .mumlaFont(.subheadline).foregroundStyle(palette.secondary)
                        Text(session.keyboardSnapshot.expiresAt, style: .time)
                            .mumlaFont(.headline).accessibilityLabel(mText("Sessionen slutar", "Session ends"))
                    } else {
                        Text(mText("Mikrofonen hålls aktiv under vald sessionstid, vilket använder batteri. Låsning eller ett samtal avslutar sessionen. Vanlig textinmatning fungerar även utan Full åtkomst.", "The microphone stays active for the selected duration, using battery. Locking or a call ends the session. Regular typing works without Full Access."))
                            .mumlaFont(.subheadline).foregroundStyle(palette.secondary)
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
                                .mumlaFont(.headline)
                            Text(mText("Ett tidigare klipp väntar på transkribering. Spara eller radera det innan du startar en ny session.", "A previous clip is waiting for transcription. Save or discard it before starting a new session."))
                                .mumlaFont(.subheadline).foregroundStyle(palette.secondary)
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
                            .mumlaFont(.subheadline)
                            .accessibilityIdentifier("keyboard.error")
                    }
                    if !session.keyboardSnapshot.isAlive(), let reason = session.keyboardSnapshot.error {
                        Label(reason, systemImage: "exclamationmark.triangle")
                            .mumlaFont(.subheadline)
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
                Label(session.isStartingKeyboard ? session.keyboardPreparationTitle : session.keyboardSnapshot.isAlive() ? mText("Avsluta session", "End session") : mText("Starta session", "Start session"),
                      systemImage: session.keyboardSnapshot.isAlive() ? "power" : "mic.fill")
                    .mumlaFont(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity).padding(18)
            }
            .buttonStyle(MumlaStereoKeyStyle(isLatched: session.keyboardSnapshot.isAlive(), height: 60))
            .disabled(!session.keyboardSnapshot.isAlive() && (!session.modelReady || session.hasPendingAudio || session.state != .idle || session.isStartingKeyboard))
            .accessibilityIdentifier("keyboard.session")
            .padding(24).background(palette.background)
        }
        .background { MumlaBackdrop() }.mumlaAppearance()
        .mumlaFont(.body)
        .presentationBackground(palette.background)
        .alert(mText("Radera osparat ljud?", "Discard unsaved audio?"), isPresented: $showDiscardAudio) {
            Button(mText("Radera", "Discard"), role: .destructive) { session.discardPendingAudio() }
            Button(mText("Avbryt", "Cancel"), role: .cancel) {}
        } message: { Text(mText("Det här klippet har inget sparat transkript än.", "This clip does not have a saved transcript yet.")) }
    }
    private var selectedDuration: KeyboardSessionDuration { .init(storedMinutes: sessionMinutes) }
    private func durationTitle(_ duration: KeyboardSessionDuration) -> String {
        switch duration {
        case .fifteenMinutes: "15 MIN"
        case .oneHour: "1 H"
        case .twoHours: "2 H"
        }
    }
    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).foregroundStyle(palette.accent).mumlaFont(.caption, weight: .semibold)
            Text(text).mumlaFont(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}
