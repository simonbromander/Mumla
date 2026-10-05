# Mumla for Mac 1.0.1 (32) - Background Hotkey Beta

Follow-up to the report that dictation only starts while Mumla's menu is open.
This build requires Input Monitoring explicitly instead of assuming that
Accessibility permission also authorizes global keyboard listening. A listener
is ready only after its real event mask and global scope have been validated.

- Verify the exact installed event tap belongs to Mumla, is global, is enabled,
  and includes every keyboard and cancellation event the hotkey requires.
- Refuse partial, mouse-only, or app-local taps rather than falsely showing
  that the key is ready. macOS can remove disallowed events from a requested
  mask while still returning a valid tap.
  [Apple's documentation](<https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)>).
- Keep the hold timer in the main run loop's common modes, for both normal
  background operation and menu tracking. No polling timer runs while idle.
- The Keyboard access control requests permission and forces a fresh listener
  installation. The app delegate stays alive throughout the application loop.
- Dictation models, text insertion, history, branding, and iOS are unchanged.

Requires macOS 14 or later; Apple Silicon and Intel. This is a direct-download
Developer ID build, not a TestFlight upload. The repository remains private.

## Install And Verify

1. Quit every Mumla copy, unzip `Mumla-1.0.1-32.zip`, and replace the app in
   Applications. Do not run the direct and TestFlight variants simultaneously.
2. Open Mumla > Settings > Keyboard access. Enable the installed app under
   System Settings > Privacy & Security > Input Monitoring, not just
   Accessibility. Grant Microphone and Accessibility for dictation and paste.
3. Quit and reopen Mumla if macOS asks. Confirm Keyboard access reports the
   selected key ready. Wait for the transcription model to be ready.
4. Close Mumla's menu and window, focus a blank TextEdit document, then hold
   the configured key for at least 250 ms. Speak and release. Repeat in Notes
   and your usual app with the menu still closed.
5. Confirm one insertion and no Copy dialog after successful paste; Ctrl+C and
   other normal shortcuts must not record. Double-tap starts hands-free.
6. If it only fails in Terminal/iTerm, check Secure Keyboard Entry. Password
   and secure-input recording remain deliberately blocked.

The native timer tests exercise normal run-loop mode while the app is inactive
and menu tracking. Metadata tests reject partial/local/disabled taps. These are
not proof of real key delivery on your installed Mac; hardware hotkey and
cross-app paste acceptance still need the menu-closed check above.

94 Swift tests and 10 signing-selection tests passed. The live-system denied
permission test passed on this build host without requesting any new access.
