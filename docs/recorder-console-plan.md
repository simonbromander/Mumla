# Fixed Recorder Console

## Scope

- Keep the dictation home surface fixed on iPhone, iPad, and Mac, including
  compact windows and iPad landscape. Preserve the existing iPhone portrait-only
  policy. History, Dictionary, and reading sheets may scroll.
- Limit the latest transcript strip to three words and one row. Copy and Share
  always use the full text. Keep correction available in the full transcript.
- Give the mutually exclusive mode keys an orange top insert, visible mechanical
  travel, and firm iOS haptics. Respect Reduce Motion and the haptics preference.
- Use the same system monospaced family throughout app-owned UI and transcript
  text, retaining Dynamic Type in reading and settings surfaces.
- Add shared About content with accurate model/conversion credits, source and
  license links, and bundled dependency notices. Do not imply English model
  routing is already implemented.

## Verification

Run core/Mac tests and iPhone/iPad UI tests, with compact-screen, landscape,
large-text, full-text copy/share, correction, and mode-latching checks. Inspect
native screenshots. Build both targets. Physical haptic feel remains a device
acceptance check. Build 26 is already in TestFlight; these changes are a new
source revision and must not be described as included in that uploaded binary.
The follow-up release is build 27 on both platforms.

## Layout Decisions

- Hardware legends, the one-line preview, and 44-point icon keys use stable type
  sizes so accessibility text settings cannot push controls out of the console.
  Full transcripts and reading surfaces retain Dynamic Type and VoiceOver.
- Sheet headers and correction-save controls cap at the largest standard text
  size, leaving room for the editable word when the software keyboard is open.
- History and the Latest transport key still open the full, selectable transcript
  with word correction. The inline preview itself does not navigate.
- The orange insert and depressed key position both identify the selected mode;
  accessibility exposes exactly one selected tab. Haptics respect the saved
  preference and animations respect Reduce Motion.

## Verified 2026-09-29

- 53 core/Mac tests passed, including three-word previews, correction persistence,
  clipboard preservation, trigger handling, and transcript fallback.
- Nine UI scenarios passed on each of iPhone SE (3rd generation), iPhone 17e,
  and iPad mini: 27 successful runs. Includes no-scroll checks, full-text sharing,
  correction, large text, mutually exclusive mode selection, and offline notices.
- Final device screenshots inspected for compact/large-text controls and iPad
  landscape; Mac snapshots inspected at the minimum 820 x 560 window and About.
- iOS and macOS Release preflights passed. Existing signing identity and App
  Store Connect record verified. Release availability is recorded separately in
  `docs/testflight.md` after upload.
- Local evidence: `.build/DesignEvidence/Release27-Acceptance.xcresult`,
  `.build/DesignEvidence/Release27-Images/`, and `.build/release27-*.log`.
- Physical haptic feel, real microphone transcription, and sandboxed Mac
  cross-app paste remain device acceptance checks, not simulator claims.
