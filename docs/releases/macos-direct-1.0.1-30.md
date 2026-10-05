# Mumla for Mac 1.0.1 (30) - Direct Beta

The first Developer ID-signed and Apple-notarized direct Mac build. This variant
is not sandboxed, allowing Mumla's existing Accessibility-based paste workflow
after you grant permission. It does not disable or bypass macOS security.

Requires macOS 14 or later. Supports Apple Silicon and Intel. The repository
remains private; a GitHub account with repository access is required to download.
iOS and the existing Mac TestFlight build are unchanged.

## Install

1. Quit the TestFlight version of Mumla and any other running Mumla copy.
2. Download `Mumla-1.0.1-30.zip`, unzip it, and move `Mumla.app` into Applications.
   Replace an older app copy only after quitting it. Do not run both variants.
3. Open Mumla and allow microphone access when prompted. Wait for the model to
   be ready if this is your first launch.
4. In System Settings > Privacy & Security > Accessibility, add the new
   `/Applications/Mumla.app` using `+` and enable it. If an old Mumla permission
   entry points to another copy, remove that entry and add the new app.
5. Quit and reopen Mumla after changing permissions. Choose your dictation key
   in Mumla's settings if you do not want the default Control key.

Existing direct data takes precedence. Otherwise, Mumla adopts its existing
TestFlight data in place when available, without moving or overwriting it.
The direct MVP currently stores data locally; CloudKit sync is not implemented.

## Verify Auto-Paste

Cross-app auto-paste has not yet been validated on a real target Mac with this
build. Notarization and passing tests are not proof of successful insertion.

1. Copy some existing text, then open a blank TextEdit document and focus it.
2. Hold the configured dictation key, speak a short sentence, and release.
3. Confirm the transcript appears once at the cursor and the mini window
   disappears without a Copy dialog. Confirm the previous clipboard is restored.
4. Repeat in your usual app, and with selected text to verify replacement.
5. Repeat with no editable text field focused. A completed transcript should
   remain in the mini window with a Copy button. Nothing should auto-copy until
   you press it. Secure/password input must not be inspected or recorded.

Never retry an unconfirmed paste automatically: the first attempt may have
landed. Completed dictations are saved in history before insertion is attempted.

## Release Checks

- 67 Swift tests and 10 signing tests passed.
- Developer ID Application signature for team `PF2PWR4YG4`, hardened runtime,
  secure timestamp, and microphone entitlement; no App Sandbox or debug access.
- Apple notarization accepted; stapled ticket validated and Gatekeeper passed.
- Final ZIP unpacked and its signature, ticket, and Gatekeeper acceptance
  verified independently. No signing credentials are included in the download.

ZIP size: 22,539,868 bytes.

SHA-256:

```text
9002fa5d58480d087de290bae884ee4eceaee508aae7f952a734a746a3bbf531
```
