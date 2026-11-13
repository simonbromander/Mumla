# Mumla for Mac 1.0.1 (50) - Classic and Native Styles Beta

## Changed

- Choose Classic or Native in Settings, independently of System, Light or Dark
  appearance. Existing installations keep Classic by default.
- Native uses a Mac sidebar, system typography and platform controls. Supported
  systems use glass materials, with material fallbacks on older macOS versions.
- The recording overlay, meeting views, settings and shared dialogs follow the
  selected style. Switching back restores Classic's recorder and title bar.
- Style changes do not restart recording services, clear history, change audio
  permissions or alter transcription and text-formatting preferences.
- Pressing the DJI mic button while an app update is being installed is now a
  no-op, including when Secure Input is enabled. Secure Input remains protected.

Existing live meetings, speaker correction, dictation and paste behavior remain.
This release adds no cloud provider or new data-sharing feature. Models continue
to run locally. The style preference stays on this device.

## Install And Test

Choose Check for Updates in the direct Mac app, or quit Mumla and replace it
with the downloaded notarized app. History, dictionary, settings and downloaded
models are preserved. Avoid running multiple copies of Mumla simultaneously.

In Settings, switch between Classic and Native, then try System, Light and Dark.
Check the recorder, compact overlay, meetings, history and settings. Confirm that
the style persists after relaunch and that recordings and model preferences stay
unchanged. Meetings still require Apple silicon and macOS 14.2 or later, and
participants' consent.

The local Swift suite passes 359 tests with nine optional model/hardware skips.
Release-helper tests pass (35 tests, 84 assertions). Mac app and UI-test targets
compile; isolated test-app inspection covered both styles and compact layouts.
Automated Mac UI execution is not verified because UI Automation access was not
granted. Physical audio capture, paste permissions/routing, older-OS materials,
traffic auditing and live updater replacement still need target-Mac acceptance.
This remains an experimental prerelease, not a quality guarantee for real calls.
