# Third-Party Notices

Mumla's [MIT license](LICENSE) covers its original code and assets, not separately
licensed dependencies, copied attribution documents, or downloaded model weights.
The following notices remain in force. Preserve their full text when distributing
relevant components; a summary here is not a replacement for upstream terms.

## Speech Models

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
