# Meeting System Audio Default

## Scope

Mac meetings default to System audio + microphone, including explicit Start from
a detected-call suggestion. Keep selected-app and microphone-only capture as
choices. This is separate from the Native/Classic appearance work; no iOS UI,
models, hotkeys, transcription policy or release is changed here.

## Capture And Privacy

- Use a private, unmuted stereo global Core Audio output tap, excluding Mumla's
  own audio process when registered. No existing output stream is required to
  start a global tap. Block transcript playback during capture in both the UI
  and coordinator. Keep the input-only microphone and separate writers.
- Explain that other applications and browser tabs are included before recording.
  An explicit Record/Start is still required; detection itself captures no audio.
- Preserve app-scoped taps without a global fallback if the app disappears. A
  system recording is not tied to one app's lifetime. Pause/resume retains the
  original capture scope even if setup changes while paused.
- Keep all chunks and transcription local, with the existing retention policy.
  Do not migrate old meeting manifests or rewrite their source metadata.

The global tap captures process output, not hardware microphone input. The
microphone remains a separate track. Source labels are not proof of identifying
individual speakers or acoustic echo cancellation.

## Checks

- Unit tests cover the default, explicit microphone-only choice, missing apps,
  suggestion preparation, resume scope, both tracks reaching transcription, and
  global-exclusion versus app-inclusion tap descriptions without capturing audio.
- Build the native Mac app and UI-test host; check compact light/dark setup and
  source-picker usability with silent synthetic fixtures.
- Real signed-app microphone/system-audio permission, two-sided call audio,
  headphones/speakers, output-device changes and macOS-version acceptance remain
  manual gates. Synthetic tests do not prove physical capture or call quality.

## Reference

[Apple: Capturing system audio with Core Audio taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)
and the SDK's `CATapDescription` documentation define the global-output exclusion
tap used here. No virtual driver or call bot is added.

## Verification (2026-11-12)

- Full Swift package suite: 335 tests, 9 existing opt-in skips, no failures.
- Native direct Mac Debug build and UI test host build-for-testing passed.
  UI XCTest execution still requires local UI Automation authorization and was
  not run; a compiled target is not a passing UI test run.
- Inspected actual SwiftUI compact light/English and dark/Swedish setup, and a
  long-title meeting prompt. Source and scope notice wrap; Record remains visible.
- Manual clicks in the isolated, silent UI host verified the system default,
  microphone-only selection, switching back, and explicit Start -> Stop/save.
  The fixture used no microphone, system audio tap, calendar or model download.
- Real-call capture and permissions remain unverified. No installed production
  app, public release or update feed was changed.

## Release Status (2026-11-12)

Included in experimental direct Mac `1.0.1 (47)` after exact-source CI, Developer
ID signing, notarization, fresh public-download audits and signed live-feed
verification. The release also corrects the system-audio permission description.
The real-call and permission gates above remain open; distribution verification
is not physical capture acceptance. The installed production app was not replaced.
See [release notes](releases/macos-direct-1.0.1-47.md) and
[publication evidence](mac-direct-release.md).
