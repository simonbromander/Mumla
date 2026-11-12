# Meeting suggestions on Mac

## Scope

Opt-in suggestions for Slack huddles and Microsoft Teams calls in the direct Mac
build (macOS 14.2+, Apple Silicon). Core Audio input-activity properties are read;
no audio tap or microphone recording is created for detection. Activity is a hint:
voice messages and microphone checks can also trigger a suggestion. Browser calls,
calendar-only reminders, automatic recording and automatic stopping are not part
of this change.

The non-activating prompt offers Start and Not now. Only Start calls the existing
meeting recorder, with the detected app selected. Existing microphone/system-audio
permissions still apply. Dismissing, expiring, switching off, locking or sleeping
never starts recording. Suggestions are suppressed while Mumla is busy.

Two seconds of input activity are required. A suggestion expires after one minute;
the same call is not suggested again until input activity has been absent for at
least 30 seconds. Short mute/reconnect transitions do not re-arm the prompt.
Some apps retain input access while muted, or do not expose it until unmuted.

Calendar context is separately opt-in. EventKit full access is required by macOS
even though Mumla only reads events; Mumla never creates or edits calendar events.
Only an ongoing or imminent event with a matching Slack/Teams meeting link can
supply a suggested title. Calendar access is not required for call detection.
No event identifiers, attendees, notes or meeting links are saved or logged. A
suggested title is saved with the meeting only after the user chooses Start.
No detection or calendar data is sent to a server. No analytics is added.
`PrivacyInfo.xcprivacy` continues to declare no developer-collected data: the
process activity and optional calendar lookup stay on the user's Mac. The direct
build adds the Calendar permission description and entitlement, not a remote API.

## Implementation and checks

- Observe Core Audio process-list and matching process input-state changes.
  Observe app lifecycle and sleep/session changes; remove listeners when disabled.
- Test debounce, helper ownership, mute gaps, dismissal, expiry, busy states,
  stale prompts, explicit consent, calendar matching and old settings decoding.
- Compile the direct app and native UI-test host; inspect light/dark prompt and
  settings snapshots without accessing a real microphone or calendar.
- Real Slack and Teams calls, permission grant/denial/revocation, screen lock,
  full-screen calls and idle CPU remain manual acceptance gates. Synthetic tests
  do not prove those work on the user's installed apps.

## API references

- Apple Core Audio: `kAudioHardwarePropertyProcessObjectList`,
  `kAudioProcessPropertyIsRunningInput`, `kAudioProcessPropertyPID`,
  `kAudioProcessPropertyBundleID` (also documented in the SDK's AudioHardware.h).
  [Input activity](https://developer.apple.com/documentation/coreaudio/kaudioprocesspropertyisrunninginput).
- Apple EventKit: `requestFullAccessToEvents()`,
  `NSCalendarsFullAccessUsageDescription`, and the calendars entitlement.
  [Calendar access levels](https://developer.apple.com/documentation/technotes/tn3153-adopting-api-changes-for-eventkit-in-ios-macos-and-watchos).

## Verification (2026-11-11, unreleased)

- `swift test`: 326 tests, 9 existing optional model/hardware skips, zero failures.
  Includes live native HAL observation start/stop without capture, policy/consent
  checks, legacy settings decoding and panel sizing/focus checks.
- Direct Mac Debug build and `MumlaMeetingsUI` build-for-testing passed.
  Automated UI execution remains blocked by local UI Automation authorization;
  compiling the UI target is not a passing UI test run.
- Actual SwiftUI light/dark prompt snapshots, long titles and Settings inspected.
  Manual click-through in the isolated UI host verified Start -> silent fixture
  recording -> Stop/save, and Not now -> zero meeting records. These fixtures use
  no microphone, calendar events, model downloads or network.
- Real Slack/Teams calls, Calendar permission grant/denial/revocation, screen lock,
  full-screen placement and idle-cost measurement remain unverified. No production
  build, update feed or installed app has been replaced by this work.

## Release Status (2026-11-12)

Included in experimental direct Mac `1.0.1 (46)` after exact-source CI, Developer
ID signing, notarization and anonymous download/feed verification. The real-call,
permission and hardware gates above remain outstanding; distribution verification
is not a claim of meeting-detection accuracy. See
[release notes](releases/macos-direct-1.0.1-46.md).
