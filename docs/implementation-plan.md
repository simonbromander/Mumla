# Mumla Implementation Plan

Status: active plan, 2026-09-24.

## Product Decision

The app name is Mumla. The PRD used Viska as a working name; all product, code,
and bundle-facing names in this rebuild use Mumla.

This is a clean-room rebuild. The old `simonbromander/kb-ios` repository is
reference-only for Apple identifiers, release lessons, and old product context.
The old architecture was an iOS-first cloud transcription product using Modal,
KB-Whisper, Whisper, StoreKit quota, and optional AI formatting. The new product
is local-first, macOS-first, and privacy-led.

## Preserved From Old Mumla

- App Store iOS app bundle: `com.mumla.app`
- App group: `group.com.mumla.app`
- iCloud container: `iCloud.com.mumla.app`
- Historical extension bundle IDs, deferred until the matching targets return:
  `com.mumla.app.widgets`, `com.mumla.app.watch`,
  `com.mumla.app.watch.widgets`, `com.mumla.app.broadcast`
- Developer team observed in project files: `PF2PWR4YG4`

## New Identity Decisions

- macOS distribution: notarized Developer ID download, outside the Mac App Store.
- macOS bundle ID: `com.mumla.mac` unless later App Store Connect constraints make
  a universal `com.mumla.app` target preferable.
- iOS distribution: TestFlight/App Store with `com.mumla.app`.
- No account system, no server-side quota, no analytics service.

## Architecture

Mumla is a native Swift/SwiftUI app with a shared Swift package:

- `MumlaCore`: pure logic, models, dictionaries, WER, routing, normalization,
  evaluation metrics, storage contracts.
- `MumlaAudio`: AVFoundation, Core Audio, model loading, FluidAudio adapters,
  VAD, clip segmentation, and transcription sessions.
- `MumlaMac`: menu bar app, floating pill, hotkey event tap, paste/clipboard
  insertion, Accessibility field observation, meeting capture.
- `MumlaIOS`: main app, keyboard extension, Live Activity, offline model store.
- `MumlaStorage`: SwiftData models, local encrypted transcript fields, CloudKit
  private database sync.

Phase 0 started with `MumlaCore` plus the evaluation CLI. On 2026-09-24 the
macOS Phase 1 app shell was started before the full owner-dataset gate by
explicit product direction. The Phase 0 quality and latency gates still decide
whether the current Pianissimo CoreML path is the one to ship.

## Model Plan

- Swedish: `KlangAI/pianissimo-sv`.
- English and first-pass multilingual routing: `nvidia/parakeet-tdt-0.6b-v3`
  using the FluidAudio CoreML path where possible.
- First Swedish CoreML candidate to test: `markstrom/pianissimo-sv-coreml`.
  It is small enough to be a practical Phase 0 path, but it is a community
  conversion and must be treated as untrusted until WER, latency, load behavior,
  and licensing metadata are verified.
- Runtime: FluidAudio for Swift/CoreML/ANE inference.
- Conversion/profiling: FluidAudio's mobius tooling and `coreml-cli` for
  CoreML load/performance checks.
- Download policy: models are downloaded after install, never bundled in the app.
- Integrity: every model artifact has pinned size and checksum before loading.
- License UI: About -> Licenses must credit KlangAI and NVIDIA under CC BY 4.0
  and state that the models were converted and/or quantized.

## Phase 0 Scope

Goal: prove that the Swedish local model is good and fast enough before building
product UI.

Inputs:

- 200 owner Swedish dictation clips with human references.
- Apple Dictation output on the same 200 clips, captured as baseline.
- 20 English clips and 20 mixed/short clips for language routing.
- At least one long Swedish sample for chunking behavior.

Tests:

- WER: same normalization pipeline for Apple baseline, original Pianissimo, and
  CoreML Pianissimo.
- Delay: release-to-text simulation for clips up to 15 seconds on an M1 Mac.
- Language routing: Parakeet first pass plus Apple's `NLLanguageRecognizer`.
- Conversion parity: CoreML Pianissimo WER within 0.5 percentage points of the
  original NeMo/PyTorch path.
- Load and idle cost: warm/cold model load, memory, and model unload behavior.
- License and model integrity: checksum, model card, attribution data.

Exit gate:

- Swedish WER is no more than 50 percent of Apple Dictation WER and no more than
  7 percent absolute on the owner clips.
- Clip <= 15 seconds inserts text within 700 ms at p95 on M1 after hotkey
  release, excluding first model download.
- Language detection is at least 97 percent on clips >= 2 seconds.
- Idle CPU is below 1 percent and memory below 150 MB with no model loaded.
- No model artifact loads unless checksum verification passes.

Kill or pivot:

- If CoreML conversion loses more than 0.5 WER points, try pause-aware 20 second
  chunking.
- If that fails, evaluate an MLX Mac-only path before building iOS.
- If Swedish WER misses the gate, stop the app build and revisit model choice.

## Phase 1 Scope

macOS dictation only:

- Hold Ctrl to dictate.
- Double-tap Ctrl for hands-free.
- Floating pill with listening, hands-free, transcribing, copied fallback, and
  language badge.
- Paste insertion with clipboard restoration.
- Last 100 dictations in history, last 10 in menu bar.
- Deterministic dictionary replacements and edit-learning guardrails.
- First-launch model download with progress, resume, checksum, and license info.
- Five-step onboarding: value, microphone, Accessibility, practice, done.

Current implementation status:

- macOS app shell, glass pill, menu bar, microphone recording, local transcriber
  adapter, paste/clipboard restore, and history are in place.
- A first-launch five-step Liquid Glass onboarding flow is in place for value,
  microphone, Accessibility, practice, and done. App settings persist locally,
  including onboarding completion and language mode.
- Dictionary entries persist locally, can be managed in the app, and are applied
  as deterministic replacements during transcript normalization.
- Secure text fields are guarded at dictation start and insertion time. Non-text
  focus falls back to copying text to the clipboard instead of blindly pasting.
- Model install is now native: the app can download the pinned Pianissimo CoreML
  artifact, resume partial files, verify checksums, and compile the CoreML
  packages into Application Support.
- Remaining Phase 1 gaps include automatic live language routing, edit-learning
  dictionary observation, launch-at-login, and release signing/notarization.

## Phase 2 Scope

macOS meetings and sync:

- Microphone plus Core Audio process taps as separate channels.
- Prompt before recording a detected meeting.
- Transcript document with timestamps, notes, playback, and Markdown export.
- iCloud private database sync with encrypted transcript text.

## Phase 3 Scope

iOS:

- Main iOS app.
- Custom keyboard session flow.
- Live Activity.
- In-person meeting recording.
- Optional on-device summaries only if Swedish quality passes owner review.

## Non-Goals For This Rebuild

- Cloud transcription fallback.
- StoreKit tiers or quota.
- Account creation.
- AI formatting presets from the old app.
- Watch, widgets, CarPlay, broadcast upload, or Obsidian export before the core
  dictation product is working.
