# Light Appearance

Add system/light/dark choices on iOS and macOS using the shared UI package.
Light mode uses neutral white polymer, graphite labels and orange highlights;
the original dark mode remains available. Keep the tactile keys, fixed recorder
layout, haptics and nonactivating Mac pill. Appearance is stored per device.

Check label contrast, both recording and transcript pills, Settings/About and
the existing dark views. Build iOS and macOS and run regression tests. This
change does not modify transcription, permissions, hotkey or paste behavior.

## Verification (2026-10-05)

- Shared Mac package: 115 tests passing, including appearance mapping and
  WCAG 4.5:1 text contrast on primary surfaces in both appearances.
- iOS Release simulator build passed.
- Four iOS UI tests passed: preference persistence, About/licenses, selected-word
  correction, and the fixed portrait/landscape recorder.
- Inspected real light Settings/recorder/history/dictionary captures on iOS.
- Inspected Mac main window, Settings, About, recording pill and transcript pill.
- Light setting is per device; System is the default and Dark remains available.
- This is source verification, not a new signed/TestFlight release or a
  physical-device acceptance test. Existing build 35 does not include this theme.
