import AppKit
import MumlaUI
import SwiftUI

struct MeetingDetectionSettingsView: View {
    @ObservedObject var app: AppCoordinator
    @ObservedObject var detection: MeetingDetectionCoordinator
    @State private var requestingCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: Binding(get: { app.settings.suggestMeetingRecording }, set: { app.setSuggestMeetingRecording($0) })) {
                Label(mText("Föreslå mötesinspelning", "Suggest meeting recording"), systemImage: "person.2.wave.2")
                    .fixedSize(horizontal: false, vertical: true)
            }.toggleStyle(MumlaSwitchStyle()).accessibilityIdentifier("meeting.detection.enabled")
                .disabled(app.meetings.availabilityMessage != nil)
            if app.settings.suggestMeetingRecording {
                Text(detection.isAvailable
                     ? mText("Slack / Teams · Frågar innan inspelning", "Slack / Teams · Asks before recording")
                     : mText("Mikrofonaktivitet är inte tillgänglig. Starta mötet manuellt.", "Microphone activity is unavailable. Start the meeting manually."))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("meeting.detection.status")
                Toggle(isOn: Binding(get: { app.settings.useMeetingCalendar }, set: { value in
                    requestingCalendar = true
                    Task { await app.setUseMeetingCalendar(value); requestingCalendar = false }
                })) {
                    Label(mText("Mötesnamn från kalendern", "Meeting titles from Calendar"), systemImage: "calendar")
                        .fixedSize(horizontal: false, vertical: true)
                }.toggleStyle(MumlaSwitchStyle()).disabled(requestingCalendar)
                    .accessibilityIdentifier("meeting.detection.calendar")
                if detection.calendarAccess == .denied || detection.calendarAccess == .restricted {
                    HStack(alignment: .top, spacing: 12) {
                        Text(mText("Kalenderåtkomst saknas. Samtal kan fortfarande upptäckas.", "Calendar access is off. Calls can still be detected."))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                        } label: {
                            Image(systemName: "arrow.up.right").frame(width: 44, height: 44)
                        }.buttonStyle(MumlaKeyStyle(radius: 8))
                            .help(mText("Öppna kalenderåtkomst", "Open Calendar permissions"))
                            .accessibilityLabel(mText("Öppna kalenderåtkomst", "Open Calendar permissions"))
                    }.font(.system(size: 12, design: .monospaced)).foregroundStyle(MumlaStyle.secondary)
                }
            }
        }.font(.system(size: 13, design: .monospaced)).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(app.meetings.availabilityMessage != nil)
    }
}
