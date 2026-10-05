# Light Appearance

Add system/light/dark choices on iOS and macOS using the shared UI package.
Light mode uses neutral white polymer, graphite labels and orange highlights;
the original dark mode remains available. Keep the tactile keys, fixed recorder
layout, haptics and nonactivating Mac pill. Appearance is stored per device.

## Release Slice: 2026-10-05

- Put the System / Light / Dark selector first in iPhone Settings. Use the same
  physical mode keys on Mac, with recognizable icons and an orange latched marker.
- Add Appearance to the Mac menu bar so it works without opening the main window.
- Use one persistent preference for Settings, sheets, the Mac pill and keyboard
  session packets. System clears the native Mac override rather than freezing
  the current system appearance. Do not change dictation or paste behavior.
- Verify persistence, native override reset, both themes, compact layout and
  existing UI regressions. Commit before creating signed release artifacts.
- Publish a notarized direct Mac beta with its signed update feed. iOS TestFlight
  still requires Apple's keyboard App Group association; an archive or unsigned
  simulator build is not an uploaded release. Retain the keyboard target.

Check label contrast, both recording and transcript pills, Settings/About and
the existing dark views. Build iOS and macOS and run regression tests. This
change does not modify transcription, permissions, hotkey or paste behavior.

## Earlier Verification (2026-10-05)

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

## Selector Verification (2026-10-05)

- All 132 shared core/Mac tests passed, including missing/unknown preference
  fallback, all three choices persisting and System clearing the native override.
- All 17 iPhone UI regression tests passed. Screenshot review then caught
  crowded large-text labels and icons too close to the physical key marker.
- The final selector stacks keys at accessibility sizes and leaves marker
  clearance. Both appearance UI tests passed again; final small-iPhone captures
  show complete labels, separate keys, light/dark sheets and a fixed recorder.
- The iPhone selector is first in Settings. Mac Settings and the menu bar use
  the same saved preference; no additional idle polling was added.
- All 31 release-helper tests passed (74 assertions). Real-device haptics and
  target-Mac hotkey, paste and live update acceptance remain separate checks.
- Evidence: `.build/appearance-release-swift-tests.log`,
  `.build/appearance-ui-20261005.xcresult`,
  `.build/appearance-ui-final-20261005.xcresult`,
  `.build/AppearanceScreenshotsFinal/` and Mac Settings captures.
