# Local text formatting trial

## Scope

An on-demand action in iOS and macOS transcript details uses Apple's on-device
Foundation Models runtime. It previews punctuation, sentence casing and paragraph
breaks. Nothing is changed until the user accepts. The original is retained for
undo. Dictation, auto-paste and background keyboard sessions are unchanged.

## Boundaries

- No cloud fallback, extra downloaded model, analytics or transcript logging.
- A fresh session for each transcript, no tools or conversation history.
- iOS/macOS 26 availability and locale checks; older or ineligible devices retain
  the existing transcript and explain why formatting is unavailable.
- Foreground only. Leaving the foreground or dismissing cancels the operation.
- Maximum 1,500 characters per trial. Do not silently truncate long transcripts.
- Reject changed word order, added/deleted words, changed numbers or links, and
  unexpected symbols. This does not prove semantic equivalence: punctuation can
  change meaning, so human preview remains required.
- Existing filler removal and dictionary replacements are not run a second time.
- Persist with an expected-text check so an old preview cannot overwrite edits.
- Keep the runtime out of the keyboard and widget dependency graphs.

## Verification

Unit tests cover preservation, failure/cancellation fallbacks, unavailable runtime,
backwards-compatible history, explicit acceptance, undo and stale previews. Build
both apps, then exercise the iOS preview UI without requiring Apple Intelligence.
An opt-in live model test uses synthetic Swedish/English cases and reports cold
and warm elapsed time. It is skipped when Apple Intelligence is unavailable.

Real Swedish output, latency, memory and physical iPhone behavior must be measured
before automatic formatting is considered. This trial does not satisfy Phase 0
dictation or release gates.

## Live evaluation

From the repo root, enable Apple Intelligence on a compatible Mac, let its model
finish preparing, then run:

```sh
MUMLA_TEST_LOCAL_FORMATTER=1 swift test --filter LocalTranscriptFormatterTests/testActualAppleModelOnSyntheticFixtures
```

Only the synthetic fixture outputs and elapsed times are printed. An unavailable
model is a skip, not a passing quality result. Review punctuation and meaning by
hand, and record the OS/model version before comparing subsequent runs.

API references: [local model](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel),
[language support](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models).
