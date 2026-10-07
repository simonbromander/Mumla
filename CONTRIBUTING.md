# Contributing To Mumla

Thanks for helping build a private, Swedish-first dictation tool. Our priorities
are privacy, Swedish accuracy, and simplicity, in that order.

## Getting Started

1. Read the [README](README.md), [development guide](docs/development.md), and
   [design system](docs/design-system.md).
2. Check existing issues. Discuss larger architecture, model, dependency, or
   permission changes in an issue before implementing them.
3. Fork the repository, create a branch, and keep the change focused.
4. Add regression tests and run the checks below. Open a PR explaining the
   behavior changed, what you tested, and what still needs physical-device testing.

No release credentials, paid account, private audio dataset, or CLA are required
to contribute. Contributions are accepted under the project's MIT license;
third-party notices must be retained. Follow the [code of conduct](CODE_OF_CONDUCT.md).

## Checks

```bash
swift test
ruby -e 'Dir.glob("fastlane/tests/*_test.rb").sort.each { |path| require File.expand_path(path) }'
```

For iOS changes, build the Simulator app and run relevant hosted/UI tests using
the development guide. For Mac changes, build the appropriate native target.
For UI changes, attach screenshots of the actual app, covering light/dark,
compact phone/iPad or Mac window sizes, and relevant accessibility states.
Do not substitute generated mockups for app screenshots.

Automated tests do not prove real global hotkey delivery, cross-app paste,
background microphone capture, physical haptics, or on-device model performance.
Report those checks separately, with hardware, OS, app version, and limitations.

CI runs package tests, release-helper unit tests, unsigned native builds, and a
full-history secret scan. It does not sign, notarize, upload, download speech
models, or use private recordings. A maintainer may need to approve a first-time
contributor's CI run.

## Engineering And Product Boundaries

- Prefer existing Swift/SwiftUI patterns and shared packages. Avoid unrelated refactors.
- Keep audio, transcripts, and dictionary contents local. Do not add telemetry,
  cloud transcription, automatic uploads, or external crash reporting.
- Never read secure/password fields or bypass Secure Input, sandboxing, or permissions.
- Preserve clipboard contents and newer clipboard writes. Save results before insertion;
  never retry an unconfirmed paste automatically.
- Keep the iOS microphone in the containing app and use supported extension APIs.
- Preserve model checksums, attribution, dependency notices, and reproducible revisions.
- Respect VoiceOver, Dynamic Type, contrast, Reduce Motion, and Swedish/English UI.
- Keep production bundle IDs, App Groups, iCloud containers, release numbers,
  updater configuration, and signing settings unchanged unless agreed with a maintainer.

## Privacy And Security

Never commit certificates/private keys, provisioning profiles, passwords, tokens,
model caches, device backups, real transcripts, or private recordings. Use synthetic
fixtures and redact diagnostics/screenshots. Do not attach full crash logs without
checking paths, identifiers, and user content.

Use portable, repository-relative paths in documentation. Remove local account
names, machine identifiers, and private repository details from shared logs and
screenshots. Before committing, configure this checkout with your public GitHub
username and a GitHub-provided noreply email address; see
[GitHub's commit email instructions](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address).
Use repository-local Git settings so other projects keep their own identity.

With [Gitleaks](https://github.com/gitleaks/gitleaks) installed:

```bash
gitleaks git --log-opts='--all' --ignore-gitleaks-allow --redact .
```

Do not add broad scanner exclusions. The existing exception matches only five
verified public model revision hashes in one documentation file. A secret already
committed is still exposed in history even after deleting it from the latest file.
Report accidental exposure privately using [SECURITY.md](SECURITY.md).

## Useful Contribution Areas

Accessibility and localization, deterministic keyboard/session tests, target-editor
paste compatibility, hotkey diagnostics, and consented Swedish evaluation are good
places to start. Planned English routing, meetings, and sync need design discussion
and evidence before changing the app's privacy or permission boundaries.
