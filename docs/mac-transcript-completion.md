# Mac transcript completion

- A confirmed paste dismisses the floating recorder immediately.
- An unconfirmed but readable editor gets up to five additional seconds of
  observation after clipboard restoration. An exact insertion acknowledgement
  dismisses the fallback. This observation never repeats the paste or changes
  the clipboard, and stops on focus change, secure input or cancellation.
- A real failure or unreadable target keeps the manual-copy fallback. Do not
  treat a dispatched keyboard event as proof of successful insertion.
- The menu has Paste Last Transcript and the ten newest Recent Transcripts.
- Menu actions retain the original application's focused editable field and
  wait for menu tracking to end. They cannot paste into a newly focused field.
- History remains saved before insertion. Clipboard preservation, permissions,
  secure-field safeguards and iOS behavior are unchanged.

Regression tests cover delayed acknowledgement, clipboard restoration, no
duplicate paste, focus/security changes, menu history freshness and menu replay.
Physical acceptance in the reported editor remains a separate check.
