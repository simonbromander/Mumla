# Mumla for Mac 1.0.1 (52) - Paste Confirmation Beta

## Fixed

- Confirm successful pastes when a rich-text editor reports an extra final
  paragraph terminator, nonbreaking spaces or Unicode line/paragraph separators.
  These differences previously could leave the "Transcript ready" panel open
  even when the full transcript had been pasted.
- Recognize a known-empty editable field when its Accessibility API reports
  zero characters but rejects an empty text-range query.
- Immediate and delayed confirmation both dismiss the recorder. Delayed
  confirmation only observes the target; Mumla never sends a second paste.

The text pasted and saved to history is unchanged. A failed or unreadable paste
keeps the configured copy fallback. Secure input, changed focus, permissions,
selection replacement, clipboard restoration and newer user copies remain
protected. Existing meetings, models, settings and data are unchanged.

## Install And Test

Choose Check for Updates in the direct Mac app, or quit Mumla and replace it
with the downloaded notarized app. Avoid running multiple Mumla copies at once.

In the Claude desktop app for Mac, try a nonsensitive draft in an empty field,
append to existing text, replace selected text and paste several paragraphs.
The full text should appear once, the recorder should disappear and the prior
clipboard should be restored. Do not send the draft unless you intend to.
Also check a blocked paste and changing focus: the fallback should still work.

The Swift suite executes 373 tests with nine existing optional model/hardware
skips and no failures. Synthetic regressions cover immediate and delayed
recorder dismissal and reject missing, duplicate or unrelated text. Native Mac
build verification is separate from real cross-app permission and paste tests.

The reported Claude desktop environment was not reproduced end to end: the
local app was signed out and the live test was deferred. This release fixes
the reproduced confirmation cases, not a guarantee for every Claude version.
Privacy traffic auditing and updater installation/relaunch remain target-Mac
acceptance checks. This is not a new iOS or sandboxed Mac TestFlight build.
