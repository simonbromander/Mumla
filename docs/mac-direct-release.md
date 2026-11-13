# Full-Capability Mac Distribution

## Classic And Native Styles Beta: 2026-11-13

- Universal direct `1.0.1 (50)` is published as a prerelease in both repositories
  from `56476a2bbddaff70c597e487e0c9ca9ae199e6ab`. PR #16 was merged as
  `e012a89c685f158900756066520f29aee6015d04` after exact-source Contributor CI
  `43380212155` passed secret scanning, package/helper tests, iOS/Mac/Watch
  builds and Watch test compilation.
- Adds independent Classic/Native style and System/Light/Dark appearance.
  Classic stays the default. Native adapts navigation, shared controls and the
  non-activating recording overlay; older systems use material fallbacks.
  Style changes do not recreate recording services or change audio permissions,
  history or transcription preferences. DJI input is ignored during app updates,
  including when Secure Input is enabled; Secure Input remains protected.
- Local checks: 359 Swift tests, nine optional model/hardware skips, zero
  failures; 35 release-helper tests, 84 assertions; 22 hosted iOS Simulator tests
  and three Native-style UI tests passed. Mac UI tests compile but execution is
  not verified because UI Automation access was not granted.
- Apple notarization `e3d38287-2433-4a2a-82bc-753c5b24bace` was Accepted.
  Signing, hardened runtime, both architectures, entitlements, dSYMs, updater
  metadata, licenses, MLX kernels, stapled ticket and Gatekeeper passed on the
  app and a fresh ZIP extraction. Model weights, debug fixtures and unreleased
  cloud-summary interfaces are absent. Only the ZIP and checksum are published.
- ZIP size: 38,064,691 bytes. SHA-256:
  `ab355556f6558b8a06f301be2ef7e2165b955f6675e141eace16b726d7debdbe`.
  An anonymous download from the source repository matches. Signed staging and
  canonical live feed are byte-identical at feed commit `1ddb983`; anonymous
  enclosure/signature checks pass for builds 50, 49 and 48.
- Physical recording, keyboard handoff, haptics, older-system materials, privacy
  traffic auditing and live updater replacement remain acceptance checks.
  No production app was replaced and no existing recordings were opened.
- iOS 36 is separately uploaded and verified VALID / IN_BETA_TESTING in the
  existing internal groups. See the TestFlight runbook for its artifact audits
  and audience/notes verification. The initial membership-agreement gate cleared.
- The public website now links build 50 and retains the Rams identity with
  readable text, larger touch controls, semantic color tokens and responsive
  derivatives of the unchanged real captures. All 21 unit and 48 browser checks
  pass; live JS/CSS and images match the tested build. Sixteen live automated
  accessibility scans passed without violations. This update was published
  manually after the Git-connected Cloudflare publishing job failed; that job
  remains a separate unresolved hosting issue. No DNS settings were changed.
- Evidence is ignored under `.build/mac50-*` and `.build/ReleaseAuditMac50/`.
  [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-50).

## Meeting Speaker Alignment Beta: 2026-11-12

- Universal direct `1.0.1 (49)` is published as a prerelease in Mumla and
  Mumla-Releases from `a0df71b56083a53d14c02eb996baaf0acf6a0522` (PR #15,
  merged as `d50a3b0`). Available speaker lookahead, stable retry offsets and
  final/pause context draining fix reproduced word-to-speaker timing defects.
- Word-duration overlap replaces single-midpoint alignment. Uncertain or
  overlapping speech stays unassigned. The old "Them" source label is now
  "Unassigned remote", not another identified person. A branded per-passage
  selector can correct one passage without merging other people or changing
  text/timing. Existing recordings are not automatically relabelled.
- Local checks completed 355 tests with nine optional skips and zero failures;
  all 35 release-helper tests passed (84 assertions). Exact-source Contributor
  CI `43222025893` passed history secret scanning, package/helper tests,
  iOS/Mac/Watch builds and Watch test compilation. The Mac UI-test target
  compiled; isolated compact light/dark interaction checks passed. Automated
  native UI-runner execution remains unverified.
- Developer ID signing, hardened runtime, both architectures, matching dSYMs,
  microphone/Calendar entitlements, permission descriptions, updater metadata,
  speaker attribution and MLX kernels passed local and fresh public-download
  audits. Model weights, debug UI fixtures and the unreleased cloud-summary
  interface are absent. Only the notarized ZIP and checksum are release assets.
- Apple notarization `5928896a-4441-41d6-862f-cbd6d2b422a3` was Accepted.
  Stapling, ticket validation and Gatekeeper passed. ZIP size: 37,960,018 bytes.
  SHA-256: `1d83ee2c1de1d71fa0cb3d3233b92d05006dff83e5af699005dcf39759a1b274`.
- Feed commit `46e4548`; the canonical live feed is byte-identical to signed
  staging. Public archives and Ed25519 signatures for 49, 48 and 47 passed
  before and after publication. Update discovery is available; installation,
  relaunch and preservation of populated data remain target-Mac acceptance checks.
- Website commit `1b1be66` adds bilingual meeting features and correction guidance,
  an unchanged native sample-meeting screenshot with a verified provenance hash,
  and build-49 download links. Its 18 unit and 42 browser checks passed locally;
  production-worker preflight and the Git-connected production build passed.
  Live JavaScript, CSS, screenshot and capture manifest match the tested build
  byte for byte. No domain or hosting configuration changed.
- Website CI `43226470650` and `43226478383` passed for that exact website
  commit. The duplicate run initially exceeded the existing 30-second mobile
  screenshot-test budget; its rerun passed without code or timeout changes.
- Real group-call speaker quality, capture/routing, signed-app permissions,
  privacy traffic auditing and live updater replacement remain separate checks.
  This is an experimental beta, not a general speaker-accuracy guarantee.
  Dictation/capture scope, iOS, sandboxed Mac TestFlight, destination sending,
  CLI summaries and Native/Classic appearance are unchanged.
- Evidence remains ignored under `.build/direct49-*` and
  `.build/ReleaseAuditMac49-20261112/`. Existing user recordings were not opened
  or modified. [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-49).

## Meeting Recording Reliability Beta: 2026-11-12

- Universal direct `1.0.1 (48)` is published as a prerelease in Mumla and
  Mumla-Releases from `a34acfdebb764996007b67c832e43a00cfb44e8d` (PR #14).
- Small callbacks now fill bounded 100 ms batches instead of exhausting the
  capture pool during brief saving delays. Accepted audio drains after overload;
  converter input memory is kept separate and the resampler tail is flushed.
  Interrupted recordings retain a warning even after transcription or restart.
- Local checks completed 340 tests with nine optional skips and zero failures;
  all 35 release-helper tests passed (84 assertions). The exact release branch's
  accelerated two-hour writer check retained full duration on both tracks across
  4,800 bounded files and passed recovery in approximately 283 seconds. This is
  generated audio, not a real call or real-time ASR acceptance.
- Exact-source Contributor CI `43204840272` passed full-history secret scanning,
  package/helper tests, iOS/Mac/Watch builds and Watch test compilation. The Mac
  UI-test target compiled locally; actual native UI-test execution remains unverified.
- Developer ID signing, hardened runtime, arm64/x86_64, matching dSYMs, microphone
  and Calendar entitlements, permission descriptions, updater metadata, MLX kernels
  and speaker attribution passed local and fresh anonymous-download audits.
  Model weights, debug UI fixtures and the separate cloud-summary interface are absent.
- Apple notarization `84e81364-a429-4b9f-8886-ddd4bab374b9` was Accepted. Stapling,
  ticket validation and Gatekeeper passed. ZIP size: 37,920,883 bytes. SHA-256:
  `9e9fc59006f9d93c6339e48f27f36c811f3f4a219d210fd30b664b59c705f2a8`.
  Only the notarized ZIP and checksum are release assets in both repositories.
- Feed commit `2ae41b0`; the canonical live feed is byte-identical to signed
  staging. Public enclosures and Ed25519 signatures for 48, 47 and 46 passed
  before and after publication. Update discovery is available; actual replacement,
  relaunch and preservation of populated user data remain target-Mac checks.
- Website commit `c002986` updates the download links only. Its 17 unit and
  40 browser checks and production-worker preflight passed locally. The
  Git-connected production build succeeded; live JavaScript/CSS match the tested
  build byte for byte. No domain or hosting configuration changed.
- Real-call capture, permissions/routing, acoustic bleed, speaker quality, privacy
  traffic auditing and live installation remain separate acceptance gates. There
  is no 13-minute limit; the specific reported stop has not been attributed.
  Audio that was not captured after a real stop cannot be reconstructed.
- Evidence remains ignored under `.build/direct48-*` and
  `.build/ReleaseAuditMac48-20261112/`. Existing user recordings were not modified.
  Settings reorganization, CLI summaries, destination sending, Native/Classic
  appearance, iOS and sandboxed Mac TestFlight are not part of this release.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-48).

## System Audio Meetings Beta: 2026-11-12

- Universal direct `1.0.1 (47)` is published as a prerelease in Mumla and
  Mumla-Releases from `102b0c266f00af6824e40bf68183cf2fbe8de7f5`.
- Includes PR #13: System audio + microphone is the meeting default, including
  explicit Start from a Slack/Teams suggestion. Setup, the suggestion and the
  system permission description disclose other apps' audio. Selected-app and
  microphone-only choices remain, with no silent fallback to broader capture.
  Pause/resume retains scope; the system recording is not tied to one app's exit.
- Local checks completed 335 tests with nine optional model/hardware skips and
  zero failures. All 35 release-helper tests passed (84 assertions). Exact-source
  Contributor CI `43175933343` passed history secret scanning, package/helper
  tests, iOS/Mac/Watch builds and Watch test compilation.
- Developer ID signing, hardened runtime, arm64/x86_64, matching dSYMs,
  microphone plus Calendar entitlements, capture/calendar descriptions, pinned
  updater settings, MLX kernels and speaker attribution passed both local and
  fresh anonymous-download audits. Model weights and debug UI fixtures are absent.
- Notarization `2698ae9f-a442-4a7e-8a79-9d018f71b2ec` was Accepted. The stapled
  ticket and Gatekeeper passed. ZIP size: 37,911,833 bytes. SHA-256:
  `aca02a31d76f0ac723a9b0f49d4e445600eea4cde06c30275f84fca1f97463c0`.
  Anonymous ZIP/checksum downloads from both official repositories match staging.
- Feed commit `c7c1993`; after cache propagation the canonical live feed is
  byte-identical to signed staging. Public enclosures and Ed25519 signatures for
  47, 46 and 45 passed before and after publication. Update discovery is available;
  live app replacement/relaunch and populated-data preservation are separate checks.
- Website commit `3fadbe2` updates the download link and bilingual system-audio
  scope, consent and explicit Stop guidance. Its 17 unit and 40 browser checks,
  production-worker preflight, website CI and Git-connected Cloudflare build
  passed. Live JavaScript/CSS match the tested build byte for byte. No DNS or
  hosting configuration changed.
- The duplicate website push-CI run needed one rerun after the existing mobile
  text-example test exceeded its 30-second budget; the other CI run and local
  suite passed initially. The rerun passed without code or timeout changes.
- Real two-sided calls, signed-app permissions, routing, acoustic bleed, speaker
  quality and traffic auditing remain target-Mac acceptance gates. Silent fixtures
  and a compiled native UI-test target do not replace those checks. The production
  app installed on the user's Mac was not replaced by this release workflow.
- Evidence remains ignored under `.build/direct47-*` and
  `.build/ReleaseAuditMac47-20261112/`. Only ZIP/checksum are release assets.
  iOS, Mac TestFlight, destination sending and Native/Classic design are unchanged.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-47).

## Meeting Suggestions Beta: 2026-11-12

- Universal direct `1.0.1 (46)` is published as a prerelease in Mumla and
  Mumla-Releases from `2166ed0a0a111e09c4ede63c3ac6124dabdf91aa`.
- Includes the meeting layout/dialog improvements from PR #11 and opt-in
  Slack/Teams input-activity prompts from PR #12. Calendar titles are separately
  opt-in. Detection does not record; capture still requires an explicit Start.
  Destination sending (PR #10), iOS and sandboxed Mac TestFlight are unchanged.
- Local checks completed 326 tests with nine optional model/hardware skips and
  zero failures. All 35 release-helper tests passed (84 assertions). Exact-source
  Contributor CI `43162378765` passed full-history secret scanning, package/helper
  tests, iOS/Mac/Watch builds and Watch test compilation.
- Developer ID signature, hardened runtime, arm64/x86_64, matching dSYMs,
  microphone plus Calendar entitlements, all three permission descriptions,
  updater metadata, MLX kernels and speaker attribution passed local and fresh
  anonymous-download audits. Debug UI fixtures and model weights are not bundled.
- Notarization `b98c0565-5400-423d-9d1c-62523d937d36` was Accepted. The stapled
  ticket and Gatekeeper passed. ZIP size: 37,907,670 bytes. SHA-256:
  `69c7de975ffc1ce68111eb32f92dfdc92855a608c0febbcd344776785626032b`.
  Anonymous ZIP/checksum downloads from both official repositories match staging.
- Feed commit `83a7a4a`; the live feed is byte-identical to signed staging.
  Anonymous enclosure downloads and Ed25519 signatures for 46, 45 and 44 passed
  before and after publication. In-app update discovery is available; live
  replacement/relaunch and populated-data preservation remain separate checks.
- Website commit `536fc67` updates the download and bilingual meeting/Calendar
  guidance. Its 17 unit and 40 browser checks passed locally. The Git-connected
  production worker build succeeded; live JavaScript/CSS match the tested build
  byte for byte. No DNS or hosting configuration was changed.
- Real Slack/Teams calls, Calendar grant/denial/revocation, screen lock,
  full-screen placement, idle cost, audio/speaker quality and privacy traffic
  auditing remain target-Mac acceptance gates. Native UI-test execution is still
  blocked by local UI Automation authorization; silent fixtures and passing
  build-for-testing do not replace real-call acceptance. This remains experimental.
- Evidence remains ignored under `.build/direct46-*` and
  `.build/ReleaseAuditMac46-20261112/`. Only ZIP/checksum are release assets.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-46).

## Experimental Live Meetings Beta: 2026-11-11

- Universal direct `1.0.1 (45)` is published as a prerelease in Mumla and
  Mumla-Releases from `ddc7ca03673ad622c128e857dbef90170efb8de7`.
- Adds explicit meeting-app/microphone capture, live local Swedish transcription,
  optional speaker separation, transcript correction/search/playback/export,
  pause/resume and recoverable disk-backed recording. Meetings require Apple
  silicon and macOS 14.2+. Existing Intel dictation remains supported.
- This is experimental: actual call capture, permissions, clock drift, speaker
  accuracy, privacy traffic auditing and live installation still need target-Mac
  acceptance. Synthetic speech and two-hour writer tests are not real-call QA.
- The local suite completed 306 tests with nine opt-in skips and no failures;
  all 35 release-helper tests passed. Exact-source Contributor CI `43085579941`
  passed secret scanning, package/helper tests, iOS/Mac/Watch builds and Watch
  test compilation. FluidAudio is pinned to the tested 0.17.3 in both resolvers.
- Developer ID signature, hardened runtime, arm64/x86_64, matching dSYMs,
  microphone-only entitlements, both capture descriptions, speaker attribution,
  updater metadata, MLX kernels and absence of model weights passed local and
  fresh anonymous-download audits.
- Notarization `cdfd4da3-42b4-485c-9ea6-9073ad4d412a` was Accepted. Stapled ticket
  and Gatekeeper checks passed. ZIP size: 37,674,117 bytes. SHA-256:
  `fe8ea201c09823d19151a82e554271fa3b13f4d360fe38e4e77a12a185c86929`.
  Anonymous ZIPs from both repositories match staging.
- Feed commit `47ec308`; the live feed matches signed staging byte for byte.
  Anonymous downloads and Ed25519 signatures for 45, 44 and 43 passed again after
  publication. Update discovery is available; live replacement/relaunch and
  populated-data preservation are separate acceptance checks.
- Website commit `5b93302` updates download links and bilingual meeting/permission
  notes. Its 17 unit and 40 browser checks passed; the Git-connected production
  worker build succeeded. No DNS or hosting configuration was changed.
- Evidence remains ignored under `.build/direct45-*` and
  `.build/ReleaseAuditMac45-20261111/`. Only ZIP/checksum are release assets.
  No destination-sending feature, iOS update or Mac TestFlight upload is included.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-45).

## Tiny Dictation And Text Models Beta: 2026-11-06

- Universal direct `1.0.1 (44)` is published as a prerelease in Mumla and
  Mumla-Releases, from `8fe64a35631e5537cc0570334f39f7b4d6bc63aa`.
- Minimal recording is a translucent, click-through 104 x 30 point REC/timer
  capsule without waveform or transport buttons. Full Recorder and readable
  copy fallback remain available. Confirmed pastes still dismiss the overlay.
- Mac Settings offers Qwen or Apple's local model, with availability/language
  checks and no silent provider fallback. Formatting supports word-preserving
  bullets/numbered lists and accurately reports unchanged output. Summaries
  remain separate previews; automatic formatting remains off by default.
- 283 shared/Mac tests completed with zero failures and seven opt-in skips;
  all 35 release-helper tests passed with 84 assertions. Exact-source
  Contributor CI `42237910229` passed secret scanning, package/helper tests,
  iOS/Mac/Watch builds and Watch test compilation.
- Real pinned-Qwen evaluation passed four list preferences, eight prose cases
  and a summary. This is synthetic evidence, not a general quality guarantee.
  Apple model quality and target-Mac microphone/paste acceptance remain separate.
- arm64/x86_64, matching dSYMs, hardened runtime, microphone-only entitlements,
  pinned updater metadata, MLX Metal kernels and absence of model weights were
  verified locally and from a freshly extracted anonymous public download.
- Apple notarization `fe5851e9-4e6a-4e54-99e5-0ee017dc053b` was Accepted.
  Stapled ticket, Gatekeeper and ZIP-integrity checks passed.
- ZIP: 37,202,981 bytes. SHA-256:
  `32c118a31c9f687eadd5d7846eb073adc784c31b2e3974a8ab86f3d0f6cb1290`.
  Both official repositories' anonymous ZIP/checksum downloads match staging.
- Feed commit `00b5113`; the live feed matches signed staging byte for byte.
  Public enclosure lengths and Ed25519 signatures for 44, 43 and 42 passed
  before and after publication. No feed URL, signing key or update policy changed.
- The website's build-44 download/setup update is deployed from `cca6195`.
  Its 17 unit and 38 browser checks passed; live JS/CSS match the local build.
- Evidence: `.build/direct44-build.log`, `.build/direct44-notarize.log`,
  `.build/direct44-source-ci.json`, `.build/direct44-local-audit.json`,
  `.build/direct44-public-audit.json`, `.build/direct44-feed-prepare.json` and
  `.build/direct44-live-public-verify.json`. dSYMs and fresh public downloads
  are retained in `.build/ReleaseAuditMac44-20261106/`, not published as assets.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-44).
  Installation/relaunch and populated-data preservation need target-Mac acceptance.
  No iOS or sandboxed Mac TestFlight upload was performed by this release.

## Minimal Dictation And Local Formatting Beta: 2026-11-06

- Universal direct `1.0.1 (43)` is published as a prerelease in Mumla and
  Mumla-Releases, from `b2849fd1da2e90c036247fcbdd57af3f9dbf4380`.
- Adds default-off local formatting before auto-paste using saved Text
  preferences, plus Recorder / Minimal overlay choices. The original is saved
  before formatting; cancellation never pastes late output. Rejected, failed or
  unavailable generation falls back to the original with a visible outcome.
- Removes repeated startup accessibility/device-list work and shortens the
  overlay appearance animation. The 250 ms hold guard is unchanged. Qwen checks
  pinned files before loading rather than before every use of its loaded model.
  Hardware latency and live model quality remain unmeasured on the target Mac.
- 269 shared/Mac tests completed with zero failures and five opt-in live checks
  skipped. All 35 release-helper tests passed with 84 assertions. Contributor
  CI passed for the exact release source, including full-history secret scanning,
  shared/helper tests and native iOS, Mac and Watch build checks.
- Developer ID signature, hardened runtime, arm64/x86_64, matching dSYMs,
  microphone-only entitlements, pinned updater metadata and MLX Metal kernels
  verified. Downloaded model weights are not bundled.
- Apple notarization `8229012c-1b59-4413-9f6a-c9ace1a6830b` was Accepted.
  Stapled ticket and Gatekeeper checks passed for the local app and a freshly
  extracted anonymous public download. ZIP integrity passed.
- ZIP: 37,192,056 bytes. SHA-256:
  `1404826f0455772e0dde7db2454a6e747c65bd1b1c370b28a33fb8dd7d1a62b3`.
  Anonymous downloads and checksum assets from both official repositories match.
- Feed commit `e5d844c`. The live feed is byte-identical to signed staging;
  anonymous downloads and Ed25519 signatures for builds 43, 42 and 41 passed
  before and after feed publication. Installation/relaunch, populated-data
  preservation and physical dictation/paste remain target-Mac acceptance checks.
- Evidence: `.build/direct43-build.log`, `.build/direct43-notarize.log`,
  `.build/direct43-swift-tests.log`, `.build/direct43-source-ci.json`,
  `.build/direct43-local-audit.json`, `.build/direct43-public-audit.json`,
  `.build/direct43-feed-prepare.json`, `.build/direct43-public-verify.json`
  and `.build/direct43-live-public-verify.json`. Anonymous ZIPs and dSYMs are
  retained in `.build/ReleaseAuditMac43-20261106/`. Internal logs and signing
  material were not published. iOS and sandboxed Mac TestFlight are unchanged.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-43).

## DJI Mic Button Beta: 2026-10-28

- Universal direct `1.0.1 (42)` is published as a prerelease in Mumla and
  Mumla-Releases, from `062cc5b3889915a5684a30412c5e26eb97a9f835`.
- Includes optional native DJI Mic Mini USB receiver button control and the
  branded waveform/record-button menu-bar icon from PR #9. DJI control is off
  by default and needs Input Monitoring. Microphone selection remains separate.
  The listener handles duplicate reports, pairing holds, permission denial,
  helper conflicts, sleep and receiver removal; existing dictation and paste
  protections remain in place.
- 256 shared/Mac tests completed with zero failures and four opt-in model
  tests skipped; all 35 release-helper tests passed with 84 assertions. The
  iOS Release Simulator preflight and signed Mac archive/export passed.
- arm64/x86_64, Developer ID signature, hardened runtime, matching dSYMs,
  microphone-only entitlements, updater metadata and MLX Metal library verified.
  Model weights are downloaded separately, not bundled in the release.
- Apple notarization `5d18d683-1313-4574-ae8f-3fc457922e38` was Accepted.
  The stapled app passed Gatekeeper. A fresh anonymous public ZIP passed the
  same signature, ticket, Gatekeeper and binary checks; ZIP integrity passed.
- ZIP: 37,143,617 bytes. SHA-256:
  `c226cfe39ca057e03d558bfd57f3f07bd03863da7d9d7b881c0fa8e8ac04367b`.
  Both official repositories contain matching ZIP and checksum assets.
- Feed commit `4ea6e3a`. The live feed is byte-identical to signed staging;
  public downloads and Ed25519 signatures for 42, 41 and 40 passed before and
  after publication. Real DJI button/audio routing, cross-app paste, live updater
  installation and model quality still require hardware acceptance.
- Evidence: `.build/direct42-build.log`, `.build/direct42-notarize.log`,
  `.build/direct42-local-audit.json`, `.build/direct42-public-audit.json`,
  `.build/direct42-feed-prepare.json`, `.build/direct42-public-verify.json`
  and `.build/direct42-live-public-verify.json`.
  dSYMs and the anonymous ZIP are retained in
  `.build/ReleaseAuditMac42-20261028/`. No private logs or signing material were
  published. iOS/Watch build 35 is a separate TestFlight release.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-42).

## Local Qwen And Compact Controls Beta: 2026-10-20

- Universal direct `1.0.1 (41)` is published as a prerelease in Mumla and
  Mumla-Releases, from `5d420373424ec2e53974e9e91fc4853057011423`.
- Includes optional Qwen3.5 4B formatting/summaries through MLX on Apple silicon,
  context-guided formatting previews, compact glass controls and the pinned
  microphone Bluetooth fix from @ehsanYazdani's PR #6. The optional 3.1 GB text
  model is downloaded separately; it is not bundled. Intel dictation remains
  supported, without Qwen generation. Review generated suggestions before use.
- 242 shared/Mac tests completed with zero failures and four opt-in model
  tests skipped; 35 release-helper tests passed with 84 assertions. Contributor
  CI passed for this release source, including full-history secret scanning,
  package/helper tests and native builds. These are not model-quality gates.
- arm64/x86_64, Developer ID signature, hardened runtime, matching dSYMs,
  microphone-only entitlements, pinned updater metadata, MLX Metal library and
  bundled runtime licenses verified. No sandbox/debug entitlement or model
  weights were added to the download.
- Apple notarization `e20563a3-51b9-4b70-b7b7-53e01dd500bd` was Accepted.
  The stapled app passed Gatekeeper and ZIP integrity checks. A fresh anonymous
  download passed signature, ticket, Gatekeeper and checksum verification.
- ZIP: 37,081,738 bytes. SHA-256:
  `ac586fa485d18fe84a7f1fa49a6793605871e79ffe3e74f4c3ba9777e7cc8ed8`.
  Both official repositories contain the ZIP and checksum. A timed-out upload
  was recovered through a temporary asset name, then renamed before updating
  the feed. No feed URL or enclosure-host policy was changed.
- Feed commit `a4642fa`. The live feed is byte-identical to the signed staging
  file; anonymous downloads and Ed25519 signatures for 41, 40 and 39 passed
  before and after publication. Live installation/relaunch, actual Bluetooth
  routing, cross-app paste and Swedish/Qwen quality remain acceptance checks.
- Evidence: `.build/direct41-build-final.log`, `.build/direct41-notarize.log`,
  `.build/DirectMac/build-audit-41.json`, `.build/direct41-public-audit.json`,
  `.build/direct41-public-verify-final.json` and
  `.build/direct41-live-public-verify.json`. No internal logs or signing
  material were published.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-41).
  iOS/Watch build 34 is a separate TestFlight upload; no sandboxed Mac
  TestFlight upload was made by this direct release.

## Microphone And Reliability Beta: 2026-10-14

- Universal direct `1.0.1 (40)` is published as a GitHub prerelease in Mumla
  and Mumla-Releases, from `41dd32da5c2d38ce72ce996da98270f4965247ed`.
- Includes @ehsanYazdani's merged PRs #3, #4 and #5: keep the main window
  alive after closing it to prevent reopen crashes; remember a dictation
  microphone without changing the system default; explain trigger presses
  blocked by Secure Input while leaving recording and protected fields blocked.
- A disconnected or unavailable pinned microphone falls back to the system
  default. A remembered device can be matched on reconnection by UID or a
  unique display name. Physical routing, disconnect/reconnect and actual
  Secure Input event delivery still require target-hardware acceptance.
- Retains build 39's Chromium paste confirmation and build 38's optional
  silent clipboard fallback. Model inference is unchanged. Local formatting
  and summary quality remains experimental.
- 209 shared/Mac tests completed with zero failures and one opt-in live-model
  skip; all 31 release-helper tests passed. Contributor CI's full-history
  secret scan, package/helper tests and unsigned native builds passed for
  the release source. These checks are not physical dictation acceptance.
- arm64/x86_64, Developer ID signature, hardened runtime and microphone-only
  entitlements verified. Apple notarization
  `49f22cc0-d6f0-4e70-a73d-6d63b335ebd3` was Accepted. The ticket was stapled;
  a fresh anonymous public-ZIP extraction passed code signature, ticket and
  Gatekeeper checks. ZIP integrity passed. No sandbox or debugger entitlement.
- ZIP size: 23,262,081 bytes. SHA-256:
  `29c49ec62be36539f7a67180c362d0c9f7a49a76021a477637d178c6bb37fde2`.
  The anonymous download and public checksum matched the staged archive.
- Feed commit `1343416`; public downloads and Ed25519 signatures passed before
  publication. The live feed is byte-identical to staging, and all enclosures
  (40, 39, 38) passed public verification. Live update installation/relaunch
  and populated-data preservation remain separate acceptance checks.
- Local evidence: `.build/direct40-build.log`, `.build/direct40-notarize.log`,
  `.build/direct40-swift-tests.log`, `.build/direct40-release-helper-tests.log`,
  `.build/direct40-feed-prepare.json`, `.build/direct40-public-verify.json`,
  `.build/direct40-live-public-verify.json` and
  `.build/DirectMac/build-audit-40.json`. Only the notarized ZIP and checksum
  were uploaded as release assets.
- [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-40).
  No iOS or sandboxed Mac TestFlight upload was performed by this release.

## Chromium Paste Confirmation Beta: 2026-10-12

- Universal direct `1.0.1 (39)` is published as a GitHub prerelease in Mumla
  and Mumla-Releases, from `7fdec0f24d522c9832eafdf03387dfd377a598af`.
  This source includes @ehsanYazdani's merged
  [PR #2](https://github.com/simonbromander/Mumla/pull/2), which was not in build 38.
- Confirms complete text insertion into empty Chromium/Electron editors whose
  Accessibility baseline is newline-only, including normalized line endings.
  Confirmed pastes dismiss the bottom bar and restore the prior clipboard.
  Partial, unchanged and unrelated text are still rejected. Existing focus,
  secure-input, permission and newer-clipboard guards remain in place.
- Includes build 38's optional silent clipboard fallback. No recording,
  transcription, hotkey or model behavior changed. Local formatting and
  summary quality remains experimental.
- 201 shared/Mac tests completed with zero failures and one opt-in live-model
  skip; all 31 release-helper tests passed. Contributor CI's full-history
  secret scan, package/helper tests and unsigned native builds passed for the
  release source. These checks are not physical target-app acceptance.
- arm64/x86_64, Developer ID signature, hardened runtime and microphone-only
  entitlements verified. Apple notarization
  `18dbb5eb-b367-4019-b243-edd8d41e803f` was Accepted. The ticket was stapled;
  a fresh anonymous public-ZIP extraction passed code signature, ticket and
  Gatekeeper checks. ZIP integrity also passed. No sandbox or debugger entitlement.
- ZIP size: 23,214,128 bytes. SHA-256:
  `731dcae4cb0aed8d24b29a82c96cb06b14a8c5953d5c246dc6296a2ea1464fbb`.
  The anonymous download and public checksum matched the local staged archive.
- Feed commit `d7441a6`; public downloads and Ed25519 signatures passed before
  feed publication. The live feed is byte-identical to staging, and all
  enclosures (39, 38, 37) passed public verification. Live update installation,
  relaunch and physical dictation/paste remain separate acceptance checks.
- Evidence is local in `.build/direct39-build.log`,
  `.build/direct39-notarize.log`, `.build/direct39-swift-tests.log`,
  `.build/direct39-release-helper-tests.log`, `.build/direct39-feed-prepare.json`,
  `.build/direct39-public-verify.json`, `.build/direct39-live-public-verify.json`
  and `.build/DirectMac/build-audit-39.json`. Only the notarized ZIP and checksum
  were uploaded as release assets.
- [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-39).
  No iOS or sandboxed Mac TestFlight upload was performed by this release.

## Silent Clipboard Fallback Beta: 2026-10-12

- Universal direct `1.0.1 (38)` is published as a GitHub prerelease in Mumla
  and Mumla-Releases, from `f214d6318c39ec31f271d262c44bce2bea152e2a`.
- Adds Mac Settings > Show Copy dialog. Switching it off copies failed,
  blocked or unverified pastes to the clipboard and hides the recorder, with
  no transcript/copy dialog. Newer user copies are protected; if copying is
  unavailable, History and menu-bar status remain the recovery path.
- Existing users keep the dialog-enabled default. Switching it off also handles
  an already-open fallback. Confirmed pastes still restore the clipboard. No
  automatic paste retry, microphone, hotkey or model change was added.
- 200 shared/Mac tests completed with zero failures and one opt-in live-model
  skip; all 31 release-helper tests passed. Unit tests are not real target-app
  acceptance. Existing formatting and summary quality remains experimental.
- arm64/x86_64, Developer ID signature, hardened runtime and microphone-only
  entitlements verified. Apple notarization
  `260603b3-50a0-460f-b54c-aad0c2b0c65e` was Accepted. The ticket was stapled;
  a fresh final-ZIP extraction passed code signature, ticket and Gatekeeper
  checks. ZIP integrity also passed. No sandbox or debugger entitlement.
- ZIP size: 23,213,886 bytes. SHA-256:
  `39a35adbd1e6bd7f2ff75a29665eadc5e30900ab3508500b9c1d6fba72b157f7`.
- Feed commit `9443180`; public downloads and Ed25519 signatures passed before
  publication. The live feed is byte-identical to staging, and all enclosures
  (38, 37, 36) passed public verification. In-app installation/relaunch and
  physical dictation/paste remain separate acceptance checks.
- Evidence is local in `.build/direct38-build.log`,
  `.build/direct38-notarize.log`, `.build/direct38-swift-tests.log`,
  `.build/direct38-release-helper-tests.log`, `.build/direct38-feed-prepare.json`,
  `.build/direct38-public-verify.json` and `.build/direct38-live-public-verify.json`.
  Only the notarized ZIP and checksum were uploaded as release assets.
- [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-38).
  No iOS or sandboxed Mac TestFlight upload was performed by this release.

## Local Text Beta: 2026-10-08

- Universal direct `1.0.1 (37)` is published as a GitHub prerelease in Mumla
  and Mumla-Releases. App source is `8cdfff858e50fa12b1e3f451a57e931c957febfa`;
  the iOS-only final text-wrapping adjustment does not change this Mac binary.
- Adds optional local formatting and separate summary previews, editable style
  preferences, delayed paste acknowledgement dismissal, Paste Last Transcript
  and the ten most recent transcripts. Generation never runs in the hotkey path.
- 190 shared/Mac tests completed, zero failures, one live-model test skipped.
  All 31 release-helper tests passed. Real target-app acceptance and Swedish
  model output quality are separate, still-pending checks.
- Developer ID signature, arm64/x86_64, hardened runtime and microphone-only
  entitlements verified. Notarization
  `6986cd27-3629-442c-9153-ec8469834676` was Accepted; ticket stapled and
  validated, Gatekeeper passed. No App Sandbox or debugger entitlement.
- ZIP size: 23,202,334 bytes. SHA-256:
  `ce523361eae99668c7caa4e776b586e6844d9acff8b7df9741e2208fc39fbf4a`.
- Public anonymous ZIP downloads and Ed25519 signatures passed before feed
  publication. Feed commit `4a6f11f`; the live feed is byte-identical to the
  verified staging feed and all enclosures (37, 36, 35) passed signature checks.
  Live in-app installation/relaunch is not claimed by these checks.
- Local evidence: `.build/direct37-build.log`, `.build/direct37-notarize.log`,
  `.build/direct37-feed-prepare.json`, `.build/direct37-public-verify.json` and
  `.build/direct37-live-public-verify.json`. No logs or signing material published.
- [Download and testing notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-37).
  iOS build 32 is a separate TestFlight beta; sandboxed Mac TestFlight remains 29.

## Why It Is Separate

The dictation workflow inspects the focused field in another app, sends Cmd+V,
and checks whether that field changed. The ordinary Mac App Store/TestFlight
sandbox does not support this unrestricted Accessibility workflow.
[Apple DTS explains the restriction](https://developer.apple.com/forums/thread/780626).

`MumlaMac` remains the sandboxed App Store/TestFlight scheme. `MumlaMacDirect`
uses the `Direct` configuration: hardened runtime, microphone entitlement,
Developer ID Application signing, no App Sandbox. Both retain `com.mumla.app`.
The direct build currently stores data locally; CloudKit sync is not implemented
in this MVP and its unused restricted entitlements are not added to this build.

## Auto-Paste Behavior

- Capture the editable target before recording and showing the nonactivating pill.
- Reject secure input, disabled fields, and fields explicitly marked read-only.
  Browser/Electron fields do not need Accessibility value setters to accept paste.
- Accept focused group/web-area editors only when explicitly marked editable.
  Read text through the Accessibility text-range API when `AXValue` is absent;
  reject ranges larger than one million characters and recheck focus/security.
- Wait up to 300 ms for physical modifiers to release before reading the field
  or staging the clipboard. Cancel safely if focus, permission or secure input
  changes, or the insertion task is cancelled.
- Stage the transcript on the clipboard, then send one PID-targeted Cmd+V using
  a private event source, only while the original field remains focused.
- Poll for up to 800 ms for the expected field update instead of checking once
  after 200 ms. An editor without a cursor range, or with a stale collapsed
  range, can confirm an exact insertion with the rest of its text unchanged.
  Normalize line endings only; selection replacements still require the exact
  expected update. A changed/opaque field is not assumed to be a successful paste.
- Restore every original clipboard item/type after success or failure, unless
  the user copied something newer. No clipboard write occurs before validation.
  If the clipboard changes after staging but before dispatch, cancel rather
  than paste the user's newer clipboard contents into the destination.
- On confirmed insertion, dismiss the pill without a transcript/copy dialog.
  By default a blocked or unconfirmed paste retains the transcript in the pill,
  and copying requires pressing Copy. Switching off Mac Settings > Show Copy
  dialog enables silent clipboard fallback instead: copy and hide the recorder
  when possible, while preserving newer user copies. Otherwise retain the
  transcript in History and show the failure in menu-bar status, not a dialog.
  Never retry an unconfirmed paste because the first attempt may have landed.
- Save every dictation in history before attempting insertion.
- Copied keyboard diagnostics include `Paste: <outcome>` to distinguish target,
  permission, modifier, dispatch and verification failures without collecting
  field content, transcript text or application titles.

## Existing Data

If the direct app already has data, it uses that store. Otherwise it adopts
Mumla's existing TestFlight container in place, including history, dictionary,
settings, models, and resumable downloads. Nothing is overwritten or moved and
large models are not duplicated. Do not run the two variants simultaneously.

## Build and Notarize

An account holder must create/install a Developer ID Application certificate
with its private key on the build Mac. Keep that key local and out of Git.
[Apple's certificate instructions](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/).

```bash
security find-identity -v -p codesigning
ruby fastlane/tests/direct_signing_test.rb
swift test
fastlane ios mac_direct_build build:32
fastlane ios mac_direct_notarize
```

The build lane uses an already-installed, unexpired Developer ID Application
identity for this team, selected by certificate fingerprint. It never requests
or creates certificates through Apple's API and does not require App Store
Connect access. Importing a `.cer` without its matching private key is not
enough; use a CSR generated on the build Mac or import a password-protected
`.p12` containing the certificate and its key. Keep all signing material local.

The notarization lane reads the same `ASC_KEY_ID`, `ASC_ISSUER_ID`, and
`ASC_KEY_PATH` used by the existing release workflow. The lanes do not upload
to TestFlight or publish a download. The build lane verifies this team's
Developer ID signature and the absence of sandboxing. The notarization lane
requires `Accepted`, staples and validates the ticket, checks Gatekeeper, and
repackages the stapled app as:

`.build/DirectMac/Mumla-1.0.1-32.zip`

Quit the TestFlight app before replacing it with the direct app. Launch the
direct app and grant Microphone, Input Monitoring, and Accessibility access in
System Settings. Input Monitoring is for the global dictation key; Accessibility
is for inspecting the destination field and confirming a paste. After switching
between TestFlight and Developer ID copies, check the installed app's permission
entries and quit/reopen Mumla if macOS requests it.
Do not disable Gatekeeper or instruct testers to bypass signing checks.

## Verification Snapshot: 2026-09-30

- 65 core/Mac tests passed, including delayed/failed paste, safe clipboard
  restoration, newer user clipboard copies, secure input, focus changes,
  successful-pill dismissal, and existing-data adoption.
- The unsigned `Direct` verification build compiled for arm64 and x86_64;
  version `1.0.1 (28)`, bundle `com.mumla.app`, distribution marker `direct`.
- Developer ID certificate creation was rejected by Apple: `This operation can
  only be performed by the Account Holder`. No signed/notarized build 28 is
  available yet; do not label an unsigned verification build distributable.
- The local test process reports Accessibility trust and event-posting access
  as false. Unit tests exercise a simulated editor; they do not establish live
  cross-app acceptance.

## Signing Preparation: 2026-10-01

- Direct build 30 is reserved; Mac TestFlight build 29 and iOS are unchanged.
- 10 signing-selection tests and all 67 Swift tests passed. Signing tests cover
  missing private-key identities, the wrong certificate type/team, validity
  dates, and deterministic selection of a usable local identity.
- The supplied Developer ID Application certificate is valid for this team,
  but its public key does not match the CSR/private key generated on this Mac.
  Importing the certificate did not create a usable codesigning identity.
- The actual build lane stops at its local signing preflight with an actionable
  missing-private-key error, before archiving or contacting Apple's API. Create
  a certificate from the supplied CSR or import a matching `.p12` as a file.
- No signed/notarized build 30 or GitHub release has been produced. Real
  auto-paste acceptance remains unverified; passing tests do not resolve that.

## Direct Beta: 2026-10-05

- The Account Holder supplied a G2 Developer ID Application certificate created
  from this build Mac's CSR. Its matching private key and certificate were
  verified and imported locally. No signing keys or passwords enter Git.
- Universal `1.0.1 (30)` was archived and exported for arm64 and x86_64, minimum
  macOS 14.0, bundle `com.mumla.app`, distribution marker `direct`.
- The exported app has this team's Developer ID signature, hardened runtime,
  and a secure timestamp. Its only entitlement is microphone access: no App
  Sandbox, debugger, app-group, or unused CloudKit entitlements.
- All 67 Swift tests and 10 signing-selection tests passed again.
- Apple notarization `94da0777-b974-43e2-9dca-51d9acb086b1` was `Accepted`.
  The ticket was stapled and validated; Gatekeeper reports
  `source=Notarized Developer ID`.
- The final ZIP was unpacked into a fresh verification directory. Its code
  signature, stapled ticket, Gatekeeper acceptance, and ZIP integrity were
  independently verified. Size: 22,539,868 bytes.
- SHA-256: `9002fa5d58480d087de290bae884ee4eceaee508aae7f952a734a746a3bbf531`.
- App source is `b80915118dcb265d2fc7cdf9e3148a8a6f4f5d6d`; the tracked Xcode
  project is regenerated from its existing `project.yml` to synchronize the
  Direct build number. No transcription or insertion behavior changed here.
- GitHub prerelease tag: `macos-1.0.1-30`. Only the notarized ZIP and its checksum
  are release assets. The repository remains private; download requires access.
  [Installation and beta notes](releases/macos-direct-1.0.1-30.md).
- Local evidence: `.build/DirectMac/build-audit-30.json`,
  `.build/direct30-build-20261005.log`,
  `.build/direct30-notarize-20261005.log`, and
  `.build/direct30-swift-tests-20261005.log`.
- Signing/distribution verification is complete. Cross-app paste acceptance is
  still pending, so this is a beta, not a verified stable auto-paste release.
  Mac TestFlight build 29 and iOS are unchanged.

## Runtime Acceptance Before Stable Release

With the signed direct app installed and permission granted, verify release of
the selected hold key in a blank TextEdit document and in the actual target app.
Check selection replacement, Swedish characters, slow browser editors, no
transcript dialog after success, and restoration of rich clipboard contents.
Then try no focused text field, revoked permission, and a secure field: no
insertion and a persistent manual-copy pill for a completed transcript. Ensure
the pill never steals focus and each attempt is saved in history exactly once.

## Hotkey Recovery

- The keyboard listener reports active, missing Input Monitoring permission,
  or unavailable instead of silently ignoring an event-tap installation failure.
- Settings and the menu bar offer a permission/retry action. Permission requests
  occur only after a user action; normal startup does not explicitly request one.
- Retry the listener when the foreground app changes or Mumla becomes active,
  including after returning from System Settings. A healthy listener is reused;
  a disabled or invalid listener is recovered without losing the saved key.
- Cancelling or stopping a listener resets pending holds and double-tap state.
  Secure input still blocks recording, and other keys cancel Ctrl shortcuts.
- There is no idle polling timer or change to transcription/paste behavior.
- 84 Swift tests passed, including 17 new monitor/coordinator regression tests.
  Real key events and cross-app paste on the installed signed build still need
  acceptance on the target Mac; simulated tests do not establish TCC access.

## Hotkey Recovery Beta: 2026-10-05

- Universal `1.0.1 (31)` was built from
  `5f3b31e5bfc390c05c7e6e379b442c3b9f201b48`; transcription and insertion behavior
  is unchanged. Input Monitoring is now an explicit permission/recovery path.
- 84 Swift tests and 10 signing tests passed. The compact Settings layout was
  rendered and visually inspected with the existing tactile design.
- Apple notarization `47a95225-a3eb-4c20-9098-526f53a35279` was accepted. The ticket
  was stapled and validated; the repacked ZIP was freshly extracted and checked
  for signature, ticket, Gatekeeper, ZIP integrity, and build identity.
- ZIP size: 22,552,826 bytes. SHA-256:
  `4b0b6e0f62ebb2d7e22d6bed5b0950bc659d0ff0c61a50f05f4bc2513fa98e91`.
- Private GitHub prerelease tag: `macos-1.0.1-31`, with only the notarized ZIP and
  its checksum. [Installation and testing notes](releases/macos-direct-1.0.1-31.md).
- Local evidence: `.build/DirectMac/build-audit-31.json`,
  `.build/direct31-build.log`, `.build/direct31-notarize.log`,
  `.build/hotkey-fix-focused-tests.log`, and `.build/hotkey-fix-all-tests.log`.
- Signing and packaging passed; live hotkey/TCC and paste acceptance on the
  installed target Mac remain pending. Mac TestFlight build 29 and iOS are
  unchanged; this does not claim sandboxed cross-app paste support.

## Background Hotkey Follow-Up

- Build 31 could count Accessibility trust as keyboard-listening permission
  and mark a successfully created port as ready without checking its actual
  global event mask. A port may still be valid after disallowed keyboard events
  are removed. [Apple's event-tap documentation](<https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)>).
- Build 32 requires `CGPreflightListenEventAccess()` explicitly, validates the
  exact newly installed tap ID and every requested event, and rejects app-local
  or partially permitted listeners. Manual retry forces a fresh installation.
- The one-shot hold timer is registered in the main run loop's common modes;
  the app delegate/listener lifetime is explicitly kept across `NSApplication.run`.
- All 94 Swift tests and 10 signing tests passed. Tests include native timer
  execution with the app inactive in default mode, menu tracking, partial/local
  mask rejection, and refusal to install a partial tap on this permission-denied
  test host. These checks still do not prove hardware input on the target Mac.
- No idle polling, microphone/security bypass, or text-insertion changes were
  added. [Installation and menu-closed acceptance](releases/macos-direct-1.0.1-32.md).

## Background Hotkey Beta: 2026-10-05

- Universal `1.0.1 (32)` was built from
  `ef74bc814cca2a8c0ce71c2fe240b08df9c80476` and signed with the existing
  Developer ID identity. App identity and microphone-only entitlements remain
  unchanged; Mac TestFlight and iOS were not uploaded or modified.
- Apple notarization `2d084a26-ed50-41ce-89ff-8bfea9773356` accepted; ticket
  stapled/validated and Gatekeeper passed. A fresh ZIP extraction was independently
  checked for signature, ticket, integrity, and version/bundle identity.
- ZIP size: 22,559,864 bytes. SHA-256:
  `0f70f56dd63f18080174bee09a0ae66ee2842f2793d0ccf146091510eca9547e`.
- Private GitHub prerelease tag: `macos-1.0.1-32`, with the notarized ZIP and
  checksum only. The installed target Mac still needs the menu-closed check;
  local tests and successful distribution are not proof of hardware input.
- Local evidence: `.build/DirectMac/build-audit-32.json`,
  `.build/direct32-build.log`, `.build/direct32-notarize.log`,
  `.build/hotkey-background-focused-tests.log`, and
  `.build/hotkey-background-all-tests.log`.

## Updater and Focused Hotkey Build: 2026-10-05

- Direct `1.0.1 (35)` was built from
  `62957a1aa07297f7540f7169f2cc11038028bb85`; bundle and team are unchanged.
  It adds direct Settings routing, a focused-app listener, trigger diagnostics,
  early hold-timer recovery, and the direct-only signed updater.
- All 113 Swift tests passed. The compact Settings rendering was inspected.
  Signing tests passed with 12 tests/13 assertions; feed policy tests passed
  with 6 tests/18 assertions. Simulated tests are not hardware acceptance.
- Apple notarization `5c6c9c0b-ea83-4f2e-92ef-7b060c5304e8` was accepted.
  The ticket was stapled and validated, and Gatekeeper accepted the app.
- The notarized ZIP SHA-256 is
  `abc20636f67947f4212425f893c9dc18992d6c4bd19e2651b7b63985aa0043c9`.
- The current sandboxed `MumlaMac` source also compiled for both architectures.
  Its binary has no Sparkle dependency or updater feed metadata. Its unchanged
  build number 29 is a local compile check, not a new TestFlight upload.
- Build 35 is a prerelease in both the private source repository and the public
  downloads-only `Mumla-Releases` repository. Only the notarized ZIP and checksum
  are assets. Public Git contains README and the signed appcast, not app source.
- Feed signing completed after an initial Keychain wait. The update key remains
  in the local Keychain. Anonymous ZIP download and Ed25519 verification passed
  before feed publication. The live feed is byte-identical to the signed staging
  feed; live feed signature and enclosure verification also passed.
- Public feed commit: `a4cf0da`. ZIP size: 23,594,069 bytes.
  [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-35).
- Live update/replacement/relaunch testing is blocked by pending Computer Use
  permissions. Hardware hotkey, cross-app paste, and preservation of populated
  user data remain unverified. The build host's local stores were empty.
- Evidence: `.build/direct35-build.log`, `.build/direct35-notarize.log`,
  `.build/DirectMac/notarization35.json`, `.build/hotkey-local-tests.log`,
  `.build/hotkey35-app-store-build.log`, and `.build/hotkey-settings-compact.png`.
- [Store compatibility and the proposed paste-only experiment](mac-app-store-compatibility.md).

## Rams Appearance Beta: 2026-10-05

- Universal direct 1.0.1 (36) was archived from source
  `d0bc0eb64940c6466a31cf9f05f831a8ea38cdd9`. It adds persistent System / Light /
  Dark choices, a menu-bar Appearance submenu and the new Rams-inspired icon.
  It does not change hotkey, recording or paste behavior.
- The exported app retains `com.mumla.app`, team `PF2PWR4YG4`, macOS 14 minimum,
  arm64/x86_64, hardened runtime and microphone-only entitlements. No sandbox,
  debugger or unused CloudKit/App Group entitlements were added.
- All 132 core/Mac tests and 31 release-helper tests passed. Native appearance
  mapping, persistence, override reset and primary text contrast were checked.
- Apple notarization `edde0dcd-00f6-4d60-9482-edb8b05eaa22` was Accepted.
  Stapling, ticket validation and Gatekeeper acceptance passed.
- ZIP size: 22,949,303 bytes. SHA-256:
  `3b8471e9c3c275c9640f3bde343a9f64d3e0965a0535e1841589fbbfe1bd52ea`.
- Published prerelease `macos-1.0.1-36` in the private source repository and
  public downloads-only repository. Anonymous download and Ed25519 verification
  passed for both feed enclosures (36 and 35) before publishing the new feed.
- Feed commit: `0a2b424`. The live feed is byte-identical to the verified staging
  feed, and its signature passed verification. Existing direct build 35 can
  discover it through Check for Updates; live installation/relaunch remains
  unverified while this Mac is locked.
- [Download and installation notes](https://github.com/simonbromander/Mumla-Releases/releases/tag/macos-1.0.1-36).
- iOS and Mac TestFlight were not uploaded by this direct release. iOS 28 is
  waiting on keyboard App Group membership; Mac TestFlight remains build 29.
- Evidence: `.build/DirectMac/build-audit-36.json`, `.build/direct36-build.log`,
  `.build/direct36-notarize.log`, `.build/direct36-feed-prepare.json`,
  `.build/direct36-public-verify.json` and `.build/direct36-live-appcast.xml`.

## Auto-Paste Reliability Source Update: 2026-10-07

- Added support for explicitly editable group/web-area inputs and the public
  Accessibility text-range API fallback. Read-only terminal output is not
  treated as an editable input merely because it is a text area.
- Added physical-modifier release checks before field reads, clipboard staging
  and dispatch. Focus/security/cancellation failures do not trigger a retry.
- Paste verification tolerates stale collapsed cursor ranges and CRLF/LF
  conversion while still requiring one exact insertion or selection replacement.
  Posting an event alone does not dismiss the fallback pill.
- Regression tests reproduced the target-classification and verification gaps
  before the implementation changed. The expanded tests cover clipboard
  preservation, cancellation, focus changes, secure input and opaque targets.
- All 155 Swift package tests passed, including 33 focused Mac paste/clipboard/
  transcript-pill tests. No physical cross-app result is inferred from mocks.
- The universal unsigned Mac compile check succeeded. Live Claude Code acceptance
  is still pending: the testing Mac is locked and the user's Claude Code host
  (terminal, VS Code or desktop) has not yet been identified.
- This is a source update, not a new signed/notarized download. Existing GitHub
  build 36 does not acquire these changes until a new direct release is published.
