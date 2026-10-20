# Mumla for Mac 1.0.1 (41) - Local Qwen and Compact Controls Beta

## New And Fixed

- Optional formatting and summary previews now use Qwen3.5 4B locally through
  MLX on Apple silicon, without requiring Apple Intelligence or macOS 26.
  Download the verified 3.1 GB model in Settings before use. It can retain
  about 3 GB of memory after first use. Intel Macs cannot run this text model.
- Add context to a text preview and regenerate it before accepting. Changing
  context invalidates the old suggestion. Formatting still requires approval;
  summaries remain separate from the original transcript. Nothing generates
  automatically in the hotkey path and there is no cloud fallback.
- More compact, translucent recorder and transcript controls, with matching
  light/dark styling and accessible actions.
- Recording opens an available pinned microphone directly, without first
  opening the system-default input. This avoids unnecessarily switching
  Bluetooth headphone playback into its lower-quality microphone mode when
  recording from another microphone. An unavailable pinned device still
  falls back to the system default.
  Thanks to @ehsanYazdani for
  [PR #6](https://github.com/simonbromander/Mumla/pull/6).

Includes the existing microphone selection, Secure Input guidance, Chromium
paste confirmation, clipboard restoration and optional silent-copy fallback.
The Watch voice-notes companion ships in the separate iOS TestFlight beta,
not in this Mac download.

## Install

Choose Check for Updates in the direct app, or download the notarized ZIP,
quit Mumla and replace the copy in Applications. Keep Microphone, Input
Monitoring and Accessibility enabled. Do not run direct and TestFlight copies
simultaneously. Existing dictation models and local data are preserved.

This is a direct Mac beta for macOS 14+, on Apple silicon and Intel. Optional
Qwen text generation is Apple-silicon-only. Speech recognition remains Swedish
only; meetings and iCloud sync are not implemented. Open-source, model and
runtime licenses are available in About.

## Testing

Try the pinned-microphone workflow with Bluetooth headphones, including device
disconnect/reconnect. Check auto-paste and clipboard restoration in your real
editor. Test model download/cancellation, formatting and summary previews,
context changes, acceptance and original restoration. Review generated text
carefully: factual and Swedish-language quality remain experimental.

Automated and distribution checks are not physical microphone-routing,
hotkey/paste, live updater or general model-quality acceptance.
