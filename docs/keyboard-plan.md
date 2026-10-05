# Mumla Keyboard

Status: implemented; physical-iPhone acceptance and release provisioning pending,
2026-10-05.

## Scope

Build a Swedish iOS keyboard with the shared light/dark recorder materials,
orange mechanical recording key, real microphone meter, haptics, Swedish
letters, shift/caps, numbers/symbols, repeating delete, space, return and the
system keyboard switcher. No model or microphone access in the extension.

The containing app owns an explicitly started, 15-minute microphone session.
Only clips started with the keyboard's recording key are written to disk.
Audio stays local and the existing Pianissimo, normalizer, dictionary and
history pipeline handles transcription. Save history before publishing text.
A Live Activity identifies the active microphone session and can end it.

## Platform Contract

Apple does not document opening the containing app from a keyboard extension
with NSExtensionContext.open. Do not use responder-chain tricks, private APIs,
invisible URL buttons or automatic return-to-app claims. Start the session in
Mumla, switch back manually, then use the keyboard without another app switch.
The keyboard gives a clear inactive/full-access state rather than a dead mic.

Full Access is needed only to write local commands in group.com.mumla.app.
Typing works without it. No networking, telemetry, host-field scraping or
clipboard use in the keyboard. Secure fields use Apple's system keyboard.

The extension uses UITextDocumentProxy.insertText. Auto-insert only for a
result requested by this keyboard instance, while visible, in the same document.
Otherwise show a preview with explicit insertion. Claim a result atomically
before insertion to prevent duplicates after an extension restart; history
remains the recovery copy if the extension dies between claim and insertion.

Shared files have complete file protection, atomic writes, schema/version
checks and bounded size. Commands carry session/request IDs and expire. A
heartbeat detects a stopped/suspended app. Interruptions, protected-data loss,
audio route changes and time limits end capture. Recording is capped at ten
minutes; pending audio stays recoverable in the containing app on failure.
Background audio is active only during a user-started session. Removing the
Live Activity ends the session as well. No remote pushes or servers.

## Verification

- Core tests: round trips, malformed/oversized packets, session expiry,
  stale/wrong-session commands, legal transitions, duplicate claims, document
  and request identity, Swedish key layouts and shift state.
- Build the main app, keyboard and widget for Simulator and generic iOS Release.
  Inspect embedded extensions, entitlements, Info.plist and dependency isolation.
- Simulator UI tests/screenshots: typing, shift, symbols, controls, light/dark,
  access/session/error states, compact widths and accessibility labels.
- Physical device gate: enable keyboard and Full Access; start a model-backed
  session and test Messages, Mail and Notes; interruptions, lock, timeout,
  stop/cancel, background transcription and Live Activity end. Simulator UI and
  successful builds are not evidence of this physical-device gate.

### Recorded Results: 2026-10-05

- `swift test`: 124 tests passed, including nine keyboard contract/layout tests
  and existing Mac regressions.
- Compact iPhone Simulator: seven UI cases passed. Two exercise the real
  extension in a host text field: typing `hej åäö` without Full Access, and
  Full Access App Group start/stop/result/consume commands with direct,
  single insertion. The latter uses a DEBUG-only, fixed transcript fixture
  saved to test history before publication; it does not record or run ASR.
- iPhone 17 Pro Simulator: three layout/interaction cases passed.
- iPad mini Simulator: four cases passed, including portrait/landscape keyboard
  bounds and the existing fixed-recorder regression. Screenshots inspected.
- Generic iOS Release build passed with signing disabled. Both `.appex` bundles
  are embedded, have matching `1.0.1 (28)` metadata, and contain no FluidAudio
  ASR symbols. This is not a signed archive, upload or TestFlight release.
- Use locally signed Simulator builds for App Group tests. An unsigned Simulator
  app has no group entitlements and cannot prove the keyboard handoff. The
  successful command tests used `CODE_SIGN_IDENTITY=-`.
- Local logs/results/screenshots are retained under `.build/keyboard-*.log` and
  `.build/Keyboard*QA.xcresult`. These generated artifacts are not committed.

### Physical Acceptance Before Release

- Messages, Mail and Notes: start in Mumla, return manually, record while Mumla
  is backgrounded, stop and verify one insertion into the original field.
- Switch fields/apps or hide the keyboard during transcription: never insert
  into a different field; offer explicit insertion or recover from app history.
- Cancel, silence, repeated retry, capture/storage failure and app termination:
  no unintended text or duplicate insertion; non-cancelled audio stays recoverable.
- Lock/unlock, microphone interruption, route changes and session/clip timeouts:
  microphone stops, pending clips recover, expired sessions cannot accept commands.
- Live Activity end/dismiss, disabled Live Activities and physical haptics.
- Check network traffic during dictation; no audio/text or analytics requests.

Simulator fixtures, compiled code and source review do not close this checklist.

## Non-goals

English ASR, a new model, cloud fallback, autocorrect/predictive typing, meeting
recording, iCloud sync, replacing the Mac hotkey, and an automatic TestFlight
upload. New extension identifiers/profiles need release-time provisioning.

## Primary References

- https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard
- https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- https://developer.apple.com/documentation/foundation/nsextensioncontext/open(_:completionhandler:)
- https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
