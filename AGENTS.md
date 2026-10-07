# Mumla Agent Notes

Mumla is being rebuilt from scratch from the 2026-09-24 PRD. The previous Mumla
implementation is reference material only. Preserve Apple identity, signing,
and App Store continuity where useful, but do not copy the old cloud transcription,
paywall, backend, or note-formatting architecture into this repo.

Product priorities, in order:

1. Privacy: no audio or text leaves the device except the user's own iCloud.
2. Swedish accuracy.
3. Simplicity.

Phase 0 comes first. Do not build broad UI before the Pianissimo CoreML quality,
latency, language-routing, and memory gates have been measured.

Public documentation and commits must not expose local account names,
home-directory paths, machine identifiers, or private repository details.
Use a public GitHub handle and GitHub-provided noreply commit email.
