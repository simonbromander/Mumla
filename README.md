# Mumla

Mumla is a fresh rebuild of the old Mumla idea: on-device Swedish and English
dictation for macOS first, then private meeting transcription and iOS.

This repo intentionally starts clean. The old `kb-ios` repo is kept locally as a
reference at `/Users/bob/projects/_references/kb-ios`, but this implementation
does not inherit its Modal backend, StoreKit quota, paywall, or cloud ASR flow.

## Preserved Identity

- iOS bundle ID: `com.mumla.app`
- App group: `group.com.mumla.app`
- iCloud container: `iCloud.com.mumla.app`
- Developer team observed in the old project: `PF2PWR4YG4`

The macOS app is planned as a notarized Developer ID app outside the Mac App
Store. The iOS app remains App Store/TestFlight.

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
swift run mumla-phase0 verify-model Configuration/model-artifacts.markstrom-pianissimo-coreml.resolved.json /path/to/downloaded/model
```

See [docs/implementation-plan.md](docs/implementation-plan.md) and
[docs/phase-0-evaluation.md](docs/phase-0-evaluation.md).
