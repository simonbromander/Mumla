# Mumla TestFlight Runbook

Mumla iOS and macOS use the preserved App Store bundle identity:

- Bundle ID: `com.mumla.app`
- Team ID: `PF2PWR4YG4`
- Version: `1.0.1`

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
