# Mumla for Mac 1.0.1 (47) - System Audio Meetings Beta

## Changed

- Meetings now default to System audio + microphone. Your microphone and the
  Mac's output are captured on separate tracks and transcribed locally.
- Starting from a Slack/Teams meeting suggestion uses the same default. The
  prompt and setup screen explain that system audio includes sounds from other
  apps and browser tabs. Nothing records before you choose Record or Start.
- Select a specific meeting app for narrower output capture, or Microphone only.
  A missing selected app does not silently fall back to recording all apps.
- Pause/resume preserves the original capture source. System-audio capture does
  not stop merely because a particular meeting app closes. Stop and save the
  recording explicitly when finished.
- The recording readout shows MIC and SYS, with descriptive VoiceOver labels.
  Transcript playback stays disabled during recording to avoid feeding it back
  into capture.

Existing dictation hotkeys, auto-paste, local formatting, minimal REC/timer mode,
meeting suggestions, live Swedish transcription, speaker labels, corrections,
playback after recording, export and audio retention remain available. This
release does not include destination sending or the Native/Classic appearance
work. iOS and sandboxed Mac TestFlight are unchanged.

## Experimental Scope And Permissions

Meetings require the direct Mac build, Apple silicon and macOS 14.2 or later.
Allow microphone and system-audio recording permission. Obtain participants'
consent and check the selected source before starting. System audio may include
notifications, music and other apps' output; choose a specific app if needed.
Microphone input is separate from the digital output tap; headphones help avoid
acoustic bleed. Individual speaker recognition and echo cancellation are not
guaranteed. Speech recognition remains Swedish-only in this meeting beta.

Suggestions and Calendar context remain opt-in. Microphone activity is a hint,
not proof of a call. No microphone or audio tap is opened for detection itself.
Calendar data is not uploaded or changed. Audio and transcripts stay local;
there is no cloud transcription or meeting-LLM connection.

## Install And Test

Choose Check for Updates in the direct Mac app, or quit Mumla and replace it with
the downloaded notarized app. Existing history, dictionary, settings and models
are preserved. Do not run production, development and TestFlight copies together.

For a short consented call, verify System audio + microphone is selected, both
MIC and SYS meters respond, and both sides appear in the saved transcript. Check
pause/resume and Stop/save. Also try a specific app and Microphone only to confirm
their narrower scopes. Recording should not require another app to already be
playing audio. Test a detected Slack/Teams suggestion separately.

Automated tests and silent UI fixtures do not establish real two-sided capture,
permissions, routing, speaker accuracy or live updater replacement. Those remain
target-Mac acceptance checks. This is an experimental prerelease, not a stable
meeting-recording guarantee.
