# Mumla for Mac 1.0.1 (31) - Hotkey Recovery Beta

Repairs silent global-hotkey failures by exposing keyboard permission and
listener status. Includes a permission/retry control in Settings and the menu
bar, plus recovery after returning from System Settings or a disabled listener.
The saved Control, Right Option, or Fn selection is preserved.

Requires macOS 14 or later. Supports Apple Silicon and Intel. This is the
Developer ID direct-download variant, not a TestFlight upload. The repository
remains private. iOS and the existing Mac TestFlight build are unchanged.

## Install

1. Quit every running Mumla copy, including the TestFlight version.
2. Unzip `Mumla-1.0.1-31.zip` and replace `/Applications/Mumla.app`.
3. Open Mumla. In Settings, select the dictation key and use Keyboard access if
   it does not report that the key is ready.
4. Enable the installed Mumla app in System Settings > Privacy & Security >
   Input Monitoring. Also grant Microphone and Accessibility for dictation and
   auto-paste. Check that permission entries refer to the installed app copy.
5. Quit and reopen Mumla if macOS asks. Wait for the model to be ready.

Existing history, dictionary, settings, and models are retained. Do not run the
TestFlight and direct variants simultaneously. Do not disable Gatekeeper.

## Verify

1. In a blank TextEdit document, hold the configured key for at least 250 ms,
   speak a short sentence, and release. The recorder should appear while held.
2. Confirm the text is inserted once and no Copy dialog appears after confirmed
   insertion. Existing clipboard contents should be restored.
3. Try Ctrl+C or another normal shortcut: it must not record or insert anything.
4. Double-tap the configured key to start hands-free; tap once to finish.
5. Switch trigger keys and repeat. Test your usual app, not just TextEdit.
6. With no editable field focused, a completed transcript remains in the mini
   recorder for manual copying. Secure/password input must not be recorded.

84 Swift tests and 10 signing tests passed. Live hotkey and auto-paste acceptance
on the installed target Mac remains pending; passing simulated tests is not
proof that its macOS permissions are configured.
