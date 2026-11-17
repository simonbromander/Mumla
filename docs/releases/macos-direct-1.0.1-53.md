# Mumla for Mac 1.0.1 (53) - Meeting Start Recovery Beta

## Improved

- A disconnected or reconnected preferred microphone no longer leaves meeting
  recording trying to use an old device identifier. Mumla resolves connected
  microphones and uses the system default when the preferred one is absent.
- Failed starts keep your title and recording choices available for retry,
  instead of opening an empty interrupted meeting. Any partial audio or
  recovery files are retained; only a provably empty failed attempt is removed.
- Microphone and computer-audio startup errors identify the failing input and
  retain its error code, with a link to the relevant permission settings.
- Recording setup focuses on the title, audio source, microphone and Start.
  Session options are expandable; calendar detection and the speaker model
  have a separate, themed Meeting preferences panel.
- Cancelling a pending start prevents a late permission response from starting
  recording. Returning to the library does not stop an active recording.

System audio + microphone remains the default. App-only and microphone-only
recording remain explicit choices; an unavailable app never silently switches
to recording all computer audio. Existing recordings are not rewritten.

## Install And Test

Choose Check for Updates in the direct Mac app, or quit Mumla and replace it
with the downloaded notarized app. Avoid running multiple Mumla copies at once.

Open Meetings, choose New meeting, leave Record on System audio + microphone,
and choose System default or a connected microphone. Headphones are not required
to start recording, although they can reduce audio leaking into the microphone.
With everyone's consent, check that a short call records both sides and that
Stop saves one meeting in the library. If starting fails, retain the error code,
check the indicated permission, and retry without recreating the meeting.

The Swift suite executes 381 tests with nine existing optional model/hardware
skips and no failures. Both Mac app targets and the UI-test target compile.
Isolated synthetic UI checks cover Classic/Native, light/dark, source and
microphone selection, an immediate failure, retry, pause/resume and stop.
Automated Mac click tests could not initialize local UI Automation.

The exact reported Slack error and real-call hardware acceptance remain
unverified. These fixes address reproduced startup and recovery defects, not
a guarantee for every audio device or Slack configuration. Privacy traffic
auditing and updater installation/relaunch remain target-Mac acceptance checks.
This is not a new iOS or sandboxed Mac TestFlight build.
