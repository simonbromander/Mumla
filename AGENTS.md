# Mumla Agent Notes

Mumla is being rebuilt from scratch from the 2026-09-24 PRD. The previous Mumla
implementation is reference material only. Preserve Apple identity, signing,
and App Store continuity where useful, but do not copy the old cloud transcription,
paywall, backend, or note-formatting architecture into this repo.

Product priorities, in order:

1. Privacy: audio stays on-device, except existing paired Watch-to-iPhone transfers
   and explicit user-requested sharing. Text leaves the device only through the
   user's own iCloud, an explicit system Share/export action, or one transcript
   sent by the user to a destination they configured. Destination Send never
   sends audio.
2. Swedish accuracy.
3. Simplicity.

Phase 0 comes first. Do not build broad UI before the Pianissimo CoreML quality,
latency, language-routing, and memory gates have been measured.

Public documentation and commits must not expose local account names,
home-directory paths, machine identifiers, or private repository details.
Use a public GitHub handle and GitHub-provided noreply commit email.
