import ActivityKit
import AppIntents
import MumlaUI
import SwiftUI
import WidgetKit

@main
struct MumlaWidgets: WidgetBundle {
    var body: some Widget { MumlaKeyboardLiveActivity() }
}

struct MumlaKeyboardLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MumlaKeyboardActivityAttributes.self) { context in
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("mumla / K01", systemImage: "keyboard").font(.system(.headline, design: .monospaced))
                    Text(context.isStale ? mText("Sessionen är pausad", "Session paused") : title(context.state.phase)).font(.system(.subheadline, design: .monospaced))
                    if let start = context.state.recordingStartedAt, context.state.phase == "recording" {
                        Text(start, style: .timer).monospacedDigit().font(.system(.title2, design: .monospaced))
                    }
                }
                Spacer()
                Button(intent: EndMumlaKeyboardSessionIntent()) {
                    Image(systemName: "power").font(.system(size: 20, weight: .medium)).frame(width: 48, height: 48)
                }.buttonStyle(MumlaKeyStyle()).accessibilityLabel(mText("Avsluta session", "End session"))
            }.padding(18).foregroundStyle(MumlaStyle.ink)
                .activityBackgroundTint(MumlaStyle.background)
                .activitySystemActionForegroundColor(MumlaStyle.ink)
                .widgetURL(URL(string: "mumla://keyboard"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("mumla", systemImage: "keyboard").font(.system(.headline, design: .monospaced))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: EndMumlaKeyboardSessionIntent()) { Image(systemName: "power").frame(width: 40, height: 40) }
                        .accessibilityLabel(mText("Avsluta session", "End session"))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.isStale ? mText("Sessionen är pausad", "Session paused") : title(context.state.phase)).font(.system(.subheadline, design: .monospaced))
                }
            } compactLeading: {
                Image(systemName: context.isStale ? "mic.slash" : context.state.phase == "recording" ? "mic.fill" : "keyboard").foregroundStyle(.orange)
            } compactTrailing: {
                if let start = context.state.recordingStartedAt, context.state.phase == "recording" {
                    Text(start, style: .timer).monospacedDigit().frame(width: 42)
                } else { Text("SV").font(.system(.caption, design: .monospaced)) }
            } minimal: { Image(systemName: context.isStale ? "mic.slash" : "mic.fill").foregroundStyle(.orange) }
            .widgetURL(URL(string: "mumla://keyboard"))
            .keylineTint(.orange)
        }
    }
    private func title(_ phase: String) -> String {
        switch phase {
        case "recording": mText("REC · Lyssnar", "REC · Listening")
        case "transcribing": mText("Bearbetar på enheten", "Transcribing on device")
        case "failed": mText("Öppna Mumla för att fortsätta", "Open Mumla to continue")
        default: mText("Tangentbord på · Mikrofon aktiv", "Keyboard on · Microphone active")
        }
    }
}
