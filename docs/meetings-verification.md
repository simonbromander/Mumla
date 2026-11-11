# Live Meetings Verification

Date: 2026-11-11. Development implementation, not a published release.

## Implemented

- Direct Mac entry from the menu bar and full recorder; a dedicated Meetings
  workspace in the existing tactile light/dark design.
- Selected-application Core Audio taps and a separately captured microphone,
  input-only AUHAL capture, real source meters, pause/resume and Stop and Save.
- Three-second PCM chunks committed before inference, local word-timed Swedish
  transcription during recording, tail completion, model-independent recording,
  record-now/transcribe-later, cancellation, retry and interrupted-job recovery.
- Optional LS-EEND speaker separation, explicit 45 MB model download with pinned
  source revision and three SHA-256 checks, local CoreML compilation, original
  license/attribution, source-label fallback, names and text corrections.
- Transcript search, speaker filtering, audio-clip playback, clean text and
  speaker/timestamp copy, Markdown/JSON export, audio retention and deletion.
- Guarded dictation hotkeys and clipboard behavior, meeting-aware update/quit
  handling, no automatic sharing, and no in-app meeting LLM or summary connection.

## Automated Evidence

- Full Swift package regression suite: 306 tests, 9 opt-in tests skipped, no
  failures. Includes meeting store, lifecycle and UI ownership cases.
- Generated Swedish speech passed through the actual PCM writer, installed
  Pianissimo model and downloaded/compiled LS-EEND model. The fixture covers
  repeated ASR boundaries, word timings, speaker slots and transcript commits.
  It exposed repeated boundary words; two-second left context and conservative
  multi-word overlap matching fixed that fixture. Deliberate repetitions have
  separate deterministic tests.
- Synthetic two-hour, two-track PCM writing/recovery passed: 4,800 independent
  chunks, three seconds or less each, with 7,200 seconds retained per source.
  The accelerated writer test took about 164 seconds. It did not use microphones,
  run a two-hour call, or measure two-hour transcription/diarization quality.
- The actual converter/writer also passed synthetic 44.1/48 kHz stereo inputs,
  retaining duration while committing 16 kHz mono chunks. Overlay tests verify
  that timer ticks do not repeatedly re-present the recording window.
- Native direct Mac Debug build and iOS Simulator regression build succeeded.
  Native setup/transcript windows were captured in light/dark and compact sizes.
  Compact setup clipping was fixed by scrolling configuration independently of
  the pinned Record action. Snapshot text is a synthetic layout fixture.
- Release helper suite: 35 runs, 84 assertions, no failures.

Private/local evidence stays ignored under `.build`: `meeting-tests.log`,
`meeting-real-model-test.log`, `meeting-two-hour-test.log`, `meeting-native-mac.log`,
`meeting-ios-regression.log`, `meeting-release-helper-tests.log`, and `MeetingEvidence/`.

## Remaining Acceptance Gates

- Grant microphone and system-audio recording permissions to the exact signed app
  being tested. Do not bypass macOS permissions or run production/development
  copies together. Meeting recording itself does not need Input Monitoring or
  Accessibility; those permissions still serve the existing dictation workflow.
- Test actual Zoom, Teams, and browser Meet calls with headphones, loudspeakers,
  pinned/disconnected inputs, output changes, multiple audio sample rates, sleep,
  source exit, permission revocation, and disk pressure.
- Measure real capture startup, dropped audio, cross-device clock drift, live
  update latency, idle/model memory, CPU, and impact on call responsiveness.
  First text needs two completed chunks plus model time. A cold CoreML model can
  take materially longer to prepare than a subsequent warm run.
- Evaluate Swedish accuracy and speaker assignment on consented annotated
  meetings, including similar voices, shared microphones, overlap and more than
  four people. A single generated voice is not a diarization benchmark, and the
  original private-dataset Phase 0 gate remains separate.
- Audit outbound traffic during real recording and transcription, separated from
  explicit model downloads and update checks. This code introduces no external
  transcription/LLM request; an independent traffic audit is still required.
- Validate the supported OS/hardware matrix, VoiceOver/Reduce Motion and actual
  permission UX. Intel/sandboxed builds are not enabled for this development beta.
- Before distribution, complete exact-source CI, signing, notarization, Gatekeeper,
  anonymous-download verification and signed updater feed publication. None of
  those release operations has been performed for this change.

## Repeatable Commands

```bash
swift test
ruby -e 'Dir.glob("fastlane/tests/*_test.rb").sort.each { |path| require File.expand_path(path) }'
mkdir -p .build/MeetingEvidence
say -v Alva -r 145 -o .build/MeetingEvidence/synthetic-speech.caf \
  'Det här är ett möte om vår nästa produkt. Vi ska testa inspelningen och kontrollera att alla ord kommer med. Anna skickar rapporten på fredag. Nästa möte börjar klockan nio.'
afconvert -f WAVE -d LEI16@16000 -c 1 \
  .build/MeetingEvidence/synthetic-speech.caf .build/MeetingEvidence/synthetic-speech.wav
MUMLA_MEETING_TEST_AUDIO="$PWD/.build/MeetingEvidence/synthetic-speech.wav" \
  swift test --filter MeetingTests.testRealLocalModelsOnExplicitSyntheticSpeechFixture
MUMLA_MEETING_LONG_TEST=1 \
  swift test --filter MeetingTests.testTwoHourTwoTrackWriterOnExplicitOptIn
```

The speech test requires an existing verified Pianissimo installation and
explicitly downloads the public pinned speaker model into isolated test storage.
It does not upload the fixture or access live microphones. The long test writes
about 461 MB of PCM plus metadata and deletes its isolated temporary store.
These opt-ins are skipped by the normal offline test suite.
