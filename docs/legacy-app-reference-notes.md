# Legacy App Reference Notes

The previous Mumla implementation was reviewed on 2026-09-24 solely for
Apple identity and release continuity. Private repository locations and internal
commit details are intentionally omitted from this public documentation.

Preserved public app identity:

- App display name: `Mumla`.
- App Store identifier: `com.mumla.app`.
- App group: `group.com.mumla.app`.
- iCloud container: `iCloud.com.mumla.app`.
- Developer team: `PF2PWR4YG4`.

What carries forward:

- Apple identity and release metadata where compatible.
- Lessons from existing tests and App Store setup.

What does not carry forward:

- Cloud ASR backend.
- StoreKit quota/paywall.
- Sign-in requirement.
- Watch/widgets/CarPlay/broadcast surface area for Phase 1.

Public reference code reviewed on 2026-09-24:

- Klang's `pianissimo-cli`, commit `4ac8e19`, for the
  local/offline Pianissimo CLI flow.
- Klang's `pianissimo-examples`, commit `1b41b76`, for
  Klang's minimal offline NeMo example and audio-format notes.
