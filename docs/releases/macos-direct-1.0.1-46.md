# Mumla for Mac 1.0.1 (46) - Meeting Suggestions Beta

## New

- Opt-in suggestions when the Slack or Microsoft Teams desktop app uses its
  microphone. A small tactile prompt offers Start and Not now. Nothing records
  automatically; detection itself does not open a microphone or audio tap.
- Optional Calendar context can supply a matching ongoing or imminent meeting
  title. Enable it separately in Settings or the meeting setup screen. Calendar
  access is not required to detect a call or record manually. Mumla never changes
  events or uploads calendar data.
- Suggestions wait for sustained input activity, expire after a minute and are
  suppressed during Mumla's other work. Brief mute/reconnect transitions do not
  immediately trigger another prompt. Switching suggestions off stops observation.

## Meeting UI Improvements

- Long meeting titles, source names and speaker labels wrap. Compact windows
  give the transcript more room, with pause/stop controls kept accessible.
- Source, speaker and action pickers follow Mumla's tactile light/dark design.
- Correction, deletion and quit-confirmation dialogs now match the app. Deleting
  audio keeps the transcript; deleting a meeting still requires confirmation.

Existing live local Swedish transcription, on-demand processing, speaker labels,
playback, export, dictation hotkeys, auto-paste and minimal REC/timer mode remain
available. Destination sending is not included in this release.

## Experimental Scope And Permissions

Meetings and suggestions require Apple silicon, macOS 14.2+ and the direct Mac
build. Browser calls and calendar-only reminders are not detected. Microphone
activity is a hint, not proof of a call: voice messages or microphone checks can
also trigger a prompt. A muted app may not expose input activity until unmuted.
If no prompt appears, start recording manually in Meetings.

Calendar permission is optional and only requested when you enable meeting titles
from Calendar. macOS requires full event access for this lookup, but Mumla only
reads nearby events and never modifies them. Only a suggested title is saved with
a recording after you choose Start. Calendar notes, attendees, links and event
identifiers are not saved or logged.

Actual recording still requires microphone and system-audio permission. Obtain
the participants' consent before recording. Speech recognition remains Swedish
only; speaker separation and transcript accuracy remain experimental.

## Install And Test

Choose Check for Updates in the direct Mac app, or quit Mumla and replace it with
the downloaded notarized app. Existing local history, dictionary, settings and
models are preserved. Do not run production, development and TestFlight copies
together. Suggestions are off by default; enable Suggest meeting recording in
Settings or the meeting setup screen.

For a short consented Slack/Teams call, check that the prompt appears, Not now
records nothing, and Start selects the correct meeting app. Check both MIC and
APP meters and confirm both sides reach the transcript. Test optional Calendar
access separately; a denied calendar must not prevent manual recording.

Automated checks and silent UI fixtures do not prove real-call detection,
permissions, full-screen placement, audio quality, idle cost or live updater
replacement. Those remain target-Mac acceptance checks. This is an experimental
prerelease, not a stable meeting-support claim. No iOS or sandboxed Mac TestFlight
build is included.
