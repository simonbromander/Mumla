# `kb-ios` Reference Notes

Reference repo: `https://github.com/simonbromander/kb-ios`

Local reference clone: `/Users/bob/projects/_references/kb-ios`

Observed on 2026-09-24:

- GitHub repo is private, Swift, default branch `main`.
- Latest inspected commit: `ec4d07e` (`Add idle recording screenshot, iPad/Watch screenshots, fix ASC submission`).
- Old app display name was already `Mumla`.
- App Store identifier: `com.mumla.app`.
- App group: `group.com.mumla.app`.
- iCloud container: `iCloud.com.mumla.app`.
- Developer team: `PF2PWR4YG4`.
- Old version was iOS/watch/widgets/broadcast-heavy with cloud transcription
  through Modal, StoreKit quota, Sign in with Apple, and AI formatting presets.

What carries forward:

- Apple identity and release metadata where compatible.
- Lessons from existing tests and App Store setup.

What does not carry forward:

- Cloud ASR backend.
- Modal dependencies.
- StoreKit quota/paywall.
- Sign-in requirement.
- Watch/widgets/CarPlay/broadcast surface area for Phase 1.
- KBWhisper naming.

Additional reference repos cloned on 2026-09-24:

- `/Users/bob/projects/_references/pianissimo-cli`, commit `4ac8e19`, for Klang's
  local/offline Pianissimo CLI flow.
- `/Users/bob/projects/_references/pianissimo-examples`, commit `1b41b76`, for
  Klang's minimal offline NeMo example and audio-format notes.
