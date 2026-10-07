# Mumla

Private, Swedish-first dictation for macOS and iOS. Native Swift apps, on-device
speech recognition, and a tactile, recorder-inspired interface.

[Website](https://mumla.app) | [Mac betas](https://github.com/simonbromander/Mumla/releases)
| [Contributing](CONTRIBUTING.md) | [Development](docs/development.md)

## What Works Today

- Swedish dictation with Pianissimo running locally through CoreML and FluidAudio.
- A Mac menu-bar recorder, configurable hold/double-tap hotkey, clipboard-preserving
  paste, and a manual-copy fallback when insertion cannot be confirmed.
- iPhone/iPad recording, local history, transcript copy/share, and a replacement dictionary.
- An iOS keyboard with Swedish/English typing assistance and an explicit dictation-session flow.
- Matching tactile controls, iPhone haptics, and System / Light / Dark appearance.

**This is an early-stage app.** English speech recognition, automatic model routing,
meeting capture, and iCloud sync are not implemented yet. Swedish/English keyboard
typing assistance is not English speech recognition. The accuracy and latency
targets still need evaluation on real, consented recordings.

Audio and transcripts are not sent to a transcription service. Model downloads
and user-requested Mac update checks use the network; there is no analytics backend.
Models are downloaded after installation, not committed or bundled in this repo.

The full Mac hotkey/paste workflow uses the direct-download build and requires
Microphone, Input Monitoring, and Accessibility permissions. The sandboxed Mac
App Store/TestFlight variant has different restrictions; open source does not
bypass macOS security. See [Mac distribution](docs/mac-app-store-compatibility.md).

## Build And Test

Use a Mac with **Xcode 26 or later**, its command-line tools, and Swift 6.
The apps target macOS 14+ and iOS 17+. Apple silicon is recommended for model work.
XcodeGen is needed only to regenerate the checked-in Xcode project.

```bash
git clone https://github.com/simonbromander/Mumla.git
cd Mumla
swift test
ruby -e 'Dir.glob("fastlane/tests/*_test.rb").sort.each { |path| require File.expand_path(path) }'
open Mumla.xcodeproj
```

Choose `Mumla` for iOS, `MumlaMacDirect` for the full Mac workflow, or `MumlaMac`
for the sandboxed Mac variant. No release certificates or App Store Connect
credentials are needed for package tests or Simulator builds.

[The development guide](docs/development.md) contains signing-free build commands,
Simulator tests, model setup, and instructions for using your own signing identities
on a physical iPhone. Do not change the official bundle IDs or signing settings in
a contribution.

## iOS Keyboard

Add Mumla in Settings > General > Keyboard > Keyboards. Full Access is required
for **local App Group communication**, not cloud transcription; normal typing
works without it. Download the model, explicitly start a 15-minute session in
Mumla, return to your writing app, and select Mumla with the globe key.

The containing app owns the microphone and transcription; the keyboard inserts
the result directly without the clipboard. iOS does not provide a supported
automatic app-and-back hop. Background audio, real keyboard handoff, and haptics
need physical-device testing, separate from Simulator checks.

## Architecture

| Directory | Responsibility |
| --- | --- |
| `Sources/MumlaCore` | Shared contracts, local storage, dictionary, hotkey gestures, keyboard protocol, evaluation |
| `Sources/MumlaAudio` | Microphone capture, verified model installation, local transcription |
| `Sources/MumlaUI` | Shared recorder controls, appearance, keyboard UI, licensing notices |
| `Sources/MumlaMac` | Menu bar, global hotkey, Accessibility, paste, floating recorder, direct updates |
| `Apps/iOS` | iOS app, custom keyboard extension, Live Activity |
| `Tests` | Package, native hosted, and UI tests |
| `Configuration` | Pinned model revisions, sizes, and SHA-256 checksums |

This is a fresh implementation, not the old Mumla cloud architecture.
There is no cloud transcription fallback, account system, or paywall backend.

## Contribute

Bug reports, accessibility improvements, native-platform fixes, Swedish quality
work, and design polish are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md),
then open an [issue](https://github.com/simonbromander/Mumla/issues) or a focused PR.
For vulnerabilities, use [private reporting](SECURITY.md), not public issues.

- [Implementation plan](docs/implementation-plan.md)
- [Design system](docs/design-system.md) and [light appearance](docs/light-appearance.md)
- [Keyboard architecture and acceptance checks](docs/keyboard-plan.md)
- [Phase 0 evaluation](docs/phase-0-evaluation.md)
- [Maintainer release runbook](docs/testflight.md)

The example `.wav` files are text placeholders for manifest-validation tests,
not speech recordings. Private evaluation audio must stay outside Git.

## License And Credits

Mumla's original code and assets are available under the [MIT License](LICENSE).
Third-party components and downloaded model weights retain their own licenses:
FluidAudio uses Apache 2.0; Sparkle includes MIT/BSD and other notices; Pianissimo,
its CoreML conversion, and the NVIDIA Parakeet base model use CC BY 4.0.
See [third-party notices](THIRD_PARTY_NOTICES.md). The model licenses are not replaced
by Mumla's MIT license.

Forks are welcome. Use your own signing identities and make it clear that your
build is not an official Mumla release.
