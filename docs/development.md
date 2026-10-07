# Local Development

## Requirements

- macOS with Xcode 26 or later, including command-line tools and an iOS Simulator runtime.
- Swift 6 from the selected Xcode. Use `xcodebuild -version` and `swift --version`
  to check your toolchain; select Xcode in Settings > Locations > Command Line Tools.
- Ruby with `minitest` for release-helper unit tests (`gem install minitest` if missing).
- Optional: XcodeGen (`brew install xcodegen`) to regenerate the project after
  changing `project.yml`. The generated project is already checked in.

The deployment targets are macOS 14 and iOS 17. Apple silicon is recommended for
CoreML/Neural Engine development. No paid Apple account, production signing key,
or App Store Connect access is needed for the checks and builds below.

## Package And Helper Tests

From the repository root:

```bash
swift test
ruby -e 'Dir.glob("fastlane/tests/*_test.rb").sort.each { |path| require File.expand_path(path) }'
```

Tests use deterministic fixtures and do not need downloaded speech models or
private recordings. The `.wav` example fixtures are text placeholders for file
and manifest validation, not valid audio; do not feed them to the model probe.

## iOS Simulator

Compile the app and embedded keyboard/widgets without signing credentials:

```bash
xcodebuild -project Mumla.xcodeproj -scheme Mumla -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/ContributorIOS \
  CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= build
```

For hosted/UI tests, use a Simulator available on your Mac. List them with
`xcrun simctl list devices available` or `xcodebuild -project Mumla.xcodeproj
-scheme Mumla -showdestinations`. Replace the example device name if necessary:

```bash
xcodebuild -project Mumla.xcodeproj -scheme Mumla -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/ContributorIOSTests \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  -only-testing:MumlaIOSTests test
```

Use the same command with `-only-testing:MumlaUITests` for UI tests, and repeat
layout/keyboard checks on an iPad Simulator. Tests use ad-hoc Simulator signing,
not an Apple certificate; App Group entitlements are needed for session tests,
so do not use `CODE_SIGNING_ALLOWED=NO` for that test run.

Alternatively open `Mumla.xcodeproj`, choose the `Mumla` scheme and an iOS
Simulator. The DEBUG-only keyboard preview harness tests fixed, synthetic
transcripts; it is not proof of real background microphone delivery.

## Direct Mac App

Build a local ad-hoc signed app without Developer ID credentials:

```bash
xcodebuild -project Mumla.xcodeproj -scheme MumlaMacDirect -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/ContributorMac \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
open .build/ContributorMac/Build/Products/Debug/Mumla.app
```

This local build is not notarized and is not a distributable official release.
Do not remove quarantine or disable Gatekeeper for downloaded builds. For compile
checks only, `CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM=` works for either Mac scheme.

Quit any installed Mumla copy before launching a development build. Builds using
the official IDs can share existing local data: back up your data privately, and
use an isolated development account for destructive tests. Do not run production
and development copies together or use the production updater in a fork.

Download the Swedish model from the app before recording. Grant Microphone,
Input Monitoring, and Accessibility to the exact local app you are testing.
Ad-hoc rebuilds may need renewed permission approval; unit tests and app-local
hotkeys do not establish global keyboard access.

For hotkey changes, test with the menu and main window closed and another editor
focused. Verify one insertion, clipboard restoration, normal-shortcut cancellation,
and the manual-copy fallback. Secure/password input must stay blocked.

## Physical iPhone And Independently Distributed Forks

Use your own Apple development account, certificates, and identifiers. The
official IDs and team in `project.yml` are public identifiers, not credentials;
they do not grant permission to sign official apps.

On a local branch that you do not submit as a contribution:

1. Set your own `DEVELOPMENT_TEAM` and unique bundle IDs for the app, keyboard,
   widgets, and test targets in `project.yml`; keep extension IDs under the app's prefix.
2. Register your own App Group and assign it to the app, keyboard, and widgets.
   Replace `group.com.mumla.app` in their entitlement files and
   `KeyboardSessionStore.appGroup` in `Sources/MumlaCore/KeyboardSession.swift`.
3. Replace the app's iCloud container references in its entitlements and Info.plist
   with your own registered container, or remove those unused capabilities for
   local development. CloudKit sync is not implemented yet.
4. Generate the project with `xcodegen generate`, select your development signing
   profiles in Xcode, and run on your device. App Groups require the appropriate
   Apple account capabilities; a free Personal Team does not provide the full keyboard flow.
5. For a Mac fork, also use your own identities/capabilities and remove or replace
   the official update feed and public key in `Apps/macOS/Mumla/Info-Direct.plist`.
   Never point your builds at the official updater as if they were official releases.

Keyboard dictation requires Full Access, an installed model, and a user-started
session in the containing app. Test switching back to Messages/Mail/Notes, repeated
recording, background/locked-device behavior, and expired-session recovery on a
physical device. Never use unsupported keyboard-to-app launch tricks.

## Models And Evaluation

Install through the app, or follow [Phase 0 evaluation](phase-0-evaluation.md)
for the pinned artifact download, checksum verification, CoreML staging, model
probe, and scoring CLI. Runtime downloads come from public Hugging Face artifacts;
no Hugging Face token is required for the pinned model.

Keep real recordings, transcripts, model caches, and evaluation results outside
Git (`Evaluation/private/` and `Evaluation/audio/` are ignored). Use synthetic or
explicitly consented clips. Do not claim WER/latency gates from placeholder
fixtures or compare results collected on different devices as equivalent.

## Release Work Is Separate

Contributor CI only tests and compiles. It has read-only repository permissions,
no signing/API credentials, and no private audio. Official distribution is a
maintainer operation described in [TestFlight](testflight.md) and
[direct Mac releases](mac-direct-release.md). A successful archive is not proof of
upload, TestFlight availability, or physical-device acceptance.
