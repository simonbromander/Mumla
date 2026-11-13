# Meeting library and transcript access

## Goal

Make a complete saved meeting easy to find, open and copy. Meetings opens on a
library, not recording setup. Keep Classic and Native styles and all local data.

## Reference review

Reviewed Granola's public help and its home-screen screenshot on 2026-11-13:

- [Granola 101](https://docs.granola.ai/help-center/getting-started/granola-101):
  home separates upcoming events from a dated list of existing meeting notes.
- [Transcription](https://docs.granola.ai/help-center/taking-notes/transcription):
  a meeting's transcript has search and a whole-transcript copy action.
- [Export](https://docs.granola.ai/help-center/sharing/exporting-notes): export
  includes transcript data. Mumla keeps its existing immediate local exports.

These are observable interaction patterns, not access to Granola's source code.
No Granola assets or proprietary implementation are copied into Mumla.

## Implementation

1. Make saved meetings the default surface. Show date groups, title, time,
   duration, processing/interruption state and a short transcript preview.
2. Search locally across titles, transcript text, source and saved speaker names.
   Results are complete meetings, never isolated chunks presented as meetings.
3. Open a meeting with one click. At wide sizes keep the searchable library next
   to the transcript; at compact sizes show a clear All meetings back action.
   Keep the library query when returning, but reset passage/speaker filters when
   switching documents. New meeting opens setup explicitly.
4. Keep the document title and full-transcript copy/export actions visible above
   the scrollable transcript. Copy/export always uses the complete meeting,
   regardless of passage filters. Show when a passage filter is active and offer
   a reset. Retain playback, corrections, speaker assignment and pinned live
   recording controls.
5. Add a plain-text export alongside existing Markdown and JSON exports.

## Boundaries

No recording/transcription engine changes, new network calls, model downloads,
calendar permission changes, automatic summaries, folders or account features.
No schema migration. No real recordings or personal transcripts in fixtures.
Upcoming calendar events are not part of this change; existing detection stays.
Opening the library or a saved document must never start/stop a recording.

## Verification

- Unit tests: local search, Unicode/case, multi-term matching, stable newest-first
  ordering, date grouping, no truncation of copied/exported transcript, selected
  record restoration and recording independence.
- Native UI scenarios: library-first entry, search/open/back, empty/no-results,
  copy full transcript while filtered, export availability, new/start/stop,
  existing correction/deletion flows. Preserve keyboard focus and VoiceOver
  labels; no action is conveyed by color alone.
- Render both skins and appearances at compact, regular and wide sizes using
  synthetic data, including long titles and long transcripts.
- Run swift test and build the hosted Mac test targets. Record UI Automation or
  hardware-only limits honestly. Do not publish a release as part of this task.

## Results

Verified locally on 2026-11-13 using synthetic meetings only:

- Swift package suite: 365 tests, nine existing optional model/hardware skips,
  zero failures. Includes five library/search/export tests and a recording
  independence regression test.
- The hosted Mac app and UI test runner build successfully with the regenerated
  Xcode project. Automated Mac click-through execution remains unverified because
  it requires local UI Automation approval; no permissions were changed.
- In the isolated Mac host, verified search across title and speaker, one-click
  open, back preserving the library query, empty search results, passage filtering,
  full-copy feedback, and the three visible export choices.
- Started a silent synthetic recording, browsed the library, returned via Current
  meeting, and stopped normally. Browsing neither stopped nor replaced it.
- Inspected actual windows in Classic light/dark and Native light/dark, including
  compact and wide layouts, a long Swedish title and a long speaker name. The
  compact reader has no squeezed inner sidebar; the wide reader keeps its library
  and selected row visible. No new motion is introduced.
- Full-text export contents are covered by unit tests, including a large final
  passage. The native file picker was not used to write a manual export.

The implementation checks did not validate real-call acoustic quality, change
capture behavior or install a production build. The subsequent Mac 51 release is
recorded in [the distribution runbook](mac-direct-release.md).
