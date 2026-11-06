# Mac text providers and structured formatting

## Report

Build 43 is published and its feed/download signatures verified. The owner sees
"No formatting changes needed" with a prompt requesting ASD-STE100 and bullet or
numbered lists. That status means the model returned the input unchanged, not
that the app established no changes were necessary. Current system instructions
forbid Markdown, and the preservation validator rejects added list markers.
Controlled-language wording changes are also outside word-preserving formatting.

## Scope

- Offer Qwen3.5 4B and Apple's on-device Foundation Models on Mac, retaining Qwen
  as the existing default. Use the chosen provider for dictation and manual text
  previews. No cloud fallback or silent provider switching.
- Show Apple availability and language support using the runtime's own checks.
  Recheck after returning from System Settings; do not promise Swedish support
  on every system/model version.
- Support prose, paragraphs, bullets and numbered lists without changing words,
  their order, names, numeric data, links or non-formatting symbols.
- Honor compatible style preferences in model instructions. Transcript/context
  remain untrusted data. Replace the misleading unchanged-status wording.
- Keep summary preferences separate from dictation formatting. Rewriting words
  is explicitly out of scope: the owner chose "Keep original words; allow lists
  only." Do not weaken automatic dictation's word-preservation guard.
- Add an opt-in, pinned-model synthetic evaluation. An unchanged response is
  not a passing structure-preference test when a list was requested.

## Verification

Test provider persistence and legacy settings, selected-provider routing,
unavailable Apple model handling, safe lists, protected numeric/symbol content,
unchanged-output feedback, history originals, cancellation and paste behavior.
Run a real synthetic Qwen trial when weights are available; keep downloaded
weights out of Git. Render compact settings in both appearances. These changes
are separate from build 43. They are now published in signed/notarized Mac
build 44 with its verified update feed; see the [release record](mac-direct-release.md).

## Model evaluation, 2026-11-06

The pinned Qwen revision produced accepted, visibly changed lists for all four
synthetic structure cases: Swedish bullets, English numbering, the reported
STE-plus-lists preference and a Swedish numbered list containing `3,5 SEK`,
`14:30` and `-2`. Every word, its order and numeric content survived. This is
layout support, not an ASD-STE100 compliance claim or permission to rewrite.
The eight existing Swedish/English formatting cases and the separate uncertainty
summary case also passed with the actual model, not mocked generation.

Across two runs, warm synthetic formatting took about 1.4-3.0 seconds in the
Debug runner on this development machine. First requests took 6.6-15.3 seconds
including initial verification/loading. Do not
market these as M1 latency or microphone measurements. Qwen's measured peak was
about 4.13 GB and retained weights about 2.80 GB. Apple Intelligence is disabled
on this machine: availability/fallback behavior is checked, but Apple output
quality has not been measured here.

For repeatable local trials, download verified pinned weights with the existing
opt-in installer test, then set `MUMLA_TEST_QWEN_DIRECTORY` to that private local
directory and run `swift test --filter QwenTextModelTests/testActualQwen`. SwiftPM
command-line tests also need MLX's `default.metallib`: an Xcode-built copy from
the exact resolved dependency can be placed beside the test executable as
`mlx.metallib`. A missing GPU resource is a failed test setup, not passing
quality evidence. Do not commit model weights or machine-specific paths.

## Regression verification

- Shared/Mac suite: 280 tests, zero failures, seven opt-in checks skipped. The
  two real Qwen quality checks were run separately and passed, including all
  four list fixtures and the eight prose fixtures plus a summary.
- Direct Mac and iOS Simulator Debug apps compile. Those are compile checks;
  signed release evidence is recorded separately. No iOS provider selector or automatic formatting was
  introduced; the shared manual formatter gains the same safe list policy.
- Compact Mac Settings was rendered and inspected in light and dark, including
  the selected Apple model's actual disabled-state message. Provider persistence,
  failed settings saves, switching during generation, unavailable Apple without
  Qwen fallback, original retention and successful-paste dismissal are covered.
- Adversarial checks reject rewritten/removed words, numbers hidden as list
  markers, changed signs/amounts/times/links, moved operators, code fences,
  injected context and incompatible style preferences. Marker removal affects
  only added output prefixes; original numeric content is never discarded.

Apple checks: https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
STE scope: https://www.asd-ste100.org/about.html
