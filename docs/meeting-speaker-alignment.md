# Live meeting speaker alignment

## Problem

The system-audio source key is not a person. The old display calls that fallback
"Them", while identified model slots are "Remote 1", "Remote 2", etc. In a group
call, alternating between a slot and this fallback can incorrectly look like a
change of person.

The current adapter feeds only the current audio chunk to a delayed streaming
speaker model, even though the next chunk is already available for ASR context.
It then permanently assigns the current chunk's trailing words before the
corresponding speaker predictions exist. Retrying a fed chunk also calculates
its model-time offset from the new stream end instead of its original position.

## Scope

- Feed available, contiguous lookahead before assigning current words, with one
  stable per-chunk model-time offset and no duplicate ingestion on retry.
- Drain the final stream, and handle pause/gap tails without ending a resumable
  speaker session. Keep model history and audio context bounded.
- Assign from word-duration overlap with model activity, not one midpoint that
  can land in a short silence. Genuine overlap or uncertainty stays unassigned.
- Display unknown remote speech as "Unassigned remote", not another person.
- Offer a tactile, per-passage speaker selector using existing identities from
  the same audio source. Do not merge all remote speakers or relabel every
  unknown passage automatically. Preserve transcript text and other passages.

No model or dependency-version change, voice enrollment, external service, automatic edits
to existing meetings, recording restart or capture-scope change is included.

## Verification

Use a delayed streaming fixture to reproduce chunk-tail fallback and retry
offset errors without downloading a model or accessing a microphone. Cover
multiple remote speakers, overlap, brief activity gaps, final partial chunks,
pause/resume, track separation, source failure and old meeting JSON. Test scoped
speaker edits, stale previews and invalid cross-track assignments. Run Swift
tests, compile the native app and UI target, and inspect the selector in light,
dark and compact layouts. Real group-call recognition quality remains a separate
acceptance check; synthetic tests do not prove acoustic speaker accuracy.

### Local results (2026-11-12)

- The delayed-stream reproduction failed with the old feed/clock behavior, then
  passed with lookahead and stable offsets. Twelve focused alignment tests now
  cover chunk tails, distinct/returning speakers, ASR retries, final partial
  chunks, pause/resume, repeated pause retries, track isolation, speaker-model
  failure, brief activity gaps and overlapping voices.
- Tests exercise the pinned FluidAudio timeline without a model: absolute frame
  queries remain correct after trimming old history, while low-confidence,
  overlapping and unavailable frames remain unassigned. Speaker probability
  history is bounded, and duplicate segment history is not retained.
- Manual correction tests preserve all other passages, text, word timing and
  aliases; reject unknown/cross-source targets and stale previews; and retain
  the previous identity even after its final passage is reassigned. Existing
  source-key JSON decodes without silently merging or reassigning passages.
- Full Swift package suite: 355 tests, nine existing optional model/hardware
  skips, zero failures. Native direct Mac build and native UI-test build passed.
- In the isolated, silent Mac preview, verified assignment, restoration and
  dismissal without changes. Inspected the selector at 820x560 in light and
  dark appearances, including a long wrapped speaker name. No production
  meeting was opened, edited or recorded. The automated Mac UI runner was
  compiled but not executed; native UI Automation approval remains unverified.

This fix is local, not in a published release. Existing recordings are not
automatically repaired. Real group-call speaker accuracy still needs acceptance
on a consented call; these tests establish alignment and editing behavior only.
