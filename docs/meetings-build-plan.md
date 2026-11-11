# Mumla Meetings Build Plan

Status: live-transcription implementation in development; not released or accepted
on real calls. Updated: 2026-11-11. The latest product direction makes live text
part of the first build, superseding the original post-meeting-first proposal.

## Product Decision

Build a Mac recording and transcript tool, not an AI meeting assistant.
The user takes the finished transcript to their own LLM for questions,
summaries, decisions, and follow-ups. Mumla does not need an LLM connection to
record, transcribe, identify speaker turns, search, or export a meeting.

For the first release:

- Save audio independently of inference. Start warming the speech model in the
  background after capture starts; a text model is never needed for meetings.
- Transcribe locally during the meeting by default. Consume committed three-second
  audio chunks with bounded left/right context and finalize the tail after Stop.
- Allow the user to turn live transcription off before starting. The saved meeting
  then has a Transcribe action that works after relaunch, including offline once
  its models are installed.
- Process long recordings in bounded windows, not one enormous in-memory request.
- Use the same job for live processing, catch-up, and saved-recording transcription.
  Recording continues even when model loading or transcription falls behind.

The live path extends the existing file-based model adapter with word timings.
It is incremental rather than a word-at-a-time streaming decoder. First text
normally needs two committed chunks plus model time; cold model preparation adds
latency. This is not a promise of subsecond live text or measured real-call quality.

## Scope

The initial beta is for the direct-download Mac app on Apple Silicon. Feature-gate
meeting audio capture to macOS 14.2 or later; do not raise the existing app's
minimum OS just to show the Meetings section. Validate each supported OS before
enabling the feature there. Intel and sandboxed Mac support need separate capture,
model, and permission acceptance; do not imply they are supported by this beta.

### Included

- Explicit microphone and selected meeting-application audio capture, without a bot
  or virtual audio driver. Microphone-only recording is an explicit source choice.
- Durable local recordings, separate source tracks, pause/resume, Stop and Save,
  recovery after an interrupted app, and a visible recording indicator.
- Swedish transcription with the existing verified Pianissimo artifact, timestamped
  segments, per-meeting speaker separation, speaker renaming, and text corrections.
- A new Mac Meetings workspace, transcript search, speaker filters, and playback
  while the source audio is retained.
- Plain text and speaker/timestamp Markdown copy/export; timestamped JSON export
  for tools and the user's own LLM. Export never sends anything automatically.
- Live transcription and on-demand transcription using the same resumable job.

### Deferred

- In-app Ask this meeting, LLM summaries, action extraction, provider login,
  subscription integration, API keys, and an MCP server. Existing dictation text
  features remain unchanged; meeting transcripts bypass that formatting path.
- Manual/custom notes, comments, custom summary templates, team workspaces,
  automatic sharing, CRM integrations, analytics, and video capture.
- Calendar/microphone-use detection and automatic meeting start/stop. Start and
  stop explicitly in v1; never infer consent from a calendar entry.
- Remembered voiceprints or automatic identity across meetings. Unknown speakers
  stay unknown; diarization does not infer a person's real name.
- iOS meetings, meeting sync, and cross-meeting semantic search.
- Automatic mixed-language routing. English meeting transcription requires its
  own verified Parakeet installation and quality gate before it is offered.

## User Flows

### Start And Record

1. Open Start Meeting from the menu bar or choose Meeting in the full recorder.
2. Select the meeting application plus microphone, or explicitly Microphone only.
   Reuse the existing microphone picker and pinned-device preference.
3. Leave Live transcription enabled, or turn it off for this
   meeting. Remember the last choice without adding another onboarding flow.
4. Review the selected sources, see the consent-message copy action, and press
   Record. Models are not prerequisites. Ask only for the relevant recording
   permissions. Start source meters after that explicit action; show Recording
   only once samples arrive, not merely when a start request was accepted.
5. Close the main window if desired. Recording continues with a menu-bar status
   and the existing minimal REC/timer treatment.
6. Pause for a private aside, Resume explicitly, then Stop and Save.

The consent message is a convenience, not a claim that copying it obtains
everyone's consent. Do not post it into another app automatically.

Application capture is preferable to all-system capture. If process selection
cannot isolate the chosen call, explain the limitation before recording. Browser
process audio may include other tabs; do not promise tab-level isolation. Never
silently broaden capture to every application or switch to another microphone.

### Stop And Transcribe

- Stop closes the writers and durably saves the recording before queuing ASR.
- Live mode processes saved chunks during capture and drains the tail after Stop;
  later mode shows Saved recording with
  Transcribe. A missing model shows an explicit download action, not a failed or
  discarded recording. No automatic model download starts during capture.
- Transcription has truthful progress based on processed audio, Cancel processing,
  and Retry. Cancelling processing preserves the recording and completed work.
- A transcript can be read while speaker assignment finishes. Clearly label its
  speaker state as processing, ready, or unavailable; do not show provisional
  identities as final.
- Completion is a restrained Transcript ready notification. It never inserts a
  meeting transcript into another app or overwrites the clipboard.

### Review And Use Elsewhere

- Open a meeting to its transcript, not an empty notes editor or summary panel.
- Search within it, filter speakers, select a timestamp to seek audio, correct
  text, or rename a speaker. Preserve the original ASR revision separately.
- Copy clean text or copy with speakers/timestamps. Export Markdown or JSON via
  the native save panel; include the meeting title and recording date, not local
  file paths, device identifiers, or voice embeddings.
- Review the exported content before manually sharing it with an LLM or teammate.
  No built-in provider request, cloud fallback, or shared-link service is in v1.
- When audio has expired, the transcript and export still work; playback and
  re-transcription clearly say that their source audio is unavailable.

## Mac UI And Existing Dictation

- Add Meetings to the existing main-window sidebar. Reuse Mumla's white/graphite
  housing, recessed display, monospaced typography, orange latched mode keys,
  system/light/dark appearance, and real source meters.
- Use a compact, date-grouped meeting list and an unframed transcript workspace.
  Show title, date, duration, recording/job state, speaker filter, and normal
  copy/export controls. Do not nest cards or show a dense AI dashboard.
- During recording the workspace shows both source meters, transport controls,
  and an auto-following live transcript. Show
  Saved recording / Transcription pending only after capture has stopped.
- Preserve the minimal click-through REC/timer capsule without adding stop/cancel
  buttons to it. Pause, Stop, and Open Meeting remain accessible from the menu bar
  and full recorder. Distinguish a meeting in the menu-bar accessibility label.
- Keep the normal configurable dictation hold/release and double-tap gestures.
  Meeting mode does not make releasing Control end a meeting. A separate optional
  meeting shortcut can be configured and must reject conflicts with dictation.
- V1 has one active capture owner. Starting a meeting while dictating must not
  discard that dictation. While a meeting records or is paused, a qualified
  dictation gesture reports Meeting in progress without stealing focus, opening
  a second recorder, or stopping the meeting. Normal Control shortcuts still work.
- Once capture stops, ordinary dictation works during queued meeting processing;
  foreground dictation has priority over the meeting model worker. Do not run
  simultaneous mutable inference against one AsrManager.
- Provide VoiceOver labels/state, keyboard navigation, visible non-color recording
  cues, 4.5:1 text contrast, Reduce Motion, and stable layout on small Mac windows.

## Implementation Boundaries

Prefer new meeting-specific types inside the existing targets over new packages,
a second app coordinator for everything, or a storage-framework migration.
Names below describe ownership, not a requirement for one file per type.

| Existing Area | Planned Change |
| --- | --- |
| `Sources/MumlaCore` | Meeting metadata, source/segment/speaker contracts, job states, local MeetingStore, retention policy, export |
| `Sources/MumlaAudio` | System-audio tap, meeting capture/writer, bounded audio reader, timestamped ASR adapter, diarization adapter |
| `Sources/MumlaMac` | Focused MeetingCoordinator, Meetings views, menu/full-recorder entry, microphone ownership, updater integration |
| `Sources/MumlaUI` | Reuse existing recorder materials and controls; add shared components only for actual duplication |
| `Tests/MumlaCoreTests` | Store/recovery/jobs, timestamp math, retention, corrections, export |
| `Tests/MumlaMacTests` | Capture ownership, shortcut/menu states, background processing priority, update/quit gates |
| Native Mac Tests | Permission, capture, source-device changes, playback, accessibility, real-window layout |
| `Configuration`, notices | Pinned diarization model revisions, checksums, sizes, source licenses and conversion attribution |

Verified source facts that shape the plan:

- `MicrophoneRecorder` writes a temporary dictation WAV and deletes it on Cancel.
  Do not reuse its cancellation/deletion semantics for saved meetings. Preserve
  the input-only AUHAL behavior that avoids changing Bluetooth output quality.
- `LocalPianissimoTranscriber` returns text and overall duration but currently
  drops FluidAudio's token timings. Add a meeting result/adapter without breaking
  the existing dictation API.
- FluidAudio is resolved to 0.17.3 at
  `a6b826ce9a09028fc685a4b32a8927ec920c3188`. Its checked-out ASR types expose token
  and word timing support, and its documentation describes long-file windowing
  and diarization. Verify model-specific behavior rather than assuming those
  capabilities transfer to Pianissimo unchanged. Avoid an unrelated upgrade.
- `DictationHistoryStore` caps dictations at 100; `VoiceNote` limits Watch notes
  to 61 seconds and 2 MB. Meetings need their own store and retention, not larger
  caps on either existing store.
- `MacStorageDirectory.resolve` adopts an existing sandbox store when needed.
  Put Meetings under the resolved root and include it in store-presence detection;
  a meetings-only store must not disappear after a distribution switch.
- `refreshUpdateActivity` currently tracks dictation/install work only. Meeting
  capture and uncommitted writes must participate in the update and quit gates.

## Recording And Storage

- Create a meeting identity and versioned manifest before capture. Store committed
  audio and metadata under the resolved app-support Meetings directory, not the
  temporary recordings directory. Use the existing Codable/atomic-file patterns.
- Keep mic and selected-app audio as separate tracks. Normalize speech storage
  to a verified 16 kHz mono PCM16 format per track unless the spike shows this
  harms diarization; preserve actual format metadata and measure that trade-off.
  Two such tracks use about 230 MB per recorded hour before metadata/overhead.
- Use independently readable three-second audio chunks. Commit each file
  before its manifest entry. Recover orphaned complete chunks, quarantine partial
  tails, and tolerate a damaged final journal record without discarding the rest.
- Use a common monotonic timeline and sample positions, not repeated wall-clock
  subtraction. Record pause intervals, missing-source intervals, device changes,
  and clock offsets. Pauses remain visible gaps in elapsed-meeting timestamps.
- Keep audio callbacks nonisolated and allocation-bounded. Copy into preallocated
  bounded buffers; conversion, file I/O and UI notifications run elsewhere. No
  Core ML, actor hop requiring MainActor, blocking disk write, or unbounded queue
  runs inside an audio callback.
- If the writer cannot keep up, surface and persist a gap or pause capture; never
  show healthy recording while dropping audio invisibly. Source loss pauses the
  meeting with an explicit choice to resume/reselect or continue microphone-only.
- Preflight free space using actual track formats and reserve for clean shutdown.
  Warn before the reserve is exhausted and stop/save cleanly if necessary.
- On crash/relaunch, recover committed data as Interrupted. Never automatically
  reactivate microphones. The possible uncommitted tail is at most three seconds
  in process-crash tests; power-loss durability is a separate measurement.
- On sleep, stop and save as interrupted. On quit during capture, offer Stop and
  Save or Keep Recording. Paused is still an active meeting for this decision.
- Measure Record-to-first-saved-audio separately from permission prompts. Proposed
  warm-path gate: at most 200 ms p95 after permissions are granted and sources
  selected. Persist only consented audio; never pre-buffer a meeting before Record.

Recording is always the source of truth. A failed/cancelled model job must not
damage it. Do not set a ten-minute dictation cap on meetings. Test two-hour
recordings before claiming support for that duration.

## Transcription Jobs And Speaker Assignment

- Persist a job per recording revision with queued, transcribing, assigning
  speakers, ready, cancelled, and failed states. Capture has its own preparing,
  recording, paused, saved, and interrupted states; do not combine both lifecycles
  into one growing enum or infer recording state from ASR activity.
- Bound concurrency to one model worker initially. Release it for foreground
  dictation, new meeting capture, or user cancellation at safe work boundaries.
  Resume from committed output after relaunch; never auto-resume audio capture.
- Read bounded, disk-backed spans through the existing FluidAudio model adapter;
  never load a two-hour Float array. The live adapter keeps two seconds of left
  context and one of right context, using word timing and multi-word overlap
  anchors to avoid repeated boundary phrases. Preserve deliberate repetitions;
  this has focused synthetic coverage, not a general meeting-WER claim.
- Separate three-second durability chunks from ASR inference windows. Let the
  pinned model's supported window/overlap rules determine decoding boundaries.
  Map token times into the meeting timeline, including pauses and track offsets.
- Persist ordered segments with stable IDs, start/end times, source track,
  optional word timings, model revision, and speaker ID. Preserve overlapping
  speakers; do not force different tracks into a false serial conversation.
- In a personal online call, the mic source may display Me and app audio initially
  Them. Those are source labels, not proof of identity. A shared-room microphone
  or microphone-only recording needs speaker separation on that track too.
- Benchmark LS-EEND and the offline VBx pipeline for the post-meeting use case.
  Include Sortformer as a comparison for smaller calls, not as a universal
  solution: its documented four-speaker limit must not silently merge larger
  meetings. Keep speaker continuity across the full timeline, not each file chunk.
- Align diarization turns to ASR token/word times. If timing is approximate or
  speakers overlap ambiguously, preserve uncertainty and allow correction.
- Speaker model failure leaves a usable transcript with source labels and a
  Retry speaker labels action. Do not replace unknowns with guessed names.
- Transcript corrections and speaker aliases are user-owned overlays/revisions.
  Re-transcription cannot silently overwrite them; publish a new revision and
  let the user explicitly replace or retain the corrected transcript.
- Retrying a job is idempotent. Model/version changes invalidate only affected
  derived work. Mark ready only after its transcript has been durably committed.

## Privacy, Retention, And Distribution

- No meeting audio, transcript, speaker embeddings, or content-bearing diagnostics
  leave the device. No new account, server, telemetry, provider integration, or
  automatic export is introduced. Explicit file export/copy is a user action.
- Ask for microphone and system-audio recording permissions independently. Use
  `NSAudioCaptureUsageDescription` for process-tap capture. Meeting recording must
  not require Accessibility/Input Monitoring merely because dictation uses them.
- Keep local files private to the user and omit content from logs. This does not
  create a new promise of application-level at-rest encryption or secure erasure.
  Do not include audio or machine details in source-controlled evaluation results.
- Default audio retention: seven days after successful transcription, with Delete
  when transcript ready as an alternative. Until transcription succeeds, pending,
  cancelled, and failed recordings stay available and show that retention state.
  Warn that choosing Transcribe later keeps audio. Do not delete the only
  untranscribed recording in a background cleanup; users can explicitly delete it.
- Deleting a meeting cancels its jobs, stops playback, and removes original audio,
  transcripts, aliases, and derived speaker data. Check cleanup at launch and on
  relevant state changes, not with continuous idle polling. Playback/retry and
  retention must coordinate so an open reader cannot cause partial deletion.
  Use a durable deletion marker and revision checks so late worker commits or
  orphan recovery cannot resurrect a deleted meeting.
- Update installs wait for recording and commits to finish. A queued/running model
  job may checkpoint and pause for an update; verify its recovery after install.
- The first release is a signed/notarized direct Mac beta. Do not claim App Store
  or TestFlight capture support until those variants pass their own checks.
  Preserve official bundle IDs, existing data, updater behavior, and dictation.

## Build Order And Exit Gates

These checkpoints retain the intended acceptance goals. Capture, storage, live
jobs, the speaker-model installer, workspace, correction, playback and export
are implemented in the development tree. Real-call, hardware and release gates
remain open. See [verification](meetings-verification.md) for measured evidence.

### M0: Capture And Model Spike

- Make a headless two-track capture probe and timestamped transcription probe.
  Keep test audio and raw results out of Git. No broad meeting UI yet.
- Build repeatable tests with public/licensed fixtures first, then obtain consented
  Swedish meeting samples and reference speaker/timestamp annotations. Include a
  headset, loudspeaker echo, a shared mic, silence, interruptions, overlapping
  voices, and at least one meeting with more than four remote speakers.
- Measure capture start, CPU/memory during recording, clock drift, ASR WER and
  missing/duplicated boundary words, timestamp error, diarization error and speaker
  count, model download/memory, and total post-stop completion time.
- Verify licenses/checksums for every proposed diarization artifact before model
  downloads are integrated into the app.
- Gate: captured tracks remain intelligible and aligned for 60 minutes and two
  hours, without audible device-mode degradation or unreported gaps. Recovery and
  model benchmarks determine the supported hardware/OS before expanding the UI.

### M1: Durable Recording And Lifecycle

- Implement MeetingStore, manifests/chunks, microphone ownership, source selection,
  permission handling, capture/pause/stop, interruptions, retention, and recovery.
- Gate: record/save works with no ASR model installed. Inject a process crash,
  disk-full/write failure, source exit, device disconnect, sleep, quit and update
  request. Preserve every committed chunk; never record again without user action.

### M2: Resumable Live Local Transcription

- Add bounded audio reading, timestamp-preserving ASR, live/later scheduling,
  progress/cancel/retry, durable segments, and foreground-dictation priority.
- Gate: the same recording transcribes after relaunch and offline; repeated jobs
  do not duplicate text. Cancellation preserves source audio. Check head/tail and
  every repeated window boundary, not just average WER.
- Keep the original 60-minute/M1 ASR goal of at most three minutes and 3 GB peak
  memory as a measured target, not an assumption. Record ASR and diarization times
  separately and publish actual end-to-end timing before promising an ETA.

### M3: Speaker Labels And Corrections

- Integrate the model selected in M0, persist turns/aliases, align words to turns,
  and add manual speaker and transcript corrections with revision safety.
- Gate: stable IDs across the whole recording and after restart. Proposed initial
  diarization gate: at most 20% DER on the agreed non-overlap annotated Swedish
  set, using a fixed 250 ms collar; report overlap and shared-mic results separately.
  Do not claim universal recognition from this narrow gate. If it fails, retain
  source-labelled transcripts and hold the speaker-recognition release claim.
- Verify sparse/quiet speakers, similar voices, more than four participants,
  duplicate speech from mic bleed, and conservative Unknown attribution.

### M4: Meeting Workspace And Export

- Add the menu/full-recorder entry, recording states, library, transcript viewer,
  local search, speaker filter, retained-audio playback, and copy/export.
- Gate: a user can record, choose later, relaunch, transcribe, rename a speaker,
  correct a word, play its source, and export the corrected result without
  touching an LLM setup screen. Test missing models, missing audio and job failure.
- Capture and inspect actual native windows in both themes, narrow supported
  sizes, large text, VoiceOver and Reduce Motion. No invented recording waveform,
  clipped controls, huge overlay, focus theft, or meeting-to-clipboard auto-paste.

### M5: Beta And Release Acceptance

- Run existing package/native regression tests and release-helper tests; add the
  targeted cases above. Verify iOS still builds because the core/audio packages
  are shared. Do not add Mac-only symbols to unguarded shared code.
- Complete at least ten consented real meetings across Zoom, Teams and browser
  Meet, including the Mac/hardware/OS support matrix chosen at M0. Check capture
  permission revocation, Bluetooth output quality, mixed sample rates, dual-track
  drift, diarization, transcript usability, and recovery. Document unsupported
  configurations rather than widening capture silently.
- Verify zero meeting-content outbound traffic with model downloads/update checks
  separated from the recording test. No logs or shared artifacts contain samples.
- Re-test hotkey/paste/clipboard, unchanged dictation formatting, historical data,
  no-model idle behavior, and safe updater installation. Preserve the idle CPU
  target below 1% and unload meeting models once jobs are idle.
- Only then follow the direct Mac release runbook: exact-source tests, signed
  archive, notarization/Gatekeeper, anonymous-download verification, signed update
  feed, and release notes. An archive alone is not a shipped/accepted release.

## Live Processing Acceptance

The first build runs inference on already committed chunks during a
meeting, reusing the store, timeline, jobs, model adapters, and source files. Label
live text/speakers provisional, drain remaining work after Stop, and avoid a
mandatory second whole-meeting ASR pass. Speaker finalization may still require
the complete recording.

Release this implementation only if it does not harm captured audio, call responsiveness,
Bluetooth output quality, transcription accuracy, or bounded memory on the
supported Macs. Keep Record now, transcribe later available. If live processing
cannot meet those gates, fix it or explicitly narrow support before release.

## Open Decisions And Evidence Needed

- Choose and pin the diarization model only after M0 quality/resource/license
  evidence. Availability in FluidAudio is not acceptance in Mumla.
- Confirm the supported OS/hardware matrix and measured two-hour behavior. The
  initial direct/Apple-Silicon scope is not a claim about Intel or sandbox builds.
- Obtain consented evaluation audio before asserting Swedish meeting quality.
  The original owner-dataset Phase 0 gate remains distinct and is not passed by
  a synthetic capture probe or a public read-speech benchmark.
- Decide whether English ships in the first meeting beta after the English model
  and routing work is evaluated; until then label the beta Swedish-first clearly.
- Confirm the proposed retention default and three-second process-crash tail budget
  in product acceptance. Do not claim zero-loss recording through abrupt power loss.

## Research References

Reviewed 2026-11-11; competitor behavior is inspiration, not implementation proof.

- [Apple: capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
- [FluidAudio 0.17.3: long transcription](https://github.com/FluidInference/FluidAudio/blob/a6b826ce9a09028fc685a4b32a8927ec920c3188/Documentation/ASR/LongTranscription.md)
- [FluidAudio 0.17.3: diarization](https://github.com/FluidInference/FluidAudio/blob/a6b826ce9a09028fc685a4b32a8927ec920c3188/Documentation/Diarization/GettingStarted.md)
- [Fireflies: meeting workspace](https://guide.fireflies.ai/articles/6653885315-learn-about-the-fireflies-notepad)
- [Granola: transcription and source labels](https://docs.granola.ai/help-center/taking-notes/transcription)
- [Existing implementation plan](implementation-plan.md), [design system](design-system.md), [light appearance](light-appearance.md), and [direct Mac release runbook](mac-direct-release.md)
