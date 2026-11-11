# Mumla for Mac 1.0.1 (45) - Experimental Live Meetings Beta

## New

- A Meetings workspace in the existing tactile light/dark interface. Open it
  from the menu bar or the full recorder, choose a meeting application and
  microphone, and explicitly start recording. Microphone-only recording is
  also available. No bot joins your call.
- Local Swedish transcription during recording, with timestamps, source labels,
  pause/resume, Stop and Save, search, text corrections and clip playback.
- Optional speaker separation through a separately downloaded, verified 45 MB
  model. Without it, the transcript distinguishes microphone and app audio.
  Speaker labels do not identify people's real names; you can name them yourself.
- Clean text, timestamped text, Markdown and JSON exports for use in your own
  tools. No meeting chat, summary provider, or external transcription service.
- Recording is saved in short chunks independently of transcription. You can
  record now and transcribe later, retry interrupted processing, and recover
  committed chunks after an interrupted session. Recovery never restarts a mic.
- Choose seven-day audio retention after transcription or deletion when
  transcription finishes. Unprocessed audio remains until it is transcribed or
  explicitly deleted. Deleting audio preserves the transcript.

Existing dictation hotkeys, auto-paste, clipboard restoration, local text models,
and minimal REC/timer mode remain available. A meeting never auto-pastes its
transcript. Stop/pause controls are available in Meetings, the full recorder and
menu bar; minimal mode remains a click-through indicator.

## Experimental Scope

Meeting capture requires Apple silicon, macOS 14.2 or later, and the direct Mac
build. Ordinary dictation still supports the existing macOS 14+ and Intel matrix.
Speech recognition remains Swedish-only. Browser capture can include audio from
other tabs in the selected browser, so close unrelated playback first.

Live text appears after two completed three-second chunks plus model processing.
The first cold model load can take longer. Text and speaker assignments are
experimental; verify the transcript against the original before relying on it.
This beta does not claim validated Zoom/Teams/Meet quality or speaker accuracy.

Recording requires explicit microphone and system-audio recording permission for
the installed app. Recording does not require Accessibility or Input Monitoring;
those permissions still serve the existing dictation hotkey and paste workflow.
Obtain the participants' consent before recording a real meeting.

## Install And Verify

Use Check for Updates in the direct Mac app, or quit Mumla and replace it with
the downloaded notarized app. Existing history, dictionary, settings and models
are preserved. Do not run production, development and TestFlight copies together.

For the first meeting test, use a short consented call with headphones. Confirm
both MIC and APP meters respond, both sides appear in the live transcript, and
Stop and Save retains the text and playback. Treat a missing source as a failed
recording check, not silence you can assume was captured.

The automated regression suite covers storage, recording lifecycle, model-independent
capture, cancellation/retry, chunk boundaries and overlay ownership. Separate
synthetic checks exercise the actual speech/speaker models, common hardware
sample rates, and two hours of two-track disk-backed writing/recovery. These are
not real-call, permission, long-meeting accuracy or hardware-memory benchmarks.

Real call capture, device changes, clock drift, permissions, VoiceOver, privacy
traffic auditing, and live update installation still need target-Mac acceptance.
This remains a prerelease, not a stable meeting recorder. No destination-sending
feature, iOS update or sandboxed Mac TestFlight upload is included.
