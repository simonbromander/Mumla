# Send Transcript To A Destination

Status: implementation plan only. Updated: 2026-11-11.
Based on source commit `7ee45b9`. No sending, credentials, or policy changes are
enabled by this document.

## Product Contract

Add one optional, user-configured destination to the containing Mac and iOS apps.
Each explicit Send action posts one saved transcript directly to that destination.
There is no developer relay, automatic sending, background queue, or audio upload
in this feature. Configuration is local to each device; credentials do not sync.

V1 supports `DictationRecord` and already-transcribed iPhone `VoiceNote` records.
The Send actions listed below do not include `MeetingRecord`, live meeting
segments, keyboard-extension sending, Watch sending, batch sending, several
destinations, or an MCP server. Existing meeting exports remain unchanged.
No new service-specific SDK, destination name, real endpoint, or credential goes
into source, fixtures, documentation, screenshots, or PR evidence.

The owner confirmed that existing paired Watch-to-iPhone audio transfer and
explicit audio sharing must remain. Existing system Share/export actions for
text also remain. Destination Send is a separate, strictly text-only action.

## Repository Findings

- `AppSettings` has a custom backward-compatible decoder. The new optional
  destination must be added to its initializer and coding keys without resetting
  existing settings when the new field is absent or invalid.
- Mac already owns an `AppSettingsStore`; iOS `DictationSession` currently does
  not. Add iOS settings ownership rather than another destination-specific file
  or a UserDefaults credential store.
- `DictationRecord` stores optional milliseconds; `VoiceNote` stores seconds.
  Both need optional `sentAt` and store methods that update only send metadata.
- `VoiceNote.deliveryID` hashes `transferData()`. Adding `sentAt` to that payload
  would change acknowledgement identity. Keep all destination-send metadata out
  of the existing Watch transfer serialization.
- `PrivacyInfo.xcprivacy` currently declares no tracking and an empty collected
  data array. The shared resource is included by iOS/Watch sources; the Mac app
  template does not currently include that shared resource directory.
- The sandboxed Mac entitlements already enable outgoing network connections.
  The direct Mac build is not sandboxed; do not add unrelated entitlements.
- There are package Mac tests and native hosted iOS/UI tests, but no hosted Mac
  test target. Add a native hosted target to meet the requested acceptance gate.

## 1. Privacy Changes First

The first implementation change updates `AGENTS.md`, the README privacy paragraph,
and `SECURITY.md` before adding a sender. Proposed priority 1, incorporating the
confirmed existing exceptions:

> Privacy: Audio stays on-device, except existing paired Watch-to-iPhone transfers
> and explicit user-requested sharing. Text leaves the device only through the
> user's own iCloud, an explicit system Share/export action, or one transcript sent
> by the user to a destination they configured. Destination Send never sends audio.

Describe iCloud as a permitted future path, not a claim that sync is implemented.
Keep model-download/update traffic distinct from transcript transmission. Explain
that the configured recipient controls retention after a successful send;
removing a destination does not delete previously received items.

Inspect the final bundled privacy manifests and generated privacy report. Include
the shared manifest as a resource in both Mac variants without pulling in the
shared Watch connectivity source. Review existing required-reason declarations;
do not add an unrelated reason or tracking domain just because HTTP is added.

### PR Privacy Rationale

Record the following reasoning in the implementation PR:

- Transcript text and the specified recording metadata travel directly from the
  containing app to the exact address supplied by the user, on an explicit action.
- Neither the developer nor an integrated service partner receives, proxies,
  retains, or gains access to that content or its bearer credential.
- There is no new analytics, tracking, response logging, or content-bearing
  diagnostics. Audio is not part of the destination request.
- Therefore this feature introduces no developer data collection. Retain the
  empty collected-data array and tracking disabled, conditional on verifying
  these boundaries in the implementation and privacy report. Manual activation
  alone is not the reason collection is absent.
- Recipient-side retention and existing user-requested sharing are disclosed
  separately. Reassess the declaration if a relay, partner integration, or
  content-bearing telemetry is introduced later.

## 2. Core And Storage

### Destination And Credentials

Add `TranscriptDestination` with a name and HTTPS URL, plus
`AppSettings.transcriptDestination: TranscriptDestination?`.

- Require a nonempty trimmed name and an absolute HTTPS address with a host.
  Refuse embedded username/password and fragments. Validate both user input and
  decoded settings, and revalidate before a request. Keep normal TLS trust checks.
- Invalid destination data disables that feature, not the user's other settings.
  Preserve old-settings decoding and existing hotkey/appearance preferences.
- Store only destination metadata in settings. Never save the bearer token in
  settings, UserDefaults, an App Group, a file, a log, or a transfer payload.
- Add `DestinationTokenStore` backed by Keychain, with an injectable interface
  for deterministic tests. Use an app-specific service/account scoped to the
  configured endpoint. Disable Keychain synchronization; on iOS use
  device-only, unlocked-device accessibility. No keyboard access group is added.
- Keep a newly entered token only in temporary secure-field state until Save;
  clear it after saving or dismissing. Existing credentials are not populated
  into ordinary text fields. Reject newline-bearing header values.
- A changed address must not silently reuse credentials for the old address.
  Require a replacement token before committing an endpoint change. Renaming an
  unchanged destination can retain its credential.
- Coordinate settings and Keychain writes with explicit failure handling. Do not
  activate a half-saved configuration or report removal until both stores have
  been cleared. Scope deletion to this feature's credential, never all app keys.

### Request Contract

Add `TranscriptSender` and a small text-only input type. That type cannot accept
an audio URL, `Data` attachment, whole `VoiceNote`, or recording store. UI adapters
extract only the text, language, recording date, and duration needed below.

| JSON Field | Value |
| --- | --- |
| `title` | First 80 Swift characters of a one-line, whitespace-normalized preview; no added ellipsis |
| `description` | Complete current transcript, unchanged, including line breaks and Unicode |
| `source` | `voice` |
| `language` | Stored record language, `sv` or `en`, not the current settings language |
| `recorded_at` | Record creation date, ISO 8601 in UTC, not send time |
| `duration_seconds` | Dictation milliseconds divided by 1,000, or voice-note duration; 0 when old dictation duration is unknown |
| `client` | `mumla/` followed by the running app's version |

Use structured JSON encoding and exactly one app-initiated POST with
`Content-Type: application/json` and `Authorization: Bearer <token>`.
Reject empty/whitespace-only transcripts and invalid nonfinite metadata locally;
never truncate `description`, substitute a summary, or send a whole history.
Validate the text-only input at construction; show a local validation error
before invoking the sender rather than inventing an HTTP status for bad input.

Inject a transport protocol implemented by a dedicated URLSession adapter. Use
an ephemeral session with no persistent cache, cookies, shared credential store,
background uploads, or waits-for-connectivity queue. Bound the whole attempt to
15 seconds, not only an idle read. Cancellation cancels the same task.

Disable every redirect, including redirects to another HTTPS address; return
its HTTP status without issuing another request. Do not handle authentication
challenges by submitting a credential elsewhere. Retain normal system TLS trust.
Do not log request/response bodies, credentials, destination paths or queries,
or raw error user-info that can contain them.

Return the requested typed outcomes:

- `sent(statusCode)`: any 2xx response.
- `unauthorized`: 401.
- `rejected(statusCode)`: all other HTTP statuses, including 3xx, 403 and 429.
- `network(error)`: sanitized typed transport failure, including timeout, offline,
  TLS failure, cancellation, and invalid response; no server body or raw URL.
- `notConfigured`: missing/invalid configuration or unavailable token; no POST.

There is no application retry, including on authentication errors or rate limits.
One accepted button action starts at most one application request. A timeout can
still mean the recipient committed the item before the response was lost. Do not
promise exactly-once server creation without a receiver idempotency contract;
that protocol extension is not part of v1.

### Send Metadata

Add optional `sentAt: Date?` to `DictationRecord` and `VoiceNote`. Old JSON must
decode with nil. Record it only after 2xx, using atomic store operations that
preserve the record's current text and all other metadata.

`sentAt` means the record was sent previously, not proof that its latest edited
text exists remotely. Preserve it through edits and label it as Last sent. Freeze
the exact text/configuration at the tap; if the text changes during the request,
the result must not imply the new version was transmitted. Never restore a
deleted record when a late success arrives. If the remote send succeeds but the
local receipt write fails, show that distinction and do not offer an automatic
retry or mark it as a failed remote send.

Keep `sentAt` omitted from `VoiceNote.transferData()` so old transfer bytes,
delivery IDs, duplicate-receive handling and acknowledgements remain unchanged.

## 3. Settings And Send UI

Reuse the tactile controls, retro typography, light/dark modes and localization.
Prefer shared destination settings and send/status views in `MumlaUI`, with
platform coordinators supplying persistence and feedback. A small app-owned send
controller owns in-flight state across views; closing a sheet must not allow a
second concurrent send of the same record.

### Settings

- Add Send destination to Mac `MainView` settings and iOS `MumlaSettingsSheet`.
- Provide name, address, a secure token field, Save, Test and Remove. Draft edits
  are not active configuration. Save validates locally and does not send.
- Test requires saved valid configuration and sends one short, clearly synthetic
  transcript through the same sender. It never reads the last real transcript,
  creates a history record, or silently retries. Display the destination name
  before the user presses Test and show the typed result afterward.
- Remove clears the address/name and its Keychain credential, immediately hiding
  Send actions after a successful removal. It does not remove transcripts or
  remote items. Explain any partial failure rather than claiming success.
- Disable configuration changes, Test and Remove while a send is in flight, so
  a new address cannot be swapped into an already-approved request.

### Transcript Actions

- Mac transcript detail in `MainView`: add Send to the named destination beside
  Share. Keep the current text/summary distinction; send the transcript only.
- Mac `StatusMenuController` history: keep existing click-to-paste rows working.
  Add a destination-named Send group with recent transcripts rather than
  replacing paste actions. Resolve record IDs against current history at tap.
- iOS `TranscriptSheet`: add the same action next to transcript Share.
- iOS `VoiceNoteSheet` in `VoiceNotes.swift`: add it beside Share text, never
  beside/inside Share recording and never with an audio attachment.
- Hide all Send actions if no valid saved destination exists. Show the name
  before sending; disable active Send controls while sending. No side effect
  occurs on view appearance, settings load, dictation completion, or reconnect.
- A record with `sentAt` requires a Send again confirmation with destination name
  and previous send time. Re-check current state after confirmation; a double tap
  or a second surface cannot bypass the in-flight guard. If the address changed
  during confirmation, require approval for the new destination before sending.
- Show Sending, Sent, or a short sanitized reason. A timeout/cancel-after-start
  says the recipient may have received it, so a manual retry may duplicate it.
- For menu-only sending, use a lightweight result surface anchored to the menu
  bar. Do not reuse the dictation/paste overlay, steal its recording state, or
  overwrite the clipboard. Normal paste, hotkeys and recording stay independent.
- On narrow iPhones, use a wrapped or separate action row rather than squeezing
  another fixed-width button into the already busy transcript toolbar. Keep the
  destination identifiable with long names, Dynamic Type and VoiceOver.

## 4. Implementation Order

1. Privacy documentation and final-bundle manifest coverage, with the PR rationale.
2. Core destination validation, Keychain adapter, text-only request sender, optional
   send metadata and backward-compatible persistence, with isolated tests.
3. Shared settings/send components, iOS settings ownership, both platform action
   paths, repeat-send confirmation and stable result handling.
4. Hosted Mac test target, native integration/UI checks, sandboxed networking
   verification, and an explicitly approved synthetic endpoint acceptance test.

Keep each change reviewable. Do not publish a release, change signing identity,
add a provider integration, or alter Watch/keyboard permissions as part of this
plan. The implementation PR must separate automated evidence, real endpoint
acceptance and any later release/upload status.

## 5. Verification Matrix

| Layer | Required Checks |
| --- | --- |
| Sender unit tests | Exact method/headers/JSON keys, full multiline Unicode text, 80-character single-line title, language/date/duration/version, no audio or internal IDs, 2xx/401/403/429/5xx/non-HTTP mapping |
| Network boundaries | HTTPS validation before transport, missing token, one request on timeout/error, no retry, redirect refused with no second request, cancellation, bounded timeout, no cookie/credential persistence |
| Token store | Save/read/replace/delete, isolated real-Keychain hosted tests, denial/error handling, endpoint change cannot reuse an old token, no credential in settings JSON or diagnostics |
| Persistence | Legacy settings/history/voice-note JSON without new fields, invalid destination preserves unrelated settings, atomic success marker, edits preserved, deletion cannot be resurrected, receipt-write failure distinguished from remote failure |
| Watch regression | Old transfer bytes and delivery ID unchanged by `sentAt`, duplicate receipt preserves phone-side send metadata, acknowledgements still succeed |
| UI | Send hidden without destination and visible with one, Test uses synthetic text only, no POST before tap, no POST on Save, double-tap guard, busy/result states, repeat-send confirmation and cancellation, remove hides actions |
| Native regression | Mac menu paste unchanged, clipboard/recording overlay untouched, iOS Share text/audio paths still distinct, long names/small window/Dynamic Type/light/dark/VoiceOver |

Normal tests use an injected in-memory transport or URLProtocol fixture, with
non-routable synthetic test hosts assembled in the fixture. They must not read a
real destination, use production Keychain items, or contact a network service.
Generate disposable test tokens in memory instead of committing token values.

Run `swift test`, existing release-helper tests, the new hosted Mac tests, and
the existing `MumlaIOSTests` and `MumlaUITests` on an available iOS Simulator.
Add the Mac hosted target and scheme wiring in `project.yml`, then regenerate
the project without unrelated version/signing changes. Test-host startup must
use isolated settings/history and a unique Keychain namespace, with microphone,
hotkey listeners, updater and Watch connectivity inactive.

Compile both Mac variants and the iOS app/keyboard/Watch targets. Inspect the
actual sandboxed Mac executable's entitlements and bundled privacy manifest;
an entitlement in a source plist alone is not a successful networking test.

## 6. Manual Acceptance And Done Gate

Use a user-controlled HTTPS test receiver configured interactively. Credentials
enter only the secure field/Keychain, never command-line arguments or committed
test configuration. Keep addresses, tokens and raw received text out of the PR.

1. Send one unique synthetic multiline transcript from the sandboxed Mac app.
   Read the receiver's stored item: exactly one new item, full text unchanged,
   expected metadata, and no audio. Repeat the same single-send acceptance on
   iOS Simulator, separately identifying its synthetic item.
2. Repeat a send only after the explicit repeat-send confirmation. Verify Cancel
   makes no request and rapid double taps create one application attempt.
3. Exercise rejected credentials, offline/timeout and redirect responses. Confirm
   no automatic retry, no redirect forwarding and clear uncertainty messaging.
4. Remove the destination, relaunch, and verify Send is hidden and its credential
   is absent. Existing transcript/audio sharing remains functional.
5. Check outgoing traffic: no request before an explicit Send/Test action, no
   developer relay, no audio body, and no content-bearing diagnostics. Keep
   unrelated model/update checks separate from this audit.

Done means the package and native tests pass, sandboxed Mac and iOS manual sends
are read back at the receiver, privacy documentation/manifest evidence matches
behavior, and the PR contains redacted verification results. Builds alone or an
HTTP status without receiver readback do not satisfy the full acceptance gate.

The test receiver and credential are implementation-time inputs; none is needed
to review this plan or run the normal isolated test suite.
