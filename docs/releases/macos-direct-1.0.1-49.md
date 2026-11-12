# Mumla for Mac 1.0.1 (49) - Meeting Speaker Alignment Beta

## Changed

- Live meeting speaker labels use the next available audio chunk before
  assigning words near a chunk boundary. This fixes a reproduced timing defect
  that could alternate one person's speech between a numbered remote speaker
  and the unassigned audio source.
- Speaker timing remains stable when transcription retries a chunk. Final
  partial chunks and pause/resume drain pending speaker context without ending
  a resumable session or adding words to the transcript.
- Words use their duration rather than a single midpoint for speaker alignment.
  Brief activity gaps do not unnecessarily split one voice. Overlapping voices
  and uncertain predictions remain unassigned, not silently merged.
- The old "Them" fallback is now "Unassigned remote". It is an audio-source
  fallback, not an identified person. Existing custom speaker names are retained.
- Click a passage's speaker label to assign that passage to an existing speaker
  from the same audio source. Other passages, transcript text and timing stay
  unchanged. Previous identities remain available to restore a correction.

Existing recordings are not automatically relabelled. This fixes demonstrated
alignment defects; it does not guarantee that the acoustic model will identify
every person correctly in a group call.

System audio + microphone remains the default, with explicit Start and Stop.
Selected-app and microphone-only capture, pause/resume, live local Swedish
transcription, playback/export and existing dictation/paste behavior are retained.
No audio or text is uploaded by these changes. iOS and Mac TestFlight are unchanged.

## Install And Test

Choose Check for Updates in the direct Mac app, or quit Mumla and replace it with
the downloaded notarized app. Existing history, dictionary, settings and models
are preserved. Do not run production, development and TestFlight copies together.

Meetings require Apple silicon and macOS 14.2 or later. The optional speaker
model must be installed for automatic speaker separation. Obtain participants'
consent. System audio includes other apps' and browser tabs' output; choose a
specific app for narrower capture. Headphones help avoid acoustic microphone bleed.

On a consented group call, check continuous speech across chunk boundaries,
different people taking turns, returning speakers, pause/resume and the final
words after Stop. Correct a single passage with its speaker selector, then
confirm that other people and the words themselves are unchanged.

The local Swift suite completed 355 tests with nine optional model/hardware skips
and no failures. Coverage includes a delayed speaker stream, actual bounded
FluidAudio timeline queries, retries, overlap, track isolation, model failure,
old history and scoped correction safety. The native app and UI-test target
compiled; the isolated selector was checked in compact light/dark layouts.
Automated Mac UI-test execution, acoustic speaker quality, real-call capture,
permissions/routing, traffic auditing and live updater replacement remain
target-Mac acceptance checks. This remains an experimental prerelease.
