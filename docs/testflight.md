# Mumla TestFlight Runbook

Mumla iOS uses the preserved App Store bundle identity:

- Bundle ID: `com.mumla.app`
- Team ID: `PF2PWR4YG4`
- Version: `1.0.1`

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
