# Mumla Keyboard

Status: experimental internal beta; physical-iPhone acceptance is pending.
The App Group is assigned to the app and both extensions. Updated 2026-10-06.

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
Tapping an inactive mic shows the activation requirement inside the keyboard,
where it can be presented reliably; it never opens another app or starts audio.
An unresponsive heartbeat is distinguished from a missing or expired session,
and termination reasons remain visible in the keyboard and containing app.

The explicitly started microphone session uses play-and-record with mixing,
so it can coexist with the host app's audio. Calls, actual interruptions,
route changes, locking and expiry still stop it. This configuration change
must be verified on a physical iPhone; simulator configuration tests do not
prove background microphone continuity.

An unfinished clip blocks new sessions to protect that audio. Keyboard setup
offers transcription or an explicitly confirmed discard instead of leaving
the session-start key disabled without a recovery path. Errors from starting
the session are shown in the setup sheet itself.

Full Access is needed only to write local commands in group.com.mumla.app.
Typing works without it. No networking, telemetry, whole-field scraping or
clipboard use in the keyboard. Typing assistance uses only the context supplied
by UITextDocumentProxy; that context is transient and cleared when the keyboard
disappears. Secure fields use Apple's system keyboard.

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

## Everyday Typing: 2026-10-06

Implement the approved first slice: automatic capitalization honoring the
host field, double-space punctuation, long-press accents, spacebar cursor
movement, and local Swedish/English spelling suggestions and conservative
autocorrection. Keep the recorder materials and existing dictation contract.

- Use a small pure-core editing policy with tests for bounded word replacement,
  sentence boundaries, rapid spaces, correction undo and cursor gestures.
- Use UIKit's local UITextChecker and supplementary lexicon; typed context is
  transient, never logged, persisted or sent over the network. Typing assistance
  works without Full Access or a microphone session.
- Preserve unknown names, digits, URLs, email addresses, mixed-case identifiers,
  selections and mid-word edits. Respect fields that disable autocorrection or
  capitalization. Only replace the current word, never the whole host field.
- Three fixed suggestion slots, a Swedish/English typing-language key and an
  autocorrect switch stay within the keyboard bounds. Long-press alternatives
  occupy that same strip, not an out-of-bounds popup. Backspace can undo the last
  automatic replacement; cursor/focus changes invalidate pending replacements.
- Verify core and hosted tests, the actual extension in Simulator, light/dark
  compact portrait/landscape layouts and regression coverage for dictation.
  Physical haptics and real-app typing remain device acceptance checks.

Out of this slice: swipe typing, emoji picker, Apple prediction-engine parity,
new ASR languages, new microphone-session behavior and an automatic release.

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

### Physical Acceptance Before Stable Release

An experimental internal TestFlight build can exercise this checklist, with the
unverified behavior stated in its testing notes. Passing Simulator fixtures is
not sufficient to mark the keyboard accepted for a stable release.

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

Typing acceptance also needs a physical iPhone: Swedish and English spelling,
contacts/text shortcuts, sentence capitalization, manual shift/caps override,
double-space punctuation, accented letters, cursor dragging and backspace undo
in Messages, Mail and Notes. Check that secure fields switch to Apple's keyboard
and literal URL/email fields never apply corrections. Verify haptics and typing
while the microphone session starts, ends or becomes unavailable.

### Connection and Activation Checks: 2026-10-06

- All 132 core/Mac tests and 31 release-helper tests (74 assertions) passed.
- Five hosted tests passed, including the real audio callback regressions and
  a check that the keyboard's audio configuration enables mixing without
  activating a microphone.
- The complete signed Simulator run passed 18 of 19 UI cases. The remaining
  case queried the LCD as the wrong accessibility element type; its stale-state
  message and typing assertions already passed. After correcting only that
  selector, the targeted case passed. Together the runs cover all 24 hosted/UI
  cases, not a single clean full-suite run.
- Real-extension fixtures exercise typing without Full Access, activation
  guidance, start/stop/consume and exactly-once insertion, and stale-session
  diagnostics. The saved-clip fixture verifies that discard requires confirmation
  and unlocks session startup; cancel leaves the clip and startup gate intact.
- A system alert did not appear from the real keyboard extension in the first
  iteration. Activation guidance now stays inside the extension's view bounds;
  its close key and keyboard switcher remain usable. Compact screenshots for
  connection loss and saved-clip recovery were inspected without overlap.
- Evidence: `.build/keyboard-connection-tests-20261006.xcresult`,
  `.build/keyboard-connection-selector-rerun-20261006.xcresult` and
  `.build/KeyboardConnectionScreenshots-20261006/`.
- These fixtures do not exercise the actual microphone or background handoff
  to Messages/Mail/Notes. No physical iPhone was connected to the build Mac.
  Retest session continuity on device and report the exact keyboard status and
  whether the Live Activity remains visible if it fails.

### Everyday Typing Verification: 2026-10-06

- All 143 core/Mac tests passed, including 11 new editing-policy tests.
- A full compact-iPhone Simulator run passed all 21 UI cases and 12 hosted
  cases. A final targeted run then covered the additional context-clearing
  test, literal-field suggestion guard, correction undo, accent dismissal and
  compact landscape refinements: 13 hosted tests and three iPad UI tests passed,
  followed by both real-extension iPhone typing cases passing again.
- The actual extension types without Full Access, capitalizes an empty field,
  turns rapid spaces into a period, offers local spelling suggestions, applies
  and undoes an automatic correction, inserts an explicitly chosen suggestion,
  chooses accented letters without inserting the base letter, and moves the
  cursor without adding a space. Literal fields disable correction and
  capitalization according to their traits; old suggestions cannot rewrite them.
- Light/dark compact-phone and iPad portrait/landscape screenshots were inspected
  without overlapping keys or out-of-bounds accent controls. VoiceOver has
  named accent and cursor actions; physical haptics remain unverified.
- Generic iOS Release build passed with signing disabled. App and extension
  identities are unchanged; the keyboard has no ASR-runtime or microphone-class
  linkage. This build is not an archive, upload or new TestFlight release.
- Evidence: `.build/KeyboardTypingFull-20261006.xcresult`,
  `.build/KeyboardTypingIPad-20261006.xcresult`,
  `.build/KeyboardTypingAcceptance-20261006.xcresult`,
  `.build/KeyboardTypingScreenshots-20261006/` and
  `.build/KeyboardTypingIPadScreenshots-20261006/`.

## Non-goals

English ASR, a new model, cloud fallback, next-word prediction, meeting
recording, iCloud sync, replacing the Mac hotkey, and an automatic TestFlight
upload. New extension identifiers/profiles need release-time provisioning.

## Primary References

- https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard
- https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards
- https://developer.apple.com/documentation/uikit/uitextchecker
- https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard
- https://developer.apple.com/documentation/foundation/nsextensioncontext/open(_:completionhandler:)
- https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
