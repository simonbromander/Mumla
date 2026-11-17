# Meeting Start Recovery

## Goal And Scope

Make starting a Mac meeting recording predictable, including Slack calls, and
remove unrelated setup choices from the path to Start recording. Preserve both
Classic and Native styles, the meeting library, live transcription, existing
recordings and on-device processing. The initial implementation did not request
a release; publication followed a separate user request below.

## Confirmed Code Problems

- Meeting startup uses a remembered microphone UID directly, unlike dictation's
  connected-device resolution. A changed/disconnected UID is reported as a
  missing meeting-app audio process.
- The new record is selected before capture starts. A failed start opens an
  empty interrupted document rather than keeping the form available to retry.
- The recording form includes detection, calendar and speaker-model settings;
  its compact viewport hides these among session controls.

The user confirmed an immediate error with System audio + microphone, not
app-specific capture. The exact error is not yet known. These defects and
synthetic regressions are not a real Slack-call acceptance. App-specific helper
process matching is outside this fix because that path is not used here.

## Implementation

1. Resolve the selected microphone consistently with dictation and show its
   current name/default selection directly in the recording form.
2. Keep setup selected until capture starts successfully. Clean up only the
   just-created, provably empty failed attempt; retain any partial audio or
   recovery files. Preserve the title/source/options for a retry.
3. Give capture errors microphone/system-audio context and a support error code.
   Offer explicit permission/settings and source-selection recovery actions.
4. Keep title, audio source, microphone and Start recording on the primary
   setup surface. Put session options behind disclosure; move detection,
   calendar and speaker-model controls to Meeting preferences.

## Verification

- Regressions: failed start/retry, partial preservation, old records unchanged,
  denied/cancelled permission, duplicate start, microphone matching and unchanged
  app-only capture scope. Run the complete Swift suite.
- Build the isolated Mac host and its UI tests. Inspect actual compact/wide
  windows in Classic/Native and light/dark, using only synthetic fixtures.
- Cover source and microphone selection, discoverable settings, successful
  start/stop and a recoverable failed start in UI fixtures. Do not grant new
  system permissions, join a real call or record private audio for acceptance.
- Check the native result visually; retain remaining hardware/Slack acceptance
  gaps explicitly. Do not publish a release without a new request.

Apple's [Core Audio tap sample](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
documents that tap capture needs `NSAudioCaptureUsageDescription` and that the
system asks for permission when recording starts. There is no permission bypass
or automatic global-audio fallback in this change.

## Verified 2026-11-17

- `swift test`: 381 tests, 9 explicit opt-in/platform skips, no failures.
  The two failed-start regressions were first run against the old code and
  failed, then passed with the fix. Added coverage for pending-start
  cancellation, duplicate starts, unindexed recovery files, microphone
  reconnection, stage-specific errors and returning to the meeting library.
- Both Mac Debug app targets and `MumlaMeetingsUI` build-for-testing succeeded
  without signing. The project includes the new setup view in every Mac target.
- UI XCTest execution did not initialize: "Timed out while enabling automation
  mode." No permissions were granted or reset. A successful test build is not
  a passing UI XCTest run.
- Actual isolated host checks used synthetic capture and separate disposable
  storage: Classic/light compact, Native/dark compact, Classic/dark wide in
  Swedish and Native/light wide. Checked microphone selection, explicit
  app-only selection, session options, the themed preferences panel, an
  immediate system-audio failure, successful retry, pause/resume and stop.
  The six seeded library items became seven after one failed attempt and one
  successful recording, with no empty failed meeting added.
- Native and Classic meeting preferences use a bounded panel with a clear Done
  action; long settings remain scrollable without hiding the close action.
- Existing private meetings were not opened or changed. No actual microphone,
  system-audio capture or Slack call was used for these checks. The exact
  reported Slack error and real-call acceptance remain outstanding.
- At implementation verification, no release was published or installed over
  the production app.

## Release Follow-Up: 2026-11-17

The user subsequently requested a release. Mac direct beta `1.0.1 (53)` is now
published with verified public downloads, a signed update feed and website
links. See the [release receipt](mac-direct-release.md#meeting-start-recovery-beta-2026-11-17)
for source, CI, signatures and remaining acceptance checks. No iOS upload or
production-app replacement was performed.
