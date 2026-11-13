# Mac Paste Confirmation

## Report And Scope

A successful paste into the Claude desktop app for Mac can leave the
"Transcript ready" panel open. The reported target is not Claude in a browser
or Claude Code in a terminal.
Mumla dismisses the panel only after reading back the expected text from the
captured, still-focused editable field. Dispatching Cmd+V alone is not proof.

This change addresses two reproducible false-negative cases:

- Rich-text Accessibility values can contain a final paragraph terminator,
  nonbreaking spaces, or Unicode line/paragraph separators instead of the
  equivalent plain-text presentation.
- An empty editor can expose a zero character count while rejecting a
  zero-length string-for-range query. That is a known empty baseline, not an
  unreadable nonempty field.

The original report's exact Accessibility values have not been verified.
Synthetic regressions demonstrate the failure modes; they do not establish
that these are the only causes in the reported environment.

## Behavior And Safeguards

- Normalize presentation equivalents only for comparison, not the pasted or
  saved transcript. Accept at most one extra final paragraph terminator, while
  retaining the existing newline-only empty-editor handling.
- Apply selected ranges to the original UTF-16 value before normalization.
  A replacement must match the selected range. Without a reliable collapsed
  cursor position, still require exactly one new insertion into the baseline.
- Confirmed immediate or delayed pastes hide the panel. Delayed confirmation
  only observes the field; it never posts another paste or changes the clipboard.
- Partial, duplicate, unrelated, unchanged, unreadable and invalid-range values
  remain unconfirmed. Genuine failures keep the configured copy fallback.
- Secure-field, focus, permission, cancellation and newer-clipboard protections
  are unchanged. No private transcript or target-field content is logged.

## Verification

- The new paragraph-terminator and presentation regressions fail against the
  previous comparison logic, including the coordinator's immediate and delayed
  panel-dismissal paths.
- `swift test`: 373 tests, 9 existing optional model/hardware skips, no failures.
- The unsigned direct Mac Debug app builds successfully. This is a compile
  check, not a signed release or a live cross-app Accessibility test.
- The installed Claude desktop app was inspected, but is at its sign-in screen.
  A real composer/paste test is blocked until the user signs in. No credentials
  were accessed and no test message was entered or sent.
- No app was installed over a user's copy, no permissions changed and no
  private conversations or recordings were read during source verification.

Before release, verify the affected Claude variant using a nonsensitive draft:
paste into an empty field, append to existing text, replace selected text, and
paste multiple paragraphs. Confirm that the overlay disappears, the text occurs
once and the prior clipboard is restored. Also check a blocked paste, changed
focus, secure input and a newer user copy: those must retain their safeguards.

## Release Status

Mac `1.0.1 (52)` was published as a signed/notarized direct beta after the
local checks, exact-source CI and anonymous public archive/feed verification.
The user explicitly deferred the Claude desktop test; it is still outstanding.
See [the release receipt](mac-direct-release.md) for artifact and acceptance
boundaries. No iOS/TestFlight build or automatic paste retry was added.
