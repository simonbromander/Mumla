# Mumla TestFlight Runbook

Mumla iOS and macOS use the preserved App Store bundle identity:

- Bundle ID: `com.mumla.app`
- Team ID: `PF2PWR4YG4`
- Version: `1.0.1`

## Verified macOS Release: 2026-09-28

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

Open TestFlight on a Mac signed into an existing internal tester account, select
Mumla, and install build 25. First launch downloads the Swedish model separately.
Recheck live status before reusing this dated release snapshot.

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
