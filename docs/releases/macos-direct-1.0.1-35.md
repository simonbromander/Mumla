# Mumla Mac Beta 1.0.1 (35)

- Settings is now directly available from the menu bar and opens the correct tab.
- The dictation key also works through a local AppKit listener while Mumla has
  focus. This does not claim global keyboard access: Input Monitoring is still
  required in other apps, and Secure Input continues to block recording.
- A hold timer that fires slightly early is rescheduled instead of dropping
  the hold. Local/global delivery is deduplicated to avoid false double-taps.
- Settings shows the last trigger stage and lets you copy a small diagnostic
  containing permissions, configured key, microphone, and model availability.
  No typed words, audio, transcripts, or dictionary contents are included.
- Check for Updates installs signed, notarized Mac betas from inside Mumla.
  No background update checks, analytics, or silent installation.
- Updates wait for recording, transcription, pasting, and model installation
  to finish. Existing local data and downloaded models are not migrated.

## Installation

Quit all older Mumla copies, unzip the download, and move Mumla to Applications,
replacing the older copy. This is the one manual install needed to get the
updater. Future direct Mac updates can be installed through Check for Updates.

Requires macOS 14 or later; Apple silicon and Intel are supported. The source
repository remains private. App identity and signing team are unchanged.

## Hotkey Check

1. From Mumla's menu choose Settings, then select Ctrl, Right Option, or Fn.
2. Use Keyboard access to grant Input Monitoring. macOS may require quitting
   and reopening after a permission change. Accessibility is separately needed
   for cross-app paste. Download the Swedish model if not yet installed.
3. Hold the selected key with Mumla focused, then repeat with TextEdit focused
   and Mumla's menu closed. Normal Ctrl shortcuts must still cancel dictation.
4. If it fails, copy the diagnostic from the icon beside Keyboard access and
   report it together with the app that had focus.

This is a beta. Passing simulated tests, signature checks, and notarization do
not prove hardware hotkey or target-app paste behavior on the user's Mac.
