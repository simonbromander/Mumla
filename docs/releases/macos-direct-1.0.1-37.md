# Mumla for Mac 1.0.1 (37) - Local Text Beta

## New

- Optional on-device formatting in transcript details: preview punctuation,
  capitalization and paragraphs, accept explicitly, or restore the original.
- Optional Summary preview, saved separately from the transcript. Copy and
  share a saved summary without replacing or pasting over the original text.
- Settings > Text preferences: local formatting and summary style prompts,
  with Save, Cancel and Reset. Formatting still preserves every original word.
- Confirmed auto-pastes dismiss the floating bar. Readable editors with delayed
  acknowledgement get a brief observation-only recheck, never a duplicate paste.
- Menu-bar Paste Last Transcript and the ten newest Recent Transcripts.

## Requirements and Limitations

Formatting and summaries require macOS 26 and a compatible Mac with Apple
Intelligence enabled and ready. Dictation still supports macOS 14 or later.
There is no cloud fallback or additional downloaded text model. Formatting is
limited to 1,500 characters; summary input to 6,000. Nothing is silently truncated.

Review summary suggestions before accepting, especially names, dates, quantities
and commitments. Swedish summary quality is still experimental. These actions
do not run in the dictation hotkey path. Failed or unverifiable pastes retain
the manual Copy fallback. Unit tests do not prove physical cross-app behavior.

Swedish dictation only. Meetings, English ASR and iCloud sync are not implemented.

## Install

Use Check for Updates in the existing direct Mac app, or download the notarized
ZIP from this release, quit Mumla and replace the copy in Applications.
Keep Microphone, Input Monitoring and Accessibility permissions enabled.
Do not run the TestFlight and direct copies at the same time.

Please test hotkey release, clipboard restoration and bar dismissal in your
actual editor, then try Paste Last Transcript from the menu. This remains a beta.
