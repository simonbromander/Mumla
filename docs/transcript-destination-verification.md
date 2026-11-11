# Transcript destination verification

Status: implemented on a separate branch after experimental Mac meetings build 45.
Not included in build 45. A live receiver acceptance check is still required before
shipping this feature.

## Behavior

In Settings, enter one destination name, HTTPS address and bearer token, then Save.
Save performs no request. A blank token preserves the existing token only when the
address is unchanged; changing the address requires a new token. Test sends only a
short synthetic transcript to the saved destination. Remove deletes its address
and app-only Keychain credential. No keyboard or Watch credential access is added.

Send actions appear only with a configured destination, next to transcript sharing
on Mac and iPhone, in the Mac history menu and beside voice-note text sharing.
The destination name is visible before sending. Existing history click-to-paste
and explicit audio sharing remain unchanged. Repeated sending requires confirmation.

The request contains one transcript's full current text, an 80-character one-line
title, language, original recording date, duration in seconds and app version.
It never contains audio, audio paths, checksums, other transcripts or device IDs.
Unknown historical durations use zero. Only 2xx responses mark `sentAt`; this is
a last-send date, not proof that subsequently edited text was delivered.

No automatic retries, redirects, credential challenges, cookies, shared credentials
or response-body storage are used. TLS verification stays enabled. Timeout or a
lost connection can mean the receiver accepted the item without returning a
response; check the receiver before explicitly sending again. A successful request
with a failed local receipt save is reported as sent, with a local-save warning.

## Automated verification

Local results on 2026-11-11: 321 Swift package tests (9 pre-existing model/hardware
skips), 2 hosted sandboxed Mac tests, 22 hosted iOS tests, 4 destination UI tests and
35 release-helper tests passed. The direct Mac app built successfully. Native light
mode screenshots were inspected for Mac Settings and the iPhone transcript view.
The four destination UI tests also passed on a compact iPhone layout; settings and
transcript screenshots were inspected at that size.

- Swift package tests cover payload fields, full Unicode text, headers, HTTPS-only
  validation, HTTP outcomes, timeout/no retry, redirect refusal, isolated URLSession
  timeout, old history, receipt edits, stable Watch transfer identity, settings
  rollback, endpoint-bound credentials, concurrent taps and unchanged paste menus.
- Hosted tests on Mac and iOS exercise real app-only Keychain save/update/read/delete
  in a unique disposable namespace and a synthetic text-only send with persistence.
- iPhone UI tests check absence without configuration, destination naming, a successful
  synthetic send, repeat confirmation, settings save/test/remove and voice-note text
  sending alongside the existing recording share action. UI fixtures cannot use
  the production Keychain or network.
- The Mac test host uses the actual app sources with App Sandbox and outbound client
  networking enabled. Its separate identity and minimal test-only entitlements avoid
  requiring an iCloud provisioning profile. Production identities and entitlements
  are unchanged. XCTest startup bypasses production history, hotkeys and recording.

Run `swift test`, the `MumlaMacTests` scheme and the `Mumla` scheme. For local hosted
tests, use Debug, local ad-hoc signing and an available iOS Simulator. CI runs the
hosted targets and focused destination UI checks as well as normal native builds.

## Privacy manifest reasoning

The developer and SDK partners do not receive these destination requests: there is
no developer-owned relay, telemetry or hosted receiver. The user chooses the receiver
and explicitly sends one transcript. That is the reason the manifest still declares
no developer-collected data; manual initiation alone would not justify this if a
developer or partner received the data. Receiver retention is outside Mumla's control.
Existing user-requested system sharing and paired Watch-to-iPhone audio transfer
remain explicit exceptions to local-only processing. Required-reason entries cover
existing file timestamps, app-private defaults and observable low-disk protection.
The shared manifest is embedded in both app builds.

## Pending live acceptance gate

Use a user-controlled HTTPS receiver configured through the app. Keep credentials
out of the repository, terminal commands, logs, screenshots and this document.

1. Use the sandboxed Mac build and send a non-sensitive transcript once.
2. Read the receiver back and verify exactly one item and the full unchanged text,
   recording date, duration, language, title and app version.
3. Verify normal iPhone behavior against that receiver, including a rejected token.
4. Confirm no additional requests occur on Save, launch, dictation, relaunch or failure.
5. Perform the release outbound-traffic audit and recheck App Store privacy answers.

Protocol stubs, successful Keychain tests and the network entitlement do not substitute
for the receiver readback. No live endpoint has been assumed or contacted during
automated verification.
