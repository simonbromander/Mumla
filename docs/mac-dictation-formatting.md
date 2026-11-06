# Optional Mac dictation formatting

The subsequent [text-provider/list follow-up](mac-text-providers.md) adds a Mac
Qwen/Apple choice and word-preserving list layout. The build-43 record below
describes what was released at that point, not that follow-up's release status.

## Scope

- Add a persistent, default-off Format before pasting switch beside Text preferences.
- Use the installed local Qwen formatter and saved formatting prompt for new Mac
  dictations only. Summaries remain explicit previews; iOS behavior is unchanged.
- Save the original to History before generation. Persist accepted formatting
  with the existing original/restore mechanism before attempting insertion.
- Preserve the captured paste target, clipboard protections and hidden-on-success
  pill. History re-paste must not format an already saved result again.
- Show formatting progress and its last outcome. Cancellation leaves the saved
  original intact and must never paste a late result. An unavailable model,
  rejected output or generation failure falls back to the saved original.
- Keep word-preservation validation independent of user prompts. Preferences
  control punctuation, capitalization and paragraph breaks, not rewriting.
- Add an independent Recorder / Minimal overlay preference. Minimal keeps REC,
  live metering, elapsed time and stop/cancel controls without the large display.
  Copy fallback remains readable and the window must never take focus.
- Investigate Mac startup delay without removing the 250 ms shortcut guard,
  bypassing secure fields, or holding the microphone open while idle.

## Verification

Cover legacy settings, persistence failures, enabled/disabled routing, saved
prompts, original retention, unavailable/unsafe/failed formatting, cancellation,
history re-paste and successful-paste dismissal. Render compact Mac settings in
both appearances and check accessibility labels and progress controls. Run the
shared and Mac regression suite. Live Qwen quality and real target-app pasting
remain separate checks; no release or device acceptance is implied by unit tests.

## Local verification, 2026-11-06

- Shared/Mac package: 269 tests, 5 opt-in checks skipped, zero failures.
- Direct Mac Debug app compiles. Compact Settings and Minimal recording overlays
  were rendered and inspected in dark and light appearances.
- Integration cases use synthetic text, isolated preferences and private test
  clipboards. They cover saved prompts, cancellation, focus changes, formatting
  save failure, successful-paste dismissal and both overlay sizes.
- Startup no longer repeats the focused-field accessibility inspection or scans
  the microphone list on every pinned-device recording. Appearance animation is
  120 ms instead of 220 ms. The 250 ms hotkey hold guard remains unchanged.
- Diagnostics include the elapsed recording-start call after the recognized
  gesture. This is not a measurement of the first audio sample arriving.
- The opt-in microphone timing run skipped because the test runner has no
  microphone permission. No hardware latency improvement is claimed yet. Run
  `MUMLA_TEST_MIC_STARTUP=1 swift test --filter MicrophoneStartupTests` on an
  authorized development machine for the recorder-only timing check.
- Qwen verifies pinned checksums before loading weights, then reuses its loaded
  container rather than hashing the model files on every request. Live Qwen
  checks skipped because no model is installed on this development machine.
- Published in the signed/notarized direct Mac beta `1.0.1 (43)`. Distribution
  verification is recorded in [Mac releases](mac-direct-release.md). Installation
  on the target Mac and real microphone/model acceptance remain separate checks.
