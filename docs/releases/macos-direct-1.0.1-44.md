# Mumla for Mac 1.0.1 (44) - Tiny Dictation And Text Models Beta

## New And Fixed

- Minimal dictation is now a translucent 104 x 30 point capsule with just a
  pulsing REC indicator and a minutes/seconds timer. No waveform, stop or discard
  buttons. Clicks pass through to the app behind it. Release the held trigger
  key to finish, tap it to stop hands-free recording, or press Escape to cancel.
  The full Recorder design is unchanged. Errors and the manual-copy fallback
  retain readable sizes; successful auto-paste still hides the overlay.
- Choose Qwen3.5 4B or Apple Intelligence under Settings > Text model. The chosen
  on-device model handles both optional Format before pasting and manual text
  previews. Mumla never silently switches providers or uses a cloud fallback.
- Formatting preferences can now request bullet or numbered lists. Mumla keeps
  every original word in order, including names, numeric values and links. It
  may change punctuation, sentence capitalization and layout, but does not
  rewrite wording to meet a writing standard. The previous conflicting
  instruction that blocked lists has been removed.
- Settings now says when the model returned unchanged text, rather than
  claiming no changes were needed. Unavailable Apple models explain the reason,
  including disabled Intelligence or unsupported language. Invalid output and
  generation failures still use the saved original.

Format before pasting remains off by default. When enabled, it adds processing
time, especially on first use. Original dictations are saved to History before
formatting and can be restored. Summaries remain separate, explicit previews;
summary preferences do not change automatic dictation or get pasted as a summary.

Qwen requires Apple silicon and the separate approximately 3.1 GB download.
Apple Intelligence requires macOS 26+, eligible hardware, Intelligence enabled
and a ready model supporting the transcript language. Availability is checked
on the device. Intel dictation remains supported without Qwen generation.
Reduce Transparency, Increase Contrast and Reduce Motion remain respected.

## Install

Choose Check for Updates in the direct Mac app, or download the notarized ZIP,
quit Mumla and replace the copy in Applications. Existing history, dictionary,
settings and downloaded models are preserved. Keep Microphone, Input Monitoring
and Accessibility enabled. Do not run direct and TestFlight copies together.

This is a direct Mac beta for macOS 14+, on Apple silicon and Intel. Speech
recognition remains Swedish-only; meetings and iCloud sync are not implemented.
No cloud fallback. Model and library licenses are available in About.

## Testing

The shared/Mac suite completed 283 tests with zero failures and seven optional
checks skipped. Real pinned-Qwen evaluations ran separately and passed: four
list-preference examples, eight Swedish/English prose cases and a separate
summary. Lists preserved amounts, times and negative values. These synthetic
cases are not a general model-quality guarantee. Apple model output quality
remains unmeasured here because Apple Intelligence was disabled on the test Mac.

Compact overlays were rendered and inspected in light and dark appearances.
Integration tests cover provider routing, cancellation, original retention,
clipboard restoration, changed focus, successful-paste dismissal, click-through
recording and interactive copy fallback. Real microphone timing, live updater
installation and cross-app dictation remain target-Mac acceptance checks.
iOS and sandboxed Mac TestFlight are unchanged by this release.
