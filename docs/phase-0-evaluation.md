# Phase 0 Evaluation

Phase 0 decides whether Mumla should continue.

## Current Harness

The repo starts with a deterministic Swift harness:

- `WordErrorRate` computes substitutions, insertions, deletions, and aggregate
  error rate.
- `TranscriptNormalizer` removes filler words and applies deterministic
  dictionary replacements.
- `LanguageRouter` encodes the PRD routing rules for auto/manual language.
- `Phase0Manifest` validates local evaluation manifests.
- `mumla-phase0` validates manifests and scores predictions.

Run:

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
swift run mumla-model-probe transcribe ModelCache/markstrom-pianissimo-sv-coreml-compiled /path/to/audio.wav --language sv --json --json-output /tmp/mumla-predictions.json
```

## Private Dataset Layout

Put real owner clips outside git:

```text
Evaluation/private/
  owner-sv-001.wav
  owner-sv-002.wav
  ...
  phase0-manifest.owner.json
  apple-baseline.predictions.json
  pianissimo-coreml.predictions.json
  parakeet-routing.predictions.json
```

`Evaluation/private/` is ignored by git.

## Manifest Format

```json
{
  "createdAt": "2026-09-24T00:00:00Z",
  "clips": [
    {
      "id": "owner-sv-001",
      "audioPath": "owner-sv-001.wav",
      "reference": "det här är den mänskliga referensen",
      "expectedLanguage": "sv",
      "durationSeconds": 7.2
    }
  ]
}
```

Predictions:

```json
[
  {
    "clipId": "owner-sv-001",
    "model": "pianissimo-coreml-fp16",
    "transcript": "det här är den mänskliga referensen",
    "latencyMilliseconds": 420,
    "detectedLanguage": "sv"
  }
]
```

## Model Bring-Up Order

1. Score Apple Dictation transcripts to establish the baseline.
2. Run original Pianissimo with NeMo/PyTorch and score the same manifest.
3. Try `markstrom/pianissimo-sv-coreml`, because a community CoreML package
   currently exists for the same base model.
4. Convert Pianissimo ourselves only if the community CoreML package fails
   accuracy, latency, loading, checksum, or compatibility checks.
5. Run FluidAudio Parakeet v3 CoreML for English and language-routing samples.
6. Measure warm latency separately from first-load compilation and downloads.

## CoreML Bring-Up

`markstrom/pianissimo-sv-coreml` downloads as portable `.mlpackage` bundles.
FluidAudio's local loader expects destination-compiled `.mlmodelc` directories,
so `scripts/stage_coreml_artifact.py` performs that compile step with
`xcrun coremlcompiler` and stages the vocabulary beside the compiled models.

`mumla-model-probe` then loads that staged directory through FluidAudio and can
transcribe a single clip. Use `--json-output` to write a clean prediction file
for the existing scorer; runtime logs may still appear on stdout.

## Required Reporting

Every Phase 0 run should produce:

- device model and OS version,
- model artifact ID and checksum,
- precision (`fp16`, `int8`, or other),
- aggregate WER and WER by language,
- p50/p95 release-to-text latency,
- peak RSS during transcription,
- routing confusion matrix,
- failure notes with audio clip IDs.

## Smoke Log

2026-09-24, `markstrom/pianissimo-sv-coreml`:

- Device: Mac15,6, Apple M3 Pro, 18 GB RAM.
- OS: macOS 26.3 build 25D125.
- FluidAudio package resolution: 0.17.3.
- Source artifact: 656 MB downloaded to `ModelCache/markstrom-pianissimo-sv-coreml`.
- Staged artifact: 657 MB compiled to
  `ModelCache/markstrom-pianissimo-sv-coreml-compiled`.
- FluidAudio load smoke: passed. Cold debug CLI load observed at 38,084 ms;
  later warm load observed at 154 ms.
- Transcription smoke clip:
  `/Users/bob/projects/_references/pianissimo-examples/repro/counting-sv.wav`,
  12.22 seconds, 16 kHz mono WAV.
- Transcript:
  `1. Stockholm är Sveriges huvudstad. 2. Göteborg ligger på västkusten. 3. Malmö ligger i Skåne. 4. Uppsala har ett gammalt universitet.`
- Scorer compatibility: passed with temporary one-clip manifest, 0.00% WER,
  141 ms transcription latency, 100% language accuracy.

This is not an owner-dataset Phase 0 result. It only proves artifact integrity,
CoreML compilation, FluidAudio loading, inference, and scorer handoff.
