# Third-Party Notices

Mumla's [MIT license](LICENSE) covers its original code and assets, not separately
licensed dependencies, copied attribution documents, or downloaded model weights.
The following notices remain in force. Preserve their full text when distributing
relevant components; a summary here is not a replacement for upstream terms.

## Speech Models

The Watch companion uses [WhisperKit 1.1.1](https://github.com/argmaxinc/argmax-oss-swift/tree/v1.1.1)
and the multilingual [OpenAI Whisper base model](https://huggingface.co/openai/whisper-base).
The [Argmax CoreML conversion](https://huggingface.co/argmaxinc/whisperkit-coreml)
and tokenizer downloads use pinned revisions and SHA-256 checksums in the Watch model manifest.
The runtime and model use MIT licenses. Argmax's incorporated tokenizer code also carries Apache 2.0 notices.
Full license texts ship in the Watch app's `Watch-Licenses.txt` resource.
Mumla does not retrain these weights. Recordings and inference remain on the Watch until paired-device delivery.

| Component | Attribution | License / Source |
| --- | --- | --- |
| Pianissimo-sv | Klang AI AB | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), [Model](https://huggingface.co/KlangAI/pianissimo-sv) |
| Pianissimo CoreML conversion | markstrom; original model by Klang AI AB | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), [Conversion](https://huggingface.co/markstrom/pianissimo-sv-coreml) |
| Parakeet TDT 0.6B v3, Pianissimo's base model | NVIDIA | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), [Model](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) |

Mumla currently downloads the community Pianissimo CoreML conversion using the
revision and checksums in `Configuration/`. The conversion changes the format and
attention configuration to fixed 15-second windows, uses int8 encoder weights
and fp16 decoder/joint weights, and does not retrain the weights. Those changes
were made by the conversion's author, not claimed as Mumla's training work.
See the full [conversion attribution](Sources/MumlaUI/Resources/Pianissimo-attribution.txt)
and [source survey](docs/model-source-survey.md).

A separate English Parakeet inference path is planned, not enabled in this build.
Model weights are not included in the Git repository. Retain attribution, source
links, license links, and notices of modifications when redistributing models.
Upstream evaluation numbers do not establish Mumla's product accuracy.

## Local Text Model

On Apple Silicon Macs, Qwen3.5 4B runs locally through MLX after an explicit model
download. The [Qwen Team's model](https://huggingface.co/Qwen/Qwen3.5-4B) and
[MLX Community 4-bit conversion](https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit)
use Apache 2.0. The conversion quantizes weights; Mumla does not retrain them.
The model revision, byte counts, and SHA-256 hashes are pinned in
`Sources/MumlaFormatting/QwenModelArtifact.swift`. Model weights are not committed.

[MLX Swift](https://github.com/ml-explore/mlx-swift),
[MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm), and their embedded MLX
runtime use MIT licenses, with additional upstream notices. Tokenization uses
[Swift Transformers](https://github.com/huggingface/swift-transformers), Apache 2.0.
Full model, runtime, and transitive dependency notices are retained in
[Qwen runtime notices](Sources/MumlaUI/Resources/Qwen-runtime-notices.txt) and
the Mac app's About > Licenses surface. iOS continues to use Apple's local
system model, supplied separately by the operating system on eligible devices.

## Runtime And Mac Updates

- [FluidAudio](https://github.com/FluidInference/FluidAudio), by Fluid Inference:
  [Apache 2.0 notice](Sources/MumlaUI/Resources/FluidAudio-LICENSE.txt).
- [Sparkle](https://github.com/sparkle-project/Sparkle), in direct Mac builds:
  [full license and external notices](Sources/MumlaUI/Resources/Sparkle-LICENSE.txt),
  including MIT, BSD, and other component terms.

Dependency versions are recorded in `Package.resolved` and the Xcode workspace's
resolved file. FluidAudio distributes additional notices/resources, retained in
the app's About > Licenses surface:

- [fastcluster](Sources/MumlaUI/Resources/fastcluster-LICENSE.md)
- [NeMo Text Processing](Sources/MumlaUI/Resources/NemoTextProcessing-LICENSE.md)
- [VBx](Sources/MumlaUI/Resources/vbx-LICENSE.md)
- [Japanese G2P](Sources/MumlaUI/Resources/JapaneseG2P-LICENSE.md)
- [Kokoro G2P](Sources/MumlaUI/Resources/KokoroAneSpanishFrenchG2P-LICENSE.md)

Keep these notices even when a transitive component is not part of Mumla's
currently exposed feature set. New dependencies or model artifacts require a
license review and corresponding attribution before merging.
