# Mumla TestFlight Runbook

Mumla iOS and macOS use the preserved App Store bundle identity:

- Bundle ID: `com.mumla.app`
- Team ID: `PF2PWR4YG4`
- Version: `1.0.1`

## Keyboard Build Prerequisites

The keyboard implementation on main is not a TestFlight release. Before its
first signed archive, verify the extension identifiers and App Group capability:

- `com.mumla.app.keyboard`: keyboard extension, new identifier.
- `com.mumla.app.widgets`: keyboard Live Activity, preserved identifier.
- Both extensions and `com.mumla.app` require `group.com.mumla.app`.
- All three targets must have matching version/build numbers, distribution
  signatures and profiles for team `PF2PWR4YG4` with `get-task-allow=false`.
- Audit the embedded `.appex` bundles as well as the containing app. Neither
  extension should link FluidAudio or have microphone/network entitlements.
- Run the physical-iPhone checklist in [keyboard-plan.md](keyboard-plan.md).
  Unsigned device builds, Simulator tests and fixtures do not prove background
  audio, Neural Engine transcription or physical haptics.

## macOS Release 29: 2026-10-01

- macOS `1.0.1 (29)`, source commit `7bfe96c` (recorder rendering fix from
  `b151913`).
- App Store Connect accepted the package at `2026-10-01T07:46:30Z`.
  Processing completed at `2026-10-01T07:49:42Z`.
- Build ID: `b026878f-4e70-428a-9e69-5651e8174b82`; verified `VALID` and
  `IN_BETA_TESTING` at `2026-10-01T07:51:06Z`. Both existing internal groups
  `Test` and `Friends` include the build. No audience changes or external beta
  review submissions were made; external state is `READY_FOR_BETA_SUBMISSION`.
- All 67 core/Mac tests and the Mac release preflight passed, including native
  panel-rendering checks for recording, short transcripts, and long transcripts.
  Archive/export passed. Exported app and installer signatures were verified
  against team `PF2PWR4YG4`; the app is universal arm64/x86_64, hardened,
  sandboxed, and has microphone/network entitlements without debugging access.
  The distribution profile expires `2027-07-03T11:46:39Z`.
- Fixes square bottom-edge artifacts and clips the mini recorder to transparent,
  rounded corners without making the panel focusable.
- Full unrestricted cross-app paste/learning still requires the direct Mac
  build, not the standard TestFlight sandbox. This release does not establish
  live auto-paste acceptance or resolve the sandbox limitation.
- Swedish and English testing notes from `fastlane/testflight/macos-1.0.1-29.json`
  were published and read back successfully at `2026-10-01T07:50:51Z`.
- Package SHA-256:
  `0358880b3791a5dfe4ef48e739521de873fe482acd4a8960b9921d162d60bf46`.
- Artifact: `.build/TestFlightMac/Mumla.pkg`; preserved package, expanded app,
  and entitlement/profile audit under `.build/ReleaseAudit29/`. Validation and
  upload logs are under `.build/release29-*.log`.
- iOS remains at its verified build 27; no iOS upload is part of this Mac release.

## macOS Release 28: 2026-09-30

- macOS `1.0.1 (28)`, source commit `7ff8af8` (paste changes from `1b674ef`).
- App Store Connect accepted the package at `2026-09-30T16:32:35Z`.
  Processing completed at `2026-09-30T16:34:43Z`.
- Build ID: `36b9e22c-8252-48db-ac79-d709b26119b8`; verified `VALID` and
  `IN_BETA_TESTING` at `2026-09-30T16:35:41Z`. Both existing internal groups
  `Test` and `Friends` include the build. No audience changes or external beta
  review submissions were made; external state is `READY_FOR_BETA_SUBMISSION`.
- 65 core/Mac tests and the Mac release preflight passed. Archive/export passed.
  The exported package's app and installer signatures were checked against team
  `PF2PWR4YG4`. The app is universal arm64/x86_64, hardened, sandboxed, and has
  microphone/network entitlements without a debugging entitlement. The embedded
  distribution profile expires `2027-07-03T11:46:39Z`.
- The package includes offline About/license notices and the paste-confirmation,
  clipboard-restoration, and successful-pill-dismissal changes. Full unrestricted
  cross-app paste/learning still requires the direct Mac build, not the standard
  TestFlight sandbox. Live cross-app device acceptance remains unverified.
- Swedish and English testing notes from `fastlane/testflight/macos-1.0.1-28.json`
  were published and read back successfully at `2026-09-30T16:35:44Z`.
- Package SHA-256:
  `2ec82a0a07f7cf1649aa6c7a0e44c27faac395d07a93f9bd3bbc3cbef1817d6e`.
- Artifact: `.build/TestFlightMac/Mumla.pkg`; preserved package, expanded app,
  and entitlement/profile audit under `.build/ReleaseAudit28/`.
- iOS remains at its verified build 27; no iOS upload is part of this Mac release.

## Verified iOS and macOS Release: 2026-09-30

- Both platforms: `1.0.1 (27)`, source commit `5bf1474`.
- iOS build ID: `d9098b27-ea63-4fb4-b821-e25eb63de0ce`.
- macOS build ID: `4685aac4-c5a3-4f88-9abd-0f9c7f8902b1`.
- App Store Connect app `6759602919`; both builds verified `VALID` and
  `IN_BETA_TESTING` at `2026-09-30T13:48:44Z`.
- Both are included in the existing internal `Test` and `Friends` groups.
  No audience changes or external review submissions were made.
- English and Swedish notes were published and read back on both platforms.
- The release includes the fixed recorder console, orange mechanical mode keys,
  retro typography, compact transcript actions, and offline About/model credits.
- 53 core/Mac tests and 27 iPhone/iPad UI runs passed for this release.
  Exported distribution signatures and entitlements were checked; the Mac
  installer signature was verified and its app is universal arm64/x86_64.
- Physical haptics and microphone quality still require device acceptance.
- The Mac TestFlight app is sandboxed. Its unrestricted cross-app Accessibility
  insertion/learning workflow is not supported by that sandbox. See
  [the direct Mac build](mac-direct-release.md) for the full dictation version.
- Build 27 does **not** include the subsequent auto-paste changes. Do not present
  it as the auto-paste fix.

Release state is a dated snapshot; use `fastlane ios beta_status` to refresh it.

## Previous iOS and macOS Release: 2026-09-29

- Both platforms: `1.0.1 (26)`, source commit `768bdcc`.
- iOS build ID: `2f758716-3a5d-481c-ba24-3560c9fb9ba8`.
- macOS build ID: `d6256734-6a31-4b94-8d3e-ad0b246b7791`.
- App Store Connect app `6759602919`; both builds verified `VALID` and
  `IN_BETA_TESTING` at `2026-09-29T04:51:42Z`.
- Both are included in the existing internal `Test` and `Friends` groups.
  No audience changes or external review submissions were made.
- Both preflights and archives/exports passed. Exported app signatures,
  identities, and distribution entitlements were checked. The Mac installer
  signature was verified; the Mac app is universal arm64/x86_64 and sandboxed.
- 50 core/Mac tests and 14 iPhone/iPad UI runs passed for this release.
- English and Swedish testing notes were published and read back successfully;
  source notes are under `fastlane/testflight/*-1.0.1-26.json`.
- Physical haptics, microphone quality, and cross-app hotkey/paste behavior in
  the Mac TestFlight sandbox still need device acceptance.
- The fixed-console, orange-key, typography, and About changes after `768bdcc`
  are not included in build 26 until a subsequent release is uploaded.

## Previous macOS Release: 2026-09-28

- Build: `1.0.1 (25)`, native macOS, macOS 14 minimum.
- App Store Connect app: `6759602919`.
- Build ID: `d96538d7-d0b8-4115-a0ab-7dc5e328798e`.
- Live processing state: `VALID`; internal state: `IN_BETA_TESTING`.
- Existing internal groups `Test` and `Friends` both include this build through
  their automatic all-builds access. No testers or groups were added.
- External state: `READY_FOR_BETA_SUBMISSION`. No external review was submitted.
- App signature and Mac App Store installer-package signature verified.
  App Sandbox and microphone-input entitlements are present; debugging
  entitlement is absent.
- Archive/export, 28 core tests, and the Mac Debug build passed in the release
  run. Native UI screenshots were inspected. This does not establish successful
  installation or audio/Accessibility behavior on a tester's Mac.
- Swedish and English testing notes were published and verified, and are retained in
  `fastlane/testflight/macos-1.0.1-25.json`.

First launch downloads the Swedish model separately.

## Commands

```bash
xcodegen generate --spec project.yml
swift test
bundle exec fastlane ios preflight
bundle exec fastlane ios build
bundle exec fastlane ios upload
bundle exec fastlane ios mac_preflight
bundle exec fastlane ios mac_build
bundle exec fastlane ios mac_upload
```

If Bundler is not configured for this checkout, use the system Fastlane:

```bash
fastlane ios preflight
fastlane ios build
fastlane ios upload
fastlane ios mac_preflight
fastlane ios mac_build
fastlane ios mac_upload
```

## Evidence To Record

- Preflight result: team, bundle ID, App Store Connect record status.
- Artifact result: `.build/TestFlight/Mumla.ipa`,
  `.build/TestFlight/Mumla.app.dSYM.zip`, and
  `.build/Mumla-fastlane.xcarchive`.
- Signature: `codesign --verify --deep --strict --verbose=2` on the archived
  `.app`.
- Entitlements: app and embedded provisioning profile, especially
  `application-identifier` and `get-task-allow=false`.
- Upload result and TestFlight processing/availability separately.

## macOS Notes

- The native macOS target is `MumlaMac`.
- macOS TestFlight uses the existing App Store Connect app record for
  `com.mumla.app`; `com.mumla.mac` is not present in App Store Connect.
- macOS artifacts are written to `.build/TestFlightMac/` and
  `.build/MumlaMac-fastlane.xcarchive`.
