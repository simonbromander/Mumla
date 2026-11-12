# Native and Classic Interface Styles

## Scope

Offer two independent preferences on macOS and iOS:

- Style: Classic (the existing Rams-inspired recorder) or Native (platform navigation,
  system typography, standard controls, and restrained materials).
- Appearance: System, Light, or Dark, available with either style.

Existing installations start in Classic. Changing style must not recreate recording
services, change audio permissions, clear history, or alter transcription settings.
Preferences are local to the device. No network requests or new permissions.

## Implementation

1. Add a persisted style preference and environment-driven palette and typography.
2. Adapt shared buttons, toggles, displays, surfaces, and sheets. Preserve Classic.
3. Use native sidebar navigation on Mac and native tabs on iOS. Include the Mac
   recording overlay; keep its sizing and non-activating behavior unchanged.
4. Add the style picker next to Appearance in both apps' settings.
5. Carry the style into the keyboard's existing shared session snapshot.

## Acceptance

- Style and appearance persist independently, including unknown-value fallback.
- Both styles support light/dark, Reduce Motion, and Reduce Transparency.
- Main recorder remains non-scrolling on iPhone; labels fit compact layouts.
- Shared rendering tests, Swift package tests, Mac build, and iOS Simulator build pass.
- Inspect real rendered app views, including settings and the small recording overlay.
- Do not claim hosted UI tests passed when runner permissions prevent execution.

## Non-goals

No downloadable skins, new settings architecture, changes to speech/summary models,
cloud providers, recording behavior, release publication, or website changes.

## Verification (2026-11-12)

- Mac app and UI-test target build successfully. Manually checked live switching,
  native navigation, light/dark, compact settings and meeting views, and restoration
  of the Classic title bar. Synthetic overlay preview does not open the microphone.
- iOS Simulator: 22 hosted tests and the three new native-style UI tests pass,
  including persistence, unchanged history, non-scrolling recorder, and large text
  at compact phone width. The existing two appearance UI tests also pass.
- Swift package: 359 tests executed, 9 optional tests skipped, one existing
  environment-dependent failure in the DJI update/model gate test while macOS
  Secure Input is enabled. All new style tests pass. An earlier full run with
  Secure Input disabled passed; do not disable security protections to run tests.
- Mac hosted click tests compile, but the runner waits for UI Automation access;
  execution was cancelled without granting new permissions. They are not reported
  as passing. Older-OS material fallbacks and physical-device haptics still need
  acceptance testing before a release.
- Reading sheets keep full Dynamic Type. The non-scrolling native recorder's
  instrument labels cap at XXX Large to fit compact screens; VoiceOver retains
  their full labels. Copy/share controls stay above the native tab bar.

Development evidence is under `.build/SkinReview/` (not committed). No recordings,
personal transcripts, signing files, or screenshots of private data are included.
