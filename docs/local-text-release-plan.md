# Local text beta release

## Scope

- Release optional foreground formatting and summary previews on iOS and Mac.
- Add local, editable style preferences in Settings with Save, Cancel and Reset.
- Keep formatting's word-preservation checks independent of user preferences.
- Save accepted summaries separately; never replace or auto-paste a summary.
- Clear a saved summary when its source transcript changes. Reject stale previews.
- Keep generation out of keyboard extensions and background dictation.
- Publish iOS through the existing internal TestFlight audience and the full
  Mac app through the notarized GitHub beta and signed in-app updater.

## Verification

Run shared tests, hosted iOS tests and focused UI checks. Build both platforms,
verify signatures, profiles and entitlements, then upload and check processing
separately. Verify the Mac ZIP, notarization and signed public update feed.

Apple Intelligence must be supported, enabled and ready. Real Swedish summary
quality is not yet approved: summaries remain an explicit beta preview with
human acceptance, not automatic meeting intelligence. Long inputs are rejected,
not silently truncated. No cloud fallback, transcript logging or extra model.
