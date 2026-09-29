# Tactile Polish and Beta Release

## Scope

Finish the recorder design across the existing iOS and macOS surfaces before
publishing the next internal TestFlight builds. Preserve recording behavior,
Apple identities, local data, and the existing beta audience.

## Design Audit

- iOS Settings and Add Word still use stock grouped forms.
- Transcript and correction sheets retain glass navigation-bar controls.
- macOS navigation, language selection, switches, and secondary actions look
  like default desktop controls beside the recorder.
- Download progress and dictionary delete actions lack the same physical finish.

## Implementation

1. Add shared mechanical switches, recessed readouts, sheet headers, and a
   segmented download gauge. Retain native accessibility semantics.
2. Replace app-owned sheet chrome and forms with engraved labels, recessed
   fields, and raised action keys. Keep text selection and system-owned UI native.
3. Apply the same finish to Mac sidebar keys, settings, onboarding, and actions.
   Add a persisted Ctrl / Right Option / Fn trigger selector. Release pastes into
   the original editable target; unconfirmed insertion keeps a transcript and
   Copy key in the nonactivating mini recorder. Match its LCD, waveform, REC
   pulse, and bottom entrance to the main recorder, respecting Reduce Motion.
4. Run core tests and iPhone/iPad UI regressions, including large text, correction
   persistence, toggle persistence, and cancellation. Inspect Mac snapshots.
5. Review the diff, commit and push, run both release preflights, archive and
   verify signatures/entitlements, upload, and confirm processing and internal
   TestFlight availability. Do not submit to external review or add testers.

## Hardware Acceptance

Simulator and snapshot checks do not prove physical haptic feel, microphone
quality, or successful installation from TestFlight. Report these separately.
Mac hotkeys, Accessibility permissions, and paste behavior in third-party editors
also require a physical-Mac acceptance pass.

## Verification: 2026-09-29

- 50 core/Mac tests passed, including hold threshold, release, double-tap,
  shortcut cancellation, persisted trigger selection, clipboard restoration,
  exact insertion verification, persistent transcript fallback, and full copy.
- Seven UI scenarios passed on both iPhone 17e and iPad mini simulators
  (14 runs), including correction persistence, inline sharing, large text,
  mechanical toggle persistence, and stereo tab latching.
- Inspected iPhone settings/add-word/transcript/correction screenshots, Mac
  compact settings/recorder, and mini-recorder recording/transcript snapshots.
- Evidence is local under `.build/DesignEvidence/Final-PhonePad.xcresult` and
  `.build/DesignEvidence/final-mac-*.png`.
- The mini panel cannot become key or main, remains open for unconfirmed
  insertion, and honors Reduce Motion for entry, dismissal, and REC pulsing.
