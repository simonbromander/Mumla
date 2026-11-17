import AppKit
import MumlaAudio
import MumlaUI
import SwiftUI

struct MeetingSetupView: View {
    @MumlaTheme private var palette
    @ObservedObject var meetings: MeetingCoordinator
    @ObservedObject var app: AppCoordinator
    @State private var sourcesOpen = false
    @State private var microphoneOpen = false
    @State private var optionsOpen = false
    @State private var appsOpen = false
    @State private var copied = false

    private var microphoneName: String {
        guard let pinned = app.settings.pinnedInputDevice,
              app.isPinnedInputDeviceConnected else { return mText("Systemets standard", "System default") }
        return pinned.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let error = meetings.error { startupError(error) }
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel(mText("Mötets namn (valfritt)", "Meeting title (optional)"))
                        TextField(mText("Nytt möte", "New meeting"), text: $meetings.title)
                            .textFieldStyle(.plain).mumlaFont(size: 15).padding(12).mumlaRecess(radius: 8)
                            .accessibilityLabel(mText("Mötets namn", "Meeting title")).accessibilityIdentifier("meeting.title")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel(mText("Spela in", "Record"))
                        selector(meetings.sourceName, symbol: meetings.sourcePID == 0 ? "mic" : "speaker.wave.2") { sourcesOpen = true }
                            .accessibilityIdentifier("meeting.source")
                            .popover(isPresented: $sourcesOpen) { sourcePicker }
                        Text(meetings.sourcePID == 0
                             ? mText("Bara din mikrofon. Passar möten i samma rum.", "Your microphone only. For meetings in the same room.")
                             : meetings.audioSource == .systemAudio
                             ? mText("Din mikrofon och allt datorljud, även ljud från andra appar.", "Your microphone and all computer audio, including sounds from other apps.")
                             : mText("Din mikrofon och den valda appen. Andra webbläsarflikar kan också höras.", "Your microphone and the selected app. Other browser tabs may also be captured."))
                            .mumlaFont(size: 12).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel(mText("Mikrofon", "Microphone"))
                        selector(microphoneName, symbol: "mic") { app.refreshInputDevices(); microphoneOpen = true }
                            .accessibilityIdentifier("meeting.microphone")
                            .popover(isPresented: $microphoneOpen) { microphonePicker }
                        if let pinned = app.settings.pinnedInputDevice, !app.isPinnedInputDeviceConnected {
                            Text(mText("\(pinned.name) är frånkopplad. Systemets standard används.", "\(pinned.name) is disconnected. Using the system default."))
                                .mumlaFont(size: 12).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    DisclosureGroup(isExpanded: $optionsOpen) {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(mText("Transkribera live", "Live transcription"), isOn: $meetings.liveTranscription)
                                .accessibilityIdentifier("meeting.live")
                            Toggle(mText("Behåll ljud i 7 dagar", "Keep audio for 7 days"), isOn: $meetings.keepAudio)
                                .accessibilityIdentifier("meeting.keepAudio")
                        }.toggleStyle(MumlaSwitchStyle()).padding(.top, 12)
                    } label: { fieldLabel(mText("Inspelningsalternativ", "Recording options")) }
                        .accessibilityIdentifier("meeting.options")
                    if app.modelDirectory == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(mText("Språkmodellen saknas. Ljudet sparas så att du kan transkribera senare.", "The speech model is missing. Audio will be saved so you can transcribe later."))
                                .mumlaFont(size: 12).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                            if app.isInstallingModel {
                                Label(mText("Hämtar språkmodell", "Downloading speech model"), systemImage: "arrow.down.circle")
                                    .mumlaFont(size: 12)
                            } else {
                                Button { app.installModel() } label: {
                                    Label(mText("Hämta språkmodell", "Download speech model"), systemImage: "arrow.down.circle")
                                        .padding(.horizontal, 12).frame(minHeight: 44)
                                }.buttonStyle(MumlaKeyStyle(radius: 8))
                            }
                        }
                    }
                }.disabled(meetings.isStarting).padding(4).padding(.bottom, 8)
            }.scrollIndicators(.visible)
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { consentButton; Spacer(minLength: 0); startButton }
                VStack(alignment: .trailing, spacing: 10) { startButton; consentButton }
            }
        }.onAppear { app.refreshInputDevices() }
    }

    private var sourcePicker: some View {
        MeetingPopover(title: mText("Spela in", "Record")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    choice(mText("Systemljud + mikrofon", "System audio + microphone"), symbol: "speaker.wave.2", selected: meetings.audioSource == .systemAudio) {
                        meetings.sourcePID = MeetingAudioSource.systemAudio.id; sourcesOpen = false
                    }.accessibilityIdentifier("meeting.source.system")
                    choice(mText("Endast mikrofon", "Microphone only"), symbol: "mic", selected: meetings.sourcePID == 0) {
                        meetings.sourcePID = 0; sourcesOpen = false
                    }.accessibilityIdentifier("meeting.source.microphone")
                    DisclosureGroup(mText("En specifik app", "A specific app"), isExpanded: $appsOpen) {
                        VStack(spacing: 8) {
                            ForEach(meetings.sources) { source in
                                choice(source.name, symbol: "app", selected: meetings.sourcePID == source.id) {
                                    meetings.sourcePID = source.id; sourcesOpen = false
                                }
                            }
                            Button { meetings.refreshSources() } label: {
                                Label(mText("Uppdatera appar", "Refresh apps"), systemImage: "arrow.clockwise").frame(minHeight: 44)
                            }.buttonStyle(MumlaKeyStyle(radius: 8))
                        }.padding(.top, 8)
                    }.padding(.vertical, 10).accessibilityIdentifier("meeting.source.apps")
                }.padding(4)
            }.frame(maxHeight: 340)
        }
    }

    private var microphonePicker: some View {
        MeetingPopover(title: mText("Mikrofon", "Microphone")) {
            ScrollView {
                VStack(spacing: 8) {
                    choice(mText("Systemets standard", "System default"), symbol: "mic", selected: app.settings.pinnedInputDevice == nil) {
                        app.setPinnedInputDevice(nil); microphoneOpen = false
                    }.accessibilityIdentifier("meeting.microphone.default")
                    ForEach(app.inputDevices) { device in
                        choice(device.name, symbol: "mic", selected: app.isPinnedInputDevice(device)) {
                            app.setPinnedInputDevice(device); microphoneOpen = false
                        }
                    }
                }.padding(4)
            }.frame(maxHeight: 280)
        }
    }

    private var consentButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(mText("Jag vill transkribera vårt möte lokalt med Mumla. Är alla okej med det?", "I'd like to transcribe our meeting locally with Mumla. Is everyone comfortable with that?"), forType: .string)
            copied = true
        } label: {
            Label(copied ? mText("Kopierat", "Copied") : mText("Kopiera samtyckesfråga", "Copy consent message"), systemImage: copied ? "checkmark" : "doc.on.doc")
                .mumlaFont(size: 12).padding(.horizontal, 12).frame(minHeight: 44)
        }.buttonStyle(MumlaKeyStyle(radius: 8)).accessibilityIdentifier("meeting.consent")
    }

    private var startButton: some View {
        Button { Task { await meetings.start() } } label: {
            HStack(spacing: 10) {
                if meetings.isStarting { ProgressView().controlSize(.small) }
                else { Image(systemName: "record.circle.fill").foregroundStyle(palette.recording) }
                Text(meetings.isStarting ? mText("Startar inspelning", "Starting recording") : mText("Starta inspelning", "Start recording"))
            }.mumlaFont(size: 13, weight: .medium).padding(.horizontal, 16).frame(minHeight: 48)
        }.buttonStyle(MumlaKeyStyle(radius: 8))
            .disabled(meetings.isCapturing || meetings.availabilityMessage != nil).accessibilityIdentifier("meeting.start")
    }

    private func startupError(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: "exclamationmark.triangle")
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("meeting.start.error")
            if meetings.startupAudioPermission == .microphone {
                permissionButton(mText("Mikrofonåtkomst", "Microphone access"), pane: "Privacy_Microphone")
            } else if meetings.startupAudioPermission == .system {
                permissionButton(mText("Systemljudåtkomst", "System audio access"), pane: "Privacy_ScreenCapture")
            }
        }.mumlaFont(size: 12).padding(14).frame(maxWidth: .infinity, alignment: .leading).mumlaRecess(radius: 8)
    }

    private func permissionButton(_ title: String, pane: String) -> some View {
        Button { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!) } label: {
            Label(title, systemImage: "arrow.up.right").fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10).frame(minHeight: 44)
        }.buttonStyle(MumlaKeyStyle(radius: 8))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).mumlaFont(size: 12, weight: .medium).foregroundStyle(palette.secondary)
    }

    private func selector(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                Text(title).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down").font(.system(size: 11))
            }.mumlaFont(size: 13).padding(12).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(MumlaKeyStyle(radius: 8))
    }

    private func choice(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                Text(title).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                if selected { Image(systemName: "checkmark").foregroundStyle(palette.accent) }
            }.mumlaFont(size: 13).padding(12).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(MumlaKeyStyle(radius: 8))
    }
}

struct MeetingPreferencesView: View {
    @MumlaTheme private var palette
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var meetings: MeetingCoordinator
    @ObservedObject var app: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            MumlaPanelHeader(mText("Mötesinställningar", "Meeting preferences"), closeLabel: mText("Stäng", "Close"), closeIdentifier: "meeting.preferences.close") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MeetingDetectionSettingsView(app: app, detection: app.meetingDetection)
                    Divider()
                    Label(mText("Talare", "Speakers"), systemImage: "person.2").mumlaFont(size: 13, weight: .medium)
                    Text(meetings.speakersInstalled ? mText("Talarmodellen är installerad.", "Speaker model installed.")
                         : mText("Hämta talarmodellen för att skilja på deltagarnas röster. 45 MB, körs lokalt.", "Download the speaker model to distinguish participants' voices. 45 MB, runs locally."))
                        .mumlaFont(size: 12).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    if let fraction = meetings.speakerDownload { MumlaDownloadGauge(fraction: fraction) }
                    else if !meetings.speakersInstalled {
                        Button { meetings.installSpeakers() } label: {
                            Label(mText("Hämta talarmodell", "Download speaker model"), systemImage: "arrow.down.circle")
                                .mumlaFont(size: 12).padding(.horizontal, 12).frame(minHeight: 44)
                        }.buttonStyle(MumlaKeyStyle(radius: 8)).disabled(meetings.isProcessing)
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Label(mText("Klart", "Done"), systemImage: "checkmark").padding(.horizontal, 16).frame(minHeight: 44)
                }.buttonStyle(MumlaKeyStyle(radius: 8)).keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("meeting.preferences.done")
            }.padding(20)
        }.frame(width: 480, height: 460).mumlaFont(.body).foregroundStyle(palette.ink)
            .background { MumlaBackdrop() }.tint(palette.accent).mumlaAppearance()
    }
}
