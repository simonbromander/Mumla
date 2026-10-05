# In-App Mac Updates

## Scope

Add manual, signed updates to the Developer ID Mac app using Sparkle 2.10.0.
The sandboxed Mac App Store/TestFlight target and iOS do not embed Sparkle.
Keep `com.mumla.app`, the signing team, existing data, permissions, and models.
Do not change transcription, hotkeys, or paste behavior.

The source repository stays private. The separate public
`simonbromander/Mumla-Releases` repository contains only a signed appcast,
installation notes, and signed/notarized app downloads. No source, credentials,
models, recordings, transcripts, or internal build logs are published.

## Implementation

1. Give the direct app its own Xcode target sharing existing Mac sources, with
   Sparkle linked only there. Pin the framework version.
2. Store the Ed25519 update key in the build Mac's Keychain under
   `com.mumla.app`; embed only its public key. Require signed feeds and archive
   verification before extraction; use HTTPS. No system profiling, silent
   installs, or background update requests by default.
3. Add localized Check for Updates actions in the menu and tactile Settings.
   Use Sparkle's standard installer UI and signature validation rather than
   implementing a downloader or replacing a running app ourselves.
4. Disable checks during active work; defer a selected installation until
   microphone permission/start, recording, transcription, paste/clipboard
   restoration, and model installation finish. Block new work once installation
   is committed. Cancel termination while existing work is outstanding.
5. Publish the ZIP before its signed feed entry. Provide a reusable feed builder
   that checks bundle identity, direct distribution, signing, notarization,
   increasing build numbers, feed URL/key, and public download checksums.

## Acceptance

- Unit-test configuration rejection, work tracking, deferred installation,
  cancellation, and no second install callback.
- Run all existing Swift and signing tests; build the App Store target and
  inspect it for absence of Sparkle and updater metadata.
- Archive, notarize, staple, and verify two universal direct builds; use the
  first to exercise real download, signature verification, replacement, and
  relaunch to the second from the public feed.
- Verify anonymous feed/download access, signatures, checksums, repository
  visibility, and preservation of local history/dictionary/settings/models.
- The first updater-enabled version still requires one manual installation.
  Real hardware hotkey and target-app paste acceptance remain separate.

## Release Maintenance

The feed URL is
`https://raw.githubusercontent.com/simonbromander/Mumla-Releases/main/appcast.xml`.
Build and notarize using the existing direct lanes, then follow the publishing
procedure below once release verification is complete. Keep the update private
key in the local Keychain and backed up securely outside Git; losing it requires
Sparkle's documented key rotation procedure.
