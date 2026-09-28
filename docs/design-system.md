# Mumla Recorder Design

The September 28 direction supersedes Liquid Glass. Mumla is a quiet digital
recorder: graphite housing, a recessed sage LCD, mechanical transport keys, and
small functional labels. The reference points are the supplied recorder images,
Teenage Engineering's compact instruments, and Dieter Rams' functional clarity.

## Shared Components

`Sources/MumlaUI` owns the materials, colors, LCD, input meter, buttons, and iOS
haptic cues. Both native apps use these components. The recording display shows
the actual PCM format, elapsed recording time, and microphone level. No simulated
waveform or decorative playback controls are shown.

- Graphite background and molded, beveled key faces.
- Sage display with dark text and a restrained scanline texture.
- Red is reserved for recording and the primary transport key.
- Raised keys move down two points when pressed. Reduce Motion removes travel.
- Opaque surfaces do not depend on transparency or a wallpaper for contrast.
- Disabled transport controls are dimmed and remain disabled until prerequisites
  are ready. The language-model download is a separate action.
- Swedish and English interface text follow the device language.

The iOS recorder keeps the latest transcript inline: a six-line preview with
physical copy and share keys. The Latest transport key scrolls to it, and a
finished dictation does not open a detail sheet. Copy and Share use the complete
transcript, even when the preview is truncated. Full details remain in History.

The bottom tabs are interlocking stereo keys. One key stays latched into its
socket; pressing another raises the old key and lowers the new face. Dragging
away cancels the switch. Each key has a fixed 64-point hit area, a visible lower
wall, beveled face, and a restrained selected indicator. The return spring and
slight face tilt are disabled with Reduce Motion; the latched state stays clear.
Page content switches immediately; only the physical keys animate.

Selecting a whole word in the iOS preview or History transcript exposes the
native `Rätta ord` / `Correct word` action. The correction sheet uses the same
recessed fields and raised save key. Saving updates only the selected occurrence
and adds a deterministic wordlist replacement for future dictations. Cancel does
not mutate either store. A changed or deleted transcript invalidates the old
selection instead of overwriting newer text. Copy and Share reflect corrections.

## Haptics

| Action | iPhone cue |
| --- | --- |
| Mechanical key down | Light rigid impact |
| Stereo tab selection | Prepared rigid latch impact |
| Start recording | Heavy impact, before microphone activation |
| Stop recording | Medium impact, after microphone deactivation |
| Cancel recording | Light rigid impact, after microphone deactivation |
| Transcript saved, text copied, word saved | Success notification |
| Error | Error notification |

Haptics can be disabled in Settings. The preference persists across relaunches.
Mumla does not play synthesized click sounds into a recording. The system
feedback APIs gracefully do nothing on devices without a Taptic Engine.

## Validation

UI tests exercise navigation, dictionary create/delete and persistence, the
haptic preference across relaunches, inline transcript actions, the complete
share-sheet payload, stereo-key selection and cancelled presses, selected-word
corrections and persistence, and English at accessibility text sizes.
Test storage is isolated from normal app history and dictionaries in Debug.
Release builds exclude the UI-test data reset and Mac snapshot entry point.

Screenshots are exported from XCTest results in `.build/DesignEvidence`.
The Mac Debug app supports `--design-snapshot /absolute/path.png`; this uses
an isolated store and renders the actual NSHostingView without requesting
microphone or Accessibility access.

Simulator validation does not establish physical haptic feel or device ASR
performance. These remain a hardware acceptance check.

## Icon

The generated recorder icon uses the same graphite, sage, and red materials.
Originals and the generation prompt are retained in `Design/AppIcon`. iOS has
an opaque square source; macOS has a rounded source with transparent margins.
