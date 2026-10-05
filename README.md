# Mumla

Mumla is a native, on-device dictation app for macOS and iOS. Its recorder-inspired
interface pairs a recessed sage display with tactile graphite or white controls
and iPhone haptic feedback. Swedish dictation and an iOS keyboard are implemented;
English routing, meetings and private iCloud sync remain planned work.

This repo intentionally starts clean. The old `kb-ios` repo is kept locally as a
reference at `/Users/bob/projects/_references/kb-ios`, but this implementation
does not inherit its Modal backend, StoreKit quota, paywall, or cloud ASR flow.

## Preserved Identity

- iOS bundle ID: `com.mumla.app`
- App group: `group.com.mumla.app`
- iCloud container: `iCloud.com.mumla.app`
- Developer team observed in the old project: `PF2PWR4YG4`

Both Xcode apps use `com.mumla.app` for TestFlight under the existing App Store
Connect record. The local macOS development bundle retains `com.mumla.mac`.
The unrestricted Mac app is also intended for Developer ID distribution;
cross-app hotkeys and Accessibility behavior must be validated separately in
the sandboxed TestFlight edition.

## Native Apps

```bash
xcodegen generate
open Mumla.xcodeproj
```

Choose `Mumla` for iOS or `MumlaMac` for macOS. Both use the local `MumlaCore`,
`MumlaAudio`, and `MumlaUI` packages. Download the Swedish model in the app before
recording. iOS supports recording, on-device transcription, history, copy/share,
a persistent replacement dictionary and the Mumla keyboard.

For the keyboard, add Mumla under iOS Settings > General > Keyboard > Keyboards
and enable Full Access for local App Group communication. Open Mumla's keyboard
setup, start a 15-minute session, switch back to your app and select Mumla with
the globe key. Recording and transcription stay in the containing app; the
extension inserts text directly, without the clipboard. Normal typing works
without Full Access. The model-backed background session and haptics still need
physical-iPhone acceptance. See [the keyboard plan](docs/keyboard-plan.md).

See [the design system](docs/design-system.md) and
[TestFlight release instructions](docs/testflight.md).

## Phase 0

The first deliverable is the spike that decides whether the product is worth
building:

- Convert or obtain a CoreML Pianissimo Swedish model compatible with FluidAudio.
- Benchmark WER and delay on the owner's real dictation clips.
- Verify automatic Swedish/English routing.
- Decide fp16 vs int8 with real accuracy and load-time numbers.

Run the current harness:

```bash
swift test
swift run mumla-phase0 validate Evaluation/phase0-manifest.example.json
swift run mumla-phase0 score Evaluation/phase0-manifest.example.json Evaluation/phase0-predictions.example.json
swift run mumla-phase0 score Evaluation/phase0-manifest.example.json Evaluation/phase0-predictions.example.json --json
python3 scripts/resolve_hf_artifact_manifest.py Configuration/model-artifacts.markstrom-pianissimo-coreml.template.json Configuration/model-artifacts.markstrom-pianissimo-coreml.resolved.json
python3 scripts/download_hf_artifact.py Configuration/model-artifacts.markstrom-pianissimo-coreml.resolved.json ModelCache/markstrom-pianissimo-sv-coreml
swift run mumla-phase0 verify-model Configuration/model-artifacts.markstrom-pianissimo-coreml.resolved.json ModelCache/markstrom-pianissimo-sv-coreml
python3 scripts/stage_coreml_artifact.py ModelCache/markstrom-pianissimo-sv-coreml ModelCache/markstrom-pianissimo-sv-coreml-compiled --force
swift run mumla-model-probe load ModelCache/markstrom-pianissimo-sv-coreml-compiled
swift run mumla-model-probe transcribe ModelCache/markstrom-pianissimo-sv-coreml-compiled /path/to/audio.wav --language sv
swift run mumla-model-probe transcribe ModelCache/markstrom-pianissimo-sv-coreml-compiled /path/to/audio.wav --language sv --json --json-output /tmp/mumla-predictions.json
swift run mumla-model-probe transcribe-manifest ModelCache/markstrom-pianissimo-sv-coreml-compiled /path/to/phase0-manifest.json --json-output /tmp/mumla-predictions.json --language expected
```

See [docs/implementation-plan.md](docs/implementation-plan.md) and
[docs/phase-0-evaluation.md](docs/phase-0-evaluation.md).

## macOS App

Run the development menu-bar app:

```bash
swift run mumla-mac
```

Build a local `.app` bundle:

```bash
./scripts/build_macos_app_bundle.sh
open .build/debug/Mumla.app
```

During development the app looks for a compiled local Pianissimo model at
`ModelCache/markstrom-pianissimo-sv-coreml-compiled` in the repo, or at
`~/Library/Application Support/Mumla/Models/markstrom-pianissimo-sv-coreml-compiled`.
If no compiled model exists, the Settings window and menu bar include a
download action. The app downloads the pinned CoreML artifact, verifies SHA-256
checksums, then compiles the `.mlpackage` files into Application Support.
