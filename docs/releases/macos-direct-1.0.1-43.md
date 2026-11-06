# Mumla for Mac 1.0.1 (43) - Minimal Dictation And Local Formatting Beta

## New And Fixed

- Settings now has a Format before pasting switch. When enabled, the installed
  local Qwen text model formats new dictations before auto-paste, using your
  saved Text preferences. Previously, preferences affected only manual previews
  in History. The switch is off by default.
- Formatting preserves words and their order while adjusting punctuation,
  capitalization and paragraphs. The original is saved in History before the
  model runs and can be restored. If the model is unavailable, fails, or changes
  words, Mumla uses the original and shows the outcome in Settings.
- Choose Recorder or Minimal under Settings > Dictation overlay. Minimal is a
  small indicator with REC, a live waveform, elapsed time and stop/cancel
  controls. Neither overlay takes focus from the app you are dictating into.
- Formatting is cancellable. Cancelling keeps the saved original and does not
  paste a late result. Successful auto-paste still dismisses the overlay;
  existing copy-dialog and silent clipboard fallback settings are respected.
- Recording startup no longer repeats the focused-field check or scans the
  microphone list for every pinned-device recording. The overlay appears with a
  shorter animation. The 250 ms hold-to-talk shortcut guard remains unchanged;
  a hardware latency improvement has not yet been measured.
- Qwen verifies downloaded files before loading, then reuses the loaded model
  rather than checking all model files again for every request.

Qwen formatting requires Apple silicon and the separate approximately 3.1 GB
model download. It adds processing time, especially on first use. Text
preferences control formatting, not rewriting or adding words. Summaries remain
separate, explicit previews and are never automatically pasted.

## Install

Choose Check for Updates in the direct Mac app, or download the notarized ZIP,
quit Mumla and replace the copy in Applications. Existing history, dictionary,
settings and downloaded models are preserved. Keep Microphone, Input Monitoring
and Accessibility enabled. Do not run direct and TestFlight copies together.

This is a direct Mac beta for macOS 14+, on Apple silicon and Intel. Intel
dictation remains supported without Qwen generation. Speech recognition remains
Swedish-only; meetings and iCloud sync are not implemented. No cloud fallback.
Model and library licenses are available in About.

## Testing

The shared/Mac regression suite completed 269 tests with zero failures and five
optional live checks skipped. Both overlay designs were rendered and inspected
in light and dark appearances. Synthetic integration tests cover saved prompts,
original retention, cancellation, changed focus, clipboard restoration, failed
history writes and dismissal after confirmed insertion.

Real microphone-start timing, Swedish model quality, live update installation
and cross-app dictation still require target-Mac acceptance. Signing and download
verification do not establish those hardware results. iOS/TestFlight is unchanged
by this Mac release.
