# Full-Capability Mac Distribution

## Why It Is Separate

The dictation workflow inspects the focused field in another app, sends Cmd+V,
and checks whether that field changed. The ordinary Mac App Store/TestFlight
sandbox does not support this unrestricted Accessibility workflow.
[Apple DTS explains the restriction](https://developer.apple.com/forums/thread/780626).

`MumlaMac` remains the sandboxed App Store/TestFlight scheme. `MumlaMacDirect`
uses the `Direct` configuration: hardened runtime, microphone entitlement,
Developer ID Application signing, no App Sandbox. Both retain `com.mumla.app`.
The direct build currently stores data locally; CloudKit sync is not implemented
in this MVP and its unused restricted entitlements are not added to this build.

## Auto-Paste Behavior

- Capture the editable target before recording and showing the nonactivating pill.
- Reject secure input, disabled fields, and fields explicitly marked read-only.
  Browser/Electron fields do not need Accessibility value setters to accept paste.
- Stage the transcript on the clipboard, then send one PID-targeted Cmd+V using
  a private event source, only while the original field remains focused.
- Poll for up to 800 ms for the expected field update instead of checking once
  after 200 ms. A text-only editor without a cursor range can confirm an exact
  insertion; a changed/opaque field is not assumed to be a successful paste.
- Restore every original clipboard item/type after success or failure, unless
  the user copied something newer. No clipboard write occurs before validation.
- On confirmed insertion, dismiss the pill without a transcript/copy dialog.
  A blocked or unconfirmed paste retains the transcript in the existing pill.
  The transcript is copied only when the user presses Copy. Never retry an
  unconfirmed paste automatically because the first attempt may have landed.
- Save every dictation in history before attempting insertion.

## Existing Data

If the direct app already has data, it uses that store. Otherwise it adopts
Mumla's existing TestFlight container in place, including history, dictionary,
settings, models, and resumable downloads. Nothing is overwritten or moved and
large models are not duplicated. Do not run the two variants simultaneously.

## Build and Notarize

An account holder must create/install a Developer ID Application certificate
with its private key on the build Mac. Keep that key local and out of Git.
[Apple's certificate instructions](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/).

```bash
security find-identity -v -p codesigning
ruby fastlane/tests/direct_signing_test.rb
swift test
fastlane ios mac_direct_build build:32
fastlane ios mac_direct_notarize
```

The build lane uses an already-installed, unexpired Developer ID Application
identity for this team, selected by certificate fingerprint. It never requests
or creates certificates through Apple's API and does not require App Store
Connect access. Importing a `.cer` without its matching private key is not
enough; use a CSR generated on the build Mac or import a password-protected
`.p12` containing the certificate and its key. Keep all signing material local.

The notarization lane reads the same `ASC_KEY_ID`, `ASC_ISSUER_ID`, and
`ASC_KEY_PATH` used by the existing release workflow. The lanes do not upload
to TestFlight or publish a download. The build lane verifies this team's
Developer ID signature and the absence of sandboxing. The notarization lane
requires `Accepted`, staples and validates the ticket, checks Gatekeeper, and
repackages the stapled app as:

`.build/DirectMac/Mumla-1.0.1-32.zip`

Quit the TestFlight app before replacing it with the direct app. Launch the
direct app and grant Microphone, Input Monitoring, and Accessibility access in
System Settings. Input Monitoring is for the global dictation key; Accessibility
is for inspecting the destination field and confirming a paste. After switching
between TestFlight and Developer ID copies, check the installed app's permission
entries and quit/reopen Mumla if macOS requests it.
Do not disable Gatekeeper or instruct testers to bypass signing checks.

## Verification Snapshot: 2026-09-30

- 65 core/Mac tests passed, including delayed/failed paste, safe clipboard
  restoration, newer user clipboard copies, secure input, focus changes,
  successful-pill dismissal, and existing-data adoption.
- The unsigned `Direct` verification build compiled for arm64 and x86_64;
  version `1.0.1 (28)`, bundle `com.mumla.app`, distribution marker `direct`.
- Developer ID certificate creation was rejected by Apple: `This operation can
  only be performed by the Account Holder`. No signed/notarized build 28 is
  available yet; do not label an unsigned verification build distributable.
- The local test process reports Accessibility trust and event-posting access
  as false. Unit tests exercise a simulated editor; they do not establish live
  cross-app acceptance.

## Signing Preparation: 2026-10-01

- Direct build 30 is reserved; Mac TestFlight build 29 and iOS are unchanged.
- 10 signing-selection tests and all 67 Swift tests passed. Signing tests cover
  missing private-key identities, the wrong certificate type/team, validity
  dates, and deterministic selection of a usable local identity.
- The supplied Developer ID Application certificate is valid for this team,
  but its public key does not match the CSR/private key generated on this Mac.
  Importing the certificate did not create a usable codesigning identity.
- The actual build lane stops at its local signing preflight with an actionable
  missing-private-key error, before archiving or contacting Apple's API. Create
  a certificate from the supplied CSR or import a matching `.p12` as a file.
- No signed/notarized build 30 or GitHub release has been produced. Real
  auto-paste acceptance remains unverified; passing tests do not resolve that.

## Direct Beta: 2026-10-05

- The Account Holder supplied a G2 Developer ID Application certificate created
  from this build Mac's CSR. Its matching private key and certificate were
  verified and imported locally. No signing keys or passwords enter Git.
- Universal `1.0.1 (30)` was archived and exported for arm64 and x86_64, minimum
  macOS 14.0, bundle `com.mumla.app`, distribution marker `direct`.
- The exported app has this team's Developer ID signature, hardened runtime,
  and a secure timestamp. Its only entitlement is microphone access: no App
  Sandbox, debugger, app-group, or unused CloudKit entitlements.
- All 67 Swift tests and 10 signing-selection tests passed again.
- Apple notarization `94da0777-b974-43e2-9dca-51d9acb086b1` was `Accepted`.
  The ticket was stapled and validated; Gatekeeper reports
  `source=Notarized Developer ID`.
- The final ZIP was unpacked into a fresh verification directory. Its code
  signature, stapled ticket, Gatekeeper acceptance, and ZIP integrity were
  independently verified. Size: 22,539,868 bytes.
- SHA-256: `9002fa5d58480d087de290bae884ee4eceaee508aae7f952a734a746a3bbf531`.
- App source is `b80915118dcb265d2fc7cdf9e3148a8a6f4f5d6d`; the tracked Xcode
  project is regenerated from its existing `project.yml` to synchronize the
  Direct build number. No transcription or insertion behavior changed here.
- GitHub prerelease tag: `macos-1.0.1-30`. Only the notarized ZIP and its checksum
  are release assets. The repository remains private; download requires access.
  [Installation and beta notes](releases/macos-direct-1.0.1-30.md).
- Local evidence: `.build/DirectMac/build-audit-30.json`,
  `.build/direct30-build-20261005.log`,
  `.build/direct30-notarize-20261005.log`, and
  `.build/direct30-swift-tests-20261005.log`.
- Signing/distribution verification is complete. Cross-app paste acceptance is
  still pending, so this is a beta, not a verified stable auto-paste release.
  Mac TestFlight build 29 and iOS are unchanged.

## Runtime Acceptance Before Stable Release

With the signed direct app installed and permission granted, verify release of
the selected hold key in a blank TextEdit document and in the actual target app.
Check selection replacement, Swedish characters, slow browser editors, no
transcript dialog after success, and restoration of rich clipboard contents.
Then try no focused text field, revoked permission, and a secure field: no
insertion and a persistent manual-copy pill for a completed transcript. Ensure
the pill never steals focus and each attempt is saved in history exactly once.

## Hotkey Recovery

- The keyboard listener reports active, missing Input Monitoring permission,
  or unavailable instead of silently ignoring an event-tap installation failure.
- Settings and the menu bar offer a permission/retry action. Permission requests
  occur only after a user action; normal startup does not explicitly request one.
- Retry the listener when the foreground app changes or Mumla becomes active,
  including after returning from System Settings. A healthy listener is reused;
  a disabled or invalid listener is recovered without losing the saved key.
- Cancelling or stopping a listener resets pending holds and double-tap state.
  Secure input still blocks recording, and other keys cancel Ctrl shortcuts.
- There is no idle polling timer or change to transcription/paste behavior.
- 84 Swift tests passed, including 17 new monitor/coordinator regression tests.
  Real key events and cross-app paste on the installed signed build still need
  acceptance on the target Mac; simulated tests do not establish TCC access.

## Hotkey Recovery Beta: 2026-10-05

- Universal `1.0.1 (31)` was built from
  `5f3b31e5bfc390c05c7e6e379b442c3b9f201b48`; transcription and insertion behavior
  is unchanged. Input Monitoring is now an explicit permission/recovery path.
- 84 Swift tests and 10 signing tests passed. The compact Settings layout was
  rendered and visually inspected with the existing tactile design.
- Apple notarization `47a95225-a3eb-4c20-9098-526f53a35279` was accepted. The ticket
  was stapled and validated; the repacked ZIP was freshly extracted and checked
  for signature, ticket, Gatekeeper, ZIP integrity, and build identity.
- ZIP size: 22,552,826 bytes. SHA-256:
  `4b0b6e0f62ebb2d7e22d6bed5b0950bc659d0ff0c61a50f05f4bc2513fa98e91`.
- Private GitHub prerelease tag: `macos-1.0.1-31`, with only the notarized ZIP and
  its checksum. [Installation and testing notes](releases/macos-direct-1.0.1-31.md).
- Local evidence: `.build/DirectMac/build-audit-31.json`,
  `.build/direct31-build.log`, `.build/direct31-notarize.log`,
  `.build/hotkey-fix-focused-tests.log`, and `.build/hotkey-fix-all-tests.log`.
- Signing and packaging passed; live hotkey/TCC and paste acceptance on the
  installed target Mac remain pending. Mac TestFlight build 29 and iOS are
  unchanged; this does not claim sandboxed cross-app paste support.

## Background Hotkey Follow-Up

- Build 31 could count Accessibility trust as keyboard-listening permission
  and mark a successfully created port as ready without checking its actual
  global event mask. A port may still be valid after disallowed keyboard events
  are removed. [Apple's event-tap documentation](<https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)>).
- Build 32 requires `CGPreflightListenEventAccess()` explicitly, validates the
  exact newly installed tap ID and every requested event, and rejects app-local
  or partially permitted listeners. Manual retry forces a fresh installation.
- The one-shot hold timer is registered in the main run loop's common modes;
  the app delegate/listener lifetime is explicitly kept across `NSApplication.run`.
- All 94 Swift tests and 10 signing tests passed. Tests include native timer
  execution with the app inactive in default mode, menu tracking, partial/local
  mask rejection, and refusal to install a partial tap on this permission-denied
  test host. These checks still do not prove hardware input on the target Mac.
- No idle polling, microphone/security bypass, or text-insertion changes were
  added. [Installation and menu-closed acceptance](releases/macos-direct-1.0.1-32.md).

## Background Hotkey Beta: 2026-10-05

- Universal `1.0.1 (32)` was built from
  `ef74bc814cca2a8c0ce71c2fe240b08df9c80476` and signed with the existing
  Developer ID identity. App identity and microphone-only entitlements remain
  unchanged; Mac TestFlight and iOS were not uploaded or modified.
- Apple notarization `2d084a26-ed50-41ce-89ff-8bfea9773356` accepted; ticket
  stapled/validated and Gatekeeper passed. A fresh ZIP extraction was independently
  checked for signature, ticket, integrity, and version/bundle identity.
- ZIP size: 22,559,864 bytes. SHA-256:
  `0f70f56dd63f18080174bee09a0ae66ee2842f2793d0ccf146091510eca9547e`.
- Private GitHub prerelease tag: `macos-1.0.1-32`, with the notarized ZIP and
  checksum only. The installed target Mac still needs the menu-closed check;
  local tests and successful distribution are not proof of hardware input.
- Local evidence: `.build/DirectMac/build-audit-32.json`,
  `.build/direct32-build.log`, `.build/direct32-notarize.log`,
  `.build/hotkey-background-focused-tests.log`, and
  `.build/hotkey-background-all-tests.log`.

## Updater and Focused Hotkey Build: 2026-10-05

- Direct `1.0.1 (35)` was built from
  `62957a1aa07297f7540f7169f2cc11038028bb85`; bundle and team are unchanged.
  It adds direct Settings routing, a focused-app listener, trigger diagnostics,
  early hold-timer recovery, and the direct-only signed updater.
- All 113 Swift tests passed. The compact Settings rendering was inspected.
  Signing tests passed with 12 tests/13 assertions; feed policy tests passed
  with 6 tests/18 assertions. Simulated tests are not hardware acceptance.
- Apple notarization `5c6c9c0b-ea83-4f2e-92ef-7b060c5304e8` was accepted.
  The ticket was stapled and validated, and Gatekeeper accepted the app.
- The notarized ZIP SHA-256 is
  `abc20636f67947f4212425f893c9dc18992d6c4bd19e2651b7b63985aa0043c9`.
- The current sandboxed `MumlaMac` source also compiled for both architectures.
  Its binary has no Sparkle dependency or updater feed metadata. Its unchanged
  build number 29 is a local compile check, not a new TestFlight upload.
- Build 35 is a prerelease in both the private source repository and the public
  downloads-only `Mumla-Releases` repository. Only the notarized ZIP and checksum
  are assets. Public Git contains README and the signed appcast, not app source.
- Feed signing completed after an initial Keychain wait. The update key remains
  in the local Keychain. Anonymous ZIP download and Ed25519 verification passed
  before feed publication. The live feed is byte-identical to the signed staging
  feed; live feed signature and enclosure verification also passed.
- Public feed commit: `a4cf0da`. ZIP size: 23,594,069 bytes.
  [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-35).
- Live update/replacement/relaunch testing is blocked by pending Computer Use
  permissions. Hardware hotkey, cross-app paste, and preservation of populated
  user data remain unverified. The build host's local stores were empty.
- Evidence: `.build/direct35-build.log`, `.build/direct35-notarize.log`,
  `.build/DirectMac/notarization35.json`, `.build/hotkey-local-tests.log`,
  `.build/hotkey35-app-store-build.log`, and `.build/hotkey-settings-compact.png`.
- [Store compatibility and the proposed paste-only experiment](mac-app-store-compatibility.md).
