# Mumla for Mac 1.0.1 (48) - Meeting Recording Reliability Beta

## Changed

- Recording now tolerates brief saving delays without exhausting the audio
  buffer pool on small microphone or system-audio callbacks. Memory stays bounded.
- If the writer genuinely overloads, audio already accepted is saved before
  stopping instead of being discarded.
- Audio conversion keeps its input memory separate from capture and drains
  pending output on Stop/Pause. Stereo system audio is covered at 44.1/48 kHz,
  with small and large callback sizes.
- Unexpected stops show a warning on the recorder. The meeting keeps an
  incomplete-recording notice even after transcription finishes or app restart.
  A non-sensitive interruption category is saved with the meeting.

There is no 13-minute meeting limit. These changes fix reproduced buffering and
conversion defects; they do not establish the cause of an individual recording
stopping. Audio after a real stop cannot be recovered if it was never captured.

System audio + microphone remains the default. Selected-app and microphone-only
capture, explicit Start, pause/resume, live local Swedish transcription, speaker
labels and existing dictation/paste behavior are retained. Capture never silently
broadens to another source or restarts automatically.

This release does not include the separate settings reorganization, CLI/cloud
summaries, destination sending or Native/Classic appearance work. No audio or
text is uploaded by the recording fixes. iOS and Mac TestFlight are unchanged.

## Install And Test

Choose Check for Updates in the direct Mac app, or quit Mumla and replace it with
the downloaded notarized app. Existing history, dictionary, settings and models
are preserved. Do not run production, development and TestFlight copies together.

Meetings require Apple silicon and macOS 14.2 or later. Allow microphone and
system-audio recording permission. Obtain participants' consent and check the
source: System audio includes other apps' and browser tabs' output. Choose a
specific app for a narrower scope; headphones help avoid acoustic microphone
bleed. Speaker recognition and echo cancellation are not guaranteed.

Verify both MIC and SYS meters and both sides of the saved transcript during a
consented call longer than 15 minutes. Check pause/resume and Stop/save, and
confirm that the end of each track is retained. Interrupted meetings must remain
clearly marked as partial rather than appearing complete.

Automated coverage includes writer stalls, true overload, converted PCM integrity,
backward-compatible history and persistent interruption warnings. An accelerated
two-hour test retained both tracks across 4,800 bounded files with recovery checks.
This is synthetic input, not two hours of real-time call capture or ASR validation.
Real-call audio, permissions, routing, traffic auditing, native UI-test execution
and live updater replacement remain target-Mac acceptance checks. This is an
experimental prerelease, not a stable recording guarantee.
