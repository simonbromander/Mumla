# Mumla for Mac 1.0.1 (51) - Meeting Library Beta

## Changed

- Meetings now opens on a dated library instead of recording setup. Each row is
  one complete meeting, with its title, time, duration, state and text preview.
- Search locally across meeting titles, transcript text, sources and speaker
  names. Open a result with one click and return without losing your search.
- Wide windows keep the meeting list beside the transcript. Compact windows
  give the document its full available width and a clear All meetings button.
- Copy transcript and Export stay above the transcript. They always include the
  complete meeting, even when the visible passages are filtered. Export supports
  plain text, Markdown and JSON.
- New meeting opens recording setup explicitly. Browsing saved meetings does not
  stop a recording; Current meeting returns to its live controls.

Classic and Native styles are both supported. Existing recordings, dictionary,
settings, downloaded models and on-device transcription are unchanged. No cloud
provider, new data-sharing behavior or audio-capture permissions are added.

## Install And Test

Choose Check for Updates in the direct Mac app, or quit Mumla and replace it with
the downloaded notarized app. Avoid running multiple Mumla copies at once.

Open Meetings, search for a title or a word spoken near the end of a meeting,
and open the result. Try Copy transcript while searching within the document:
the clipboard should still contain every passage. Check export and going back
to the same search results. Try both styles at compact and wide window sizes.

The Swift suite executes 365 tests with nine existing optional model/hardware
skips and no failures. The Mac app and UI-test runner compile, and isolated
synthetic interaction checks cover search, open/back, copy feedback, export
choices and browsing during recording in both appearances and styles. Automated
Mac UI-runner execution remains unverified because UI Automation permission was
not granted. No production recordings were used or changed during verification.

Real-call audio quality, capture permissions/routing, privacy traffic auditing
and live updater replacement remain target-Mac acceptance checks. Meetings
remain an experimental beta requiring Apple silicon, macOS 14.2 or later and
participants' consent. This is not a new iOS or sandboxed Mac TestFlight build.
