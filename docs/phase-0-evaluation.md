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
swift run mumla-phase0 verify-model Configuration/model-artifacts.markstrom-pianissimo-coreml.resolved.json /path/to/downloaded/model
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
