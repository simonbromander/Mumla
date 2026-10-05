# Local macOS hotkey investigation, 2026-10-05

## Live findings

- The initially resolved `Mumla` app was the old development app, version
  `0.1.0 (1)`, bundle `com.mumla.mac`. It was closed before testing the current
  direct build, so two Mumla listeners were not running together.
- The current GitHub app in `.build/DirectMac/Mumla.app` is `1.0.1 (35)`, bundle
  `com.mumla.app`, signed with this team's Developer ID Application identity,
  hardened, notarized, and not sandboxed.
- The current app's Settings reported missing Input Monitoring. System Settings
  showed one enabled `Mumla` entry, but a narrowly filtered, read-only permission
  lookup identified that grant as `com.mumla.mac`, not `com.mumla.app`.
- The current app also had no transcription model installed on this Mac. Hotkey
  stage diagnostics can be tested without recording or downloading a model;
  end-to-end recording and paste cannot be accepted in that state.
- No permissions were granted or reset during this investigation.
- Native UI automation rejects modifier-only presses, so it cannot produce a
  physical Ctrl hold or double tap. A Ctrl shortcut sent through automation did
  not change the trigger-stage readout; this is not proof about physical Ctrl
  events. Physical key acceptance remains outstanding.

## Reproduced lifecycle defects

Three new tests failed against the previous implementation:

1. When re-enabling a disabled global tap failed, the source was stopped without
   restoring the in-app fallback. Ctrl could then fail even inside Mumla.
2. Retrying a local-only listener after app activation reset a pending hold.
3. A silently dead global listener had no repair path without an app-focus
   change. A real main-run-loop wait of 6.5 seconds did not reinstall it.

These are deterministic lifecycle reproductions using an injected event source,
not a claim that the user's physical-key failure has been reproduced.

## Changes

- Restore the local fallback immediately after a failed tap resume, while
  continuing to report that the global listener is unavailable.
- Preserve a healthy local-only listener and its pending gesture on routine
  activation retries. Explicit manual reconnect still forces a restart.
- Check listener health every five seconds, with one second of scheduling
  tolerance, in common run-loop modes. Healthy listeners are not restarted and
  permission is never requested by this check. A working in-app hold on a known
  local fallback is not interrupted by a global repair attempt.
- Suspend the listener on sleep/session resignation and reinstall it on
  wake/session activation. Suspension cancels dictation, including hands-free;
  stopping the listener invalidates both timers.
- Include the running bundle identity in copied hotkey diagnostics.

## Verification

- All six additional regression tests and the existing suite passed:
  `swift test`, 130 tests, zero failures.
- New tests cover automatic background repair with a real run-loop timer,
  fallback preservation, active-gesture preservation, revoked permissions, and
  ensuring a stopped listener cannot restart itself.
- Evidence log: `.build/hotkey-recovery-tests-20261005.log`.
- A universal Developer ID signed local candidate, `1.0.1 (36)`, built
  successfully and passed deep/strict code-signature verification. It launched
  as a menu-bar process from
  `.build/DirectVerification/Build/Products/Direct/Mumla.app`. This candidate has
  not been submitted for notarization or published. Build evidence:
  `.build/hotkey-recovery-build-20261005.log`.
- The local candidate's 20-second idle sample showed no measurable CPU-time
  increase (0.0% at the sample resolution) and 80.6 MB RSS. This was the
  hidden-window, no-model, missing-global-permission state; it is not a
  performance sign-off for recording or the authorized global-listener state.

## Remaining physical acceptance

1. Enable Input Monitoring for the exact signed `com.mumla.app` app being tested,
   not merely the old same-name entry. Grant Accessibility separately for paste.
2. In Mumla Settings, confirm the listener reports ready, then physically hold
   Ctrl for at least 250 ms and release. The gesture readout should advance.
3. Repeat with TextEdit focused, a new disposable document, and Mumla's menu
   closed. Check left/right Ctrl, double tap, shortcut cancellation, and Esc.
4. Repeat after sleep/wake and after switching applications. Actual sleep/wake
   acceptance has not been performed by automation.
5. With the model installed and microphone access granted, verify recording,
   release-to-paste, and clipboard restoration independently of gesture stages.

This is a local investigation and candidate fix, not a new GitHub or TestFlight
binary release and not a physical-key acceptance sign-off.
