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
fastlane ios mac_direct_build build:30
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

`.build/DirectMac/Mumla-1.0.1-30.zip`

Quit the TestFlight app before replacing it with the direct app. Launch the
direct app and grant Microphone and Accessibility access in System Settings.
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

## Runtime Acceptance Before Release

With the signed direct app installed and permission granted, verify release of
the selected hold key in a blank TextEdit document and in the actual target app.
Check selection replacement, Swedish characters, slow browser editors, no
transcript dialog after success, and restoration of rich clipboard contents.
Then try no focused text field, revoked permission, and a secure field: no
insertion and a persistent manual-copy pill for a completed transcript. Ensure
the pill never steals focus and each attempt is saved in history exactly once.
