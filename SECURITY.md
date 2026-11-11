# Security Policy

## Report Privately

Please report security or privacy vulnerabilities through
[GitHub private vulnerability reporting](https://github.com/simonbromander/Mumla/security/advisories/new).
Do not disclose vulnerabilities, credentials, private audio, or transcripts in
public issues or pull requests.

Include the affected version/distribution, OS, reproduction steps using synthetic
content, impact, and any proposed fix. A minimal redacted example is preferable
to a device backup or a full user-data export. Do not test against other people's
devices or data.

If GitHub's private reporting form is unavailable, ask the maintainer
[@simonbromander](https://github.com/simonbromander) to arrange a private channel,
without publishing sensitive details.

## Supported Versions

Mumla is currently in beta. Fixes target the current `main` branch and the latest
official build for each platform/distribution. Older betas are not maintained
as separate security branches; use the latest build when reporting a problem.
There is no guaranteed response-time SLA or bug-bounty program.

## Security Boundaries

- Speech inference is on-device; model downloads are pinned and checksum-verified.
- Destination Send permits one transcript and recording metadata to leave the
  device only after an explicit user action, directly to a configured HTTPS
  address. It never uploads audio, a whole history, or a background queue.
- Tokens belong only in the containing app's local Keychain: no settings,
  UserDefaults, keyboard access group, logs, screenshots or repository values.
  Redirects and application retries are prohibited; normal TLS trust remains.
- Neither the developer nor an integrated service partner receives exported
  content through a relay or telemetry. Recipient-side storage is controlled by
  the user and their chosen recipient, not by Mumla.
- Existing explicit system Share/export actions and paired Watch-to-iPhone audio
  transfers remain permitted. Do not infer that destination sending can export
  audio or run from the Watch or keyboard extension. iCloud sync is not implemented.
- Keyboard communication uses the local App Group; microphone capture belongs
  to an explicitly started session in the containing app.
- Secure input and password fields must not be read or recorded.
- Direct Mac builds require explicit OS permissions. App Store sandbox restrictions
  are not bypassed.
- Signing keys, update-signing keys, provisioning profiles, and release API
  credentials are maintainer-only and must never enter Git or contributor CI.

Permission bypasses, unintended recording, transcript exposure, cross-app insertion
into the wrong target, and unverified model/update loading are particularly useful
reports. General bugs belong in the normal issue tracker.
