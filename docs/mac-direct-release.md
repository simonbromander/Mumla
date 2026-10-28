# Full-Capability Mac Distribution

## DJI Mic Button Beta: 2026-10-28

- Universal direct `1.0.1 (42)` is published as a prerelease in Mumla and
  Mumla-Releases, from `062cc5b3889915a5684a30412c5e26eb97a9f835`.
- Includes optional native DJI Mic Mini USB receiver button control and the
  branded waveform/record-button menu-bar icon from PR #9. DJI control is off
  by default and needs Input Monitoring. Microphone selection remains separate.
  The listener handles duplicate reports, pairing holds, permission denial,
  helper conflicts, sleep and receiver removal; existing dictation and paste
  protections remain in place.
- 256 shared/Mac tests completed with zero failures and four opt-in model
  tests skipped; all 35 release-helper tests passed with 84 assertions. The
  iOS Release Simulator preflight and signed Mac archive/export passed.
- arm64/x86_64, Developer ID signature, hardened runtime, matching dSYMs,
  microphone-only entitlements, updater metadata and MLX Metal library verified.
  Model weights are downloaded separately, not bundled in the release.
- Apple notarization `5d18d683-1313-4574-ae8f-3fc457922e38` was Accepted.
  The stapled app passed Gatekeeper. A fresh anonymous public ZIP passed the
  same signature, ticket, Gatekeeper and binary checks; ZIP integrity passed.
- ZIP: 37,143,617 bytes. SHA-256:
  `c226cfe39ca057e03d558bfd57f3f07bd03863da7d9d7b881c0fa8e8ac04367b`.
  Both official repositories contain matching ZIP and checksum assets.
- Feed commit `4ea6e3a`. The live feed is byte-identical to signed staging;
  public downloads and Ed25519 signatures for 42, 41 and 40 passed before and
  after publication. Real DJI button/audio routing, cross-app paste, live updater
  installation and model quality still require hardware acceptance.
- Evidence: `.build/direct42-build.log`, `.build/direct42-notarize.log`,
  `.build/direct42-local-audit.json`, `.build/direct42-public-audit.json`,
  `.build/direct42-feed-prepare.json`, `.build/direct42-public-verify.json`
  and `.build/direct42-live-public-verify.json`.
  dSYMs and the anonymous ZIP are retained in
  `.build/ReleaseAuditMac42-20261028/`. No private logs or signing material were
  published. iOS/Watch build 35 is a separate TestFlight release.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-42).

## Local Qwen And Compact Controls Beta: 2026-10-20

- Universal direct `1.0.1 (41)` is published as a prerelease in Mumla and
  Mumla-Releases, from `5d420373424ec2e53974e9e91fc4853057011423`.
- Includes optional Qwen3.5 4B formatting/summaries through MLX on Apple silicon,
  context-guided formatting previews, compact glass controls and the pinned
  microphone Bluetooth fix from @ehsanYazdani's PR #6. The optional 3.1 GB text
  model is downloaded separately; it is not bundled. Intel dictation remains
  supported, without Qwen generation. Review generated suggestions before use.
- 242 shared/Mac tests completed with zero failures and four opt-in model
  tests skipped; 35 release-helper tests passed with 84 assertions. Contributor
  CI passed for this release source, including full-history secret scanning,
  package/helper tests and native builds. These are not model-quality gates.
- arm64/x86_64, Developer ID signature, hardened runtime, matching dSYMs,
  microphone-only entitlements, pinned updater metadata, MLX Metal library and
  bundled runtime licenses verified. No sandbox/debug entitlement or model
  weights were added to the download.
- Apple notarization `e20563a3-51b9-4b70-b7b7-53e01dd500bd` was Accepted.
  The stapled app passed Gatekeeper and ZIP integrity checks. A fresh anonymous
  download passed signature, ticket, Gatekeeper and checksum verification.
- ZIP: 37,081,738 bytes. SHA-256:
  `ac586fa485d18fe84a7f1fa49a6793605871e79ffe3e74f4c3ba9777e7cc8ed8`.
  Both official repositories contain the ZIP and checksum. A timed-out upload
  was recovered through a temporary asset name, then renamed before updating
  the feed. No feed URL or enclosure-host policy was changed.
- Feed commit `a4642fa`. The live feed is byte-identical to the signed staging
  file; anonymous downloads and Ed25519 signatures for 41, 40 and 39 passed
  before and after publication. Live installation/relaunch, actual Bluetooth
  routing, cross-app paste and Swedish/Qwen quality remain acceptance checks.
- Evidence: `.build/direct41-build-final.log`, `.build/direct41-notarize.log`,
  `.build/DirectMac/build-audit-41.json`, `.build/direct41-public-audit.json`,
  `.build/direct41-public-verify-final.json` and
  `.build/direct41-live-public-verify.json`. No internal logs or signing
  material were published.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-41).
  iOS/Watch build 34 is a separate TestFlight upload; no sandboxed Mac
  TestFlight upload was made by this direct release.

## Microphone And Reliability Beta: 2026-10-14

- Universal direct `1.0.1 (40)` is published as a GitHub prerelease in Mumla
  and Mumla-Releases, from `41dd32da5c2d38ce72ce996da98270f4965247ed`.
- Includes @ehsanYazdani's merged PRs #3, #4 and #5: keep the main window
  alive after closing it to prevent reopen crashes; remember a dictation
  microphone without changing the system default; explain trigger presses
  blocked by Secure Input while leaving recording and protected fields blocked.
- A disconnected or unavailable pinned microphone falls back to the system
  default. A remembered device can be matched on reconnection by UID or a
  unique display name. Physical routing, disconnect/reconnect and actual
  Secure Input event delivery still require target-hardware acceptance.
- Retains build 39's Chromium paste confirmation and build 38's optional
  silent clipboard fallback. Model inference is unchanged. Local formatting
  and summary quality remains experimental.
- 209 shared/Mac tests completed with zero failures and one opt-in live-model
  skip; all 31 release-helper tests passed. Contributor CI's full-history
  secret scan, package/helper tests and unsigned native builds passed for
  the release source. These checks are not physical dictation acceptance.
- arm64/x86_64, Developer ID signature, hardened runtime and microphone-only
  entitlements verified. Apple notarization
  `49f22cc0-d6f0-4e70-a73d-6d63b335ebd3` was Accepted. The ticket was stapled;
  a fresh anonymous public-ZIP extraction passed code signature, ticket and
  Gatekeeper checks. ZIP integrity passed. No sandbox or debugger entitlement.
- ZIP size: 23,262,081 bytes. SHA-256:
  `29c49ec62be36539f7a67180c362d0c9f7a49a76021a477637d178c6bb37fde2`.
  The anonymous download and public checksum matched the staged archive.
- Feed commit `1343416`; public downloads and Ed25519 signatures passed before
  publication. The live feed is byte-identical to staging, and all enclosures
  (40, 39, 38) passed public verification. Live update installation/relaunch
  and populated-data preservation remain separate acceptance checks.
- Local evidence: `.build/direct40-build.log`, `.build/direct40-notarize.log`,
  `.build/direct40-swift-tests.log`, `.build/direct40-release-helper-tests.log`,
  `.build/direct40-feed-prepare.json`, `.build/direct40-public-verify.json`,
  `.build/direct40-live-public-verify.json` and
  `.build/DirectMac/build-audit-40.json`. Only the notarized ZIP and checksum
  were uploaded as release assets.
- [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-40).
  No iOS or sandboxed Mac TestFlight upload was performed by this release.

## Chromium Paste Confirmation Beta: 2026-10-12

- Universal direct `1.0.1 (39)` is published as a GitHub prerelease in Mumla
  and Mumla-Releases, from `7fdec0f24d522c9832eafdf03387dfd377a598af`.
  This source includes @ehsanYazdani's merged
  [PR #2](https://github.com/simonbromander/Mumla/pull/2), which was not in build 38.
- Confirms complete text insertion into empty Chromium/Electron editors whose
  Accessibility baseline is newline-only, including normalized line endings.
  Confirmed pastes dismiss the bottom bar and restore the prior clipboard.
  Partial, unchanged and unrelated text are still rejected. Existing focus,
  secure-input, permission and newer-clipboard guards remain in place.
- Includes build 38's optional silent clipboard fallback. No recording,
  transcription, hotkey or model behavior changed. Local formatting and
  summary quality remains experimental.
- 201 shared/Mac tests completed with zero failures and one opt-in live-model
  skip; all 31 release-helper tests passed. Contributor CI's full-history
  secret scan, package/helper tests and unsigned native builds passed for the
  release source. These checks are not physical target-app acceptance.
- arm64/x86_64, Developer ID signature, hardened runtime and microphone-only
  entitlements verified. Apple notarization
  `18dbb5eb-b367-4019-b243-edd8d41e803f` was Accepted. The ticket was stapled;
  a fresh anonymous public-ZIP extraction passed code signature, ticket and
  Gatekeeper checks. ZIP integrity also passed. No sandbox or debugger entitlement.
- ZIP size: 23,214,128 bytes. SHA-256:
  `731dcae4cb0aed8d24b29a82c96cb06b14a8c5953d5c246dc6296a2ea1464fbb`.
  The anonymous download and public checksum matched the local staged archive.
- Feed commit `d7441a6`; public downloads and Ed25519 signatures passed before
  feed publication. The live feed is byte-identical to staging, and all
  enclosures (39, 38, 37) passed public verification. Live update installation,
  relaunch and physical dictation/paste remain separate acceptance checks.
- Evidence is local in `.build/direct39-build.log`,
  `.build/direct39-notarize.log`, `.build/direct39-swift-tests.log`,
  `.build/direct39-release-helper-tests.log`, `.build/direct39-feed-prepare.json`,
  `.build/direct39-public-verify.json`, `.build/direct39-live-public-verify.json`
  and `.build/DirectMac/build-audit-39.json`. Only the notarized ZIP and checksum
  were uploaded as release assets.
- [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-39).
  No iOS or sandboxed Mac TestFlight upload was performed by this release.

## Silent Clipboard Fallback Beta: 2026-10-12

- Universal direct `1.0.1 (38)` is published as a GitHub prerelease in Mumla
  and Mumla-Releases, from `f214d6318c39ec31f271d262c44bce2bea152e2a`.
- Adds Mac Settings > Show Copy dialog. Switching it off copies failed,
  blocked or unverified pastes to the clipboard and hides the recorder, with
  no transcript/copy dialog. Newer user copies are protected; if copying is
  unavailable, History and menu-bar status remain the recovery path.
- Existing users keep the dialog-enabled default. Switching it off also handles
  an already-open fallback. Confirmed pastes still restore the clipboard. No
  automatic paste retry, microphone, hotkey or model change was added.
- 200 shared/Mac tests completed with zero failures and one opt-in live-model
  skip; all 31 release-helper tests passed. Unit tests are not real target-app
  acceptance. Existing formatting and summary quality remains experimental.
- arm64/x86_64, Developer ID signature, hardened runtime and microphone-only
  entitlements verified. Apple notarization
  `260603b3-50a0-460f-b54c-aad0c2b0c65e` was Accepted. The ticket was stapled;
  a fresh final-ZIP extraction passed code signature, ticket and Gatekeeper
  checks. ZIP integrity also passed. No sandbox or debugger entitlement.
- ZIP size: 23,213,886 bytes. SHA-256:
  `39a35adbd1e6bd7f2ff75a29665eadc5e30900ab3508500b9c1d6fba72b157f7`.
- Feed commit `9443180`; public downloads and Ed25519 signatures passed before
  publication. The live feed is byte-identical to staging, and all enclosures
  (38, 37, 36) passed public verification. In-app installation/relaunch and
  physical dictation/paste remain separate acceptance checks.
- Evidence is local in `.build/direct38-build.log`,
  `.build/direct38-notarize.log`, `.build/direct38-swift-tests.log`,
  `.build/direct38-release-helper-tests.log`, `.build/direct38-feed-prepare.json`,
  `.build/direct38-public-verify.json` and `.build/direct38-live-public-verify.json`.
  Only the notarized ZIP and checksum were uploaded as release assets.
- [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-38).
  No iOS or sandboxed Mac TestFlight upload was performed by this release.

## Local Text Beta: 2026-10-08

- Universal direct `1.0.1 (37)` is published as a GitHub prerelease in Mumla
  and Mumla-Releases. App source is `8cdfff858e50fa12b1e3f451a57e931c957febfa`;
  the iOS-only final text-wrapping adjustment does not change this Mac binary.
- Adds optional local formatting and separate summary previews, editable style
  preferences, delayed paste acknowledgement dismissal, Paste Last Transcript
  and the ten most recent transcripts. Generation never runs in the hotkey path.
- 190 shared/Mac tests completed, zero failures, one live-model test skipped.
  All 31 release-helper tests passed. Real target-app acceptance and Swedish
  model output quality are separate, still-pending checks.
- Developer ID signature, arm64/x86_64, hardened runtime and microphone-only
  entitlements verified. Notarization
  `6986cd27-3629-442c-9153-ec8469834676` was Accepted; ticket stapled and
  validated, Gatekeeper passed. No App Sandbox or debugger entitlement.
- ZIP size: 23,202,334 bytes. SHA-256:
  `ce523361eae99668c7caa4e776b586e6844d9acff8b7df9741e2208fc39fbf4a`.
- Public anonymous ZIP downloads and Ed25519 signatures passed before feed
  publication. Feed commit `4a6f11f`; the live feed is byte-identical to the
  verified staging feed and all enclosures (37, 36, 35) passed signature checks.
  Live in-app installation/relaunch is not claimed by these checks.
- Local evidence: `.build/direct37-build.log`, `.build/direct37-notarize.log`,
  `.build/direct37-feed-prepare.json`, `.build/direct37-public-verify.json` and
  `.build/direct37-live-public-verify.json`. No logs or signing material published.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-37).
  iOS build 32 is a separate TestFlight beta; sandboxed Mac TestFlight remains 29.

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
- Accept focused group/web-area editors only when explicitly marked editable.
  Read text through the Accessibility text-range API when `AXValue` is absent;
  reject ranges larger than one million characters and recheck focus/security.
- Wait up to 300 ms for physical modifiers to release before reading the field
  or staging the clipboard. Cancel safely if focus, permission or secure input
  changes, or the insertion task is cancelled.
- Stage the transcript on the clipboard, then send one PID-targeted Cmd+V using
  a private event source, only while the original field remains focused.
- Poll for up to 800 ms for the expected field update instead of checking once
  after 200 ms. An editor without a cursor range, or with a stale collapsed
  range, can confirm an exact insertion with the rest of its text unchanged.
  Normalize line endings only; selection replacements still require the exact
  expected update. A changed/opaque field is not assumed to be a successful paste.
- Restore every original clipboard item/type after success or failure, unless
  the user copied something newer. No clipboard write occurs before validation.
  If the clipboard changes after staging but before dispatch, cancel rather
  than paste the user's newer clipboard contents into the destination.
- On confirmed insertion, dismiss the pill without a transcript/copy dialog.
  By default a blocked or unconfirmed paste retains the transcript in the pill,
  and copying requires pressing Copy. Switching off Mac Settings > Show Copy
  dialog enables silent clipboard fallback instead: copy and hide the recorder
  when possible, while preserving newer user copies. Otherwise retain the
  transcript in History and show the failure in menu-bar status, not a dialog.
  Never retry an unconfirmed paste because the first attempt may have landed.
- Save every dictation in history before attempting insertion.
- Copied keyboard diagnostics include `Paste: <outcome>` to distinguish target,
  permission, modifier, dispatch and verification failures without collecting
  field content, transcript text or application titles.

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

## Rams Appearance Beta: 2026-10-05

- Universal direct 1.0.1 (36) was archived from source
  `d0bc0eb64940c6466a31cf9f05f831a8ea38cdd9`. It adds persistent System / Light /
  Dark choices, a menu-bar Appearance submenu and the new Rams-inspired icon.
  It does not change hotkey, recording or paste behavior.
- The exported app retains `com.mumla.app`, team `PF2PWR4YG4`, macOS 14 minimum,
  arm64/x86_64, hardened runtime and microphone-only entitlements. No sandbox,
  debugger or unused CloudKit/App Group entitlements were added.
- All 132 core/Mac tests and 31 release-helper tests passed. Native appearance
  mapping, persistence, override reset and primary text contrast were checked.
- Apple notarization `edde0dcd-00f6-4d60-9482-edb8b05eaa22` was Accepted.
  Stapling, ticket validation and Gatekeeper acceptance passed.
- ZIP size: 22,949,303 bytes. SHA-256:
  `3b8471e9c3c275c9640f3bde343a9f64d3e0965a0535e1841589fbbfe1bd52ea`.
- Published prerelease `macos-1.0.1-36` in the private source repository and
  public downloads-only repository. Anonymous download and Ed25519 verification
  passed for both feed enclosures (36 and 35) before publishing the new feed.
- Feed commit: `0a2b424`. The live feed is byte-identical to the verified staging
  feed, and its signature passed verification. Existing direct build 35 can
  discover it through Check for Updates; live installation/relaunch remains
  unverified while this Mac is locked.
- [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-36).
- iOS and Mac TestFlight were not uploaded by this direct release. iOS 28 is
  waiting on keyboard App Group membership; Mac TestFlight remains build 29.
- Evidence: `.build/DirectMac/build-audit-36.json`, `.build/direct36-build.log`,
  `.build/direct36-notarize.log`, `.build/direct36-feed-prepare.json`,
  `.build/direct36-public-verify.json` and `.build/direct36-live-appcast.xml`.

## Auto-Paste Reliability Source Update: 2026-10-07

- Added support for explicitly editable group/web-area inputs and the public
  Accessibility text-range API fallback. Read-only terminal output is not
  treated as an editable input merely because it is a text area.
- Added physical-modifier release checks before field reads, clipboard staging
  and dispatch. Focus/security/cancellation failures do not trigger a retry.
- Paste verification tolerates stale collapsed cursor ranges and CRLF/LF
  conversion while still requiring one exact insertion or selection replacement.
  Posting an event alone does not dismiss the fallback pill.
- Regression tests reproduced the target-classification and verification gaps
  before the implementation changed. The expanded tests cover clipboard
  preservation, cancellation, focus changes, secure input and opaque targets.
- All 155 Swift package tests passed, including 33 focused Mac paste/clipboard/
  transcript-pill tests. No physical cross-app result is inferred from mocks.
- The universal unsigned Mac compile check succeeded. Live Claude Code acceptance
  is still pending: the testing Mac is locked and the user's Claude Code host
  (terminal, VS Code or desktop) has not yet been identified.
- This is a source update, not a new signed/notarized download. Existing GitHub
  build 36 does not acquire these changes until a new direct release is published.
