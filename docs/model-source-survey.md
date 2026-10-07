# Model Source Survey

Checked on 2026-09-24.

## Primary Sources

- `KlangAI/pianissimo-sv`
  - Upstream Swedish model.
  - Public Hugging Face model.
  - License tag: `cc-by-4.0`.
  - Artifacts: `.gitattributes`, `README.md`, `pianissimo-sv.nemo`.
  - API snapshot SHA: `8f1f6d8f8bd7482a5ea1d2bfaf6ef5be61597138`.

- `FluidInference/parakeet-tdt-0.6b-v3-coreml`
  - CoreML conversion of NVIDIA Parakeet TDT v3.
  - Public Hugging Face model.
  - License tag: `cc-by-4.0`.
  - Contains CoreML bundles and `parakeet_vocab.json`.
  - API snapshot SHA: `7dd20fe6b1797d35f5e3307e8b1732d9a178edfe`.

- `markstrom/pianissimo-sv-coreml`
  - Community CoreML conversion of KlangAI Pianissimo.
  - Public Hugging Face model.
  - License tag: `cc-by-4.0`.
  - Contains `Preprocessor.mlpackage`, `Encoder.mlpackage`,
    `Decoder.mlpackage`, `JointDecisionv3.mlpackage`, `parakeet_vocab.json`,
    and attribution/license files.
  - API snapshot SHA: `106fa163a138a0db6737e0c50494269e07f508d0`.
  - Initial artifact template:
    `Configuration/model-artifacts.markstrom-pianissimo-coreml.template.json`.
    It pins filenames and revision.
  - Resolved artifact manifest:
    `Configuration/model-artifacts.markstrom-pianissimo-coreml.resolved.json`.
    It pins byte sizes and SHA-256 checksums for the current candidate revision.
  - Artifact metadata resolver:
    `scripts/resolve_hf_artifact_manifest.py`. It fills sizes and SHA-256 values
    from the pinned Hugging Face revision, using LFS metadata for large model
    files and hashing small non-LFS files directly.
  - Artifact downloader:
    `scripts/download_hf_artifact.py`. It downloads only the manifest files,
    resumes `.part` files, and verifies SHA-256 before moving files into place.
  - Bring-up status:
    downloaded, checksum-verified, compiled with `xcrun coremlcompiler`, loaded
    through FluidAudio, and transcribed the local Swedish smoke clip on
    2026-09-24.

## Fallback And Comparison Sources

- `moonhouse/pianissimo-sv-mlx`
  - MLX/safetensors conversion for Apple Silicon experiments.
  - Useful if CoreML conversion fails but a Mac-only path still looks viable.
  - API snapshot SHA: `74b386f56bf7178a540ec4bc7c3acfc81efdd9ad`.

- `moonhouse/pianissimo-sv-onnx`
  - Int8 ONNX conversion.
  - Useful as a conversion reference and non-Apple comparison path.
  - API snapshot SHA: `72c38267654dadd538bceac7a851de00fb55f11a`.

## Reference Code

- Previous Mumla implementation
  - Apple identity and release continuity only; private repository details omitted.
- Klang's `pianissimo-cli`
  - Klang's offline CLI and worker setup.
- Klang's `pianissimo-examples`
  - Minimal local NeMo transcription example and audio-format notes.
