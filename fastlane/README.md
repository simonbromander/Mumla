fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta_notes

```sh
[bundle exec] fastlane ios beta_notes
```

Publish and verify localized testing notes for one explicitly selected build

### ios beta_status

```sh
[bundle exec] fastlane ios beta_status
```

Read-only TestFlight status for both platforms and the existing internal audience

### ios preflight

```sh
[bundle exec] fastlane ios preflight
```

Read-only release preflight: generate project, build simulator, verify ASC app record/signing context

### ios build

```sh
[bundle exec] fastlane ios build
```

Create a signed App Store/TestFlight IPA without uploading

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Upload an existing signed IPA to TestFlight

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios mac_preflight

```sh
[bundle exec] fastlane ios mac_preflight
```

Read-only macOS release preflight: generate project, build macOS release, verify ASC app record/signing context

### ios mac_build

```sh
[bundle exec] fastlane ios mac_build
```

Create a signed macOS App Store/TestFlight package without uploading

### ios mac_upload

```sh
[bundle exec] fastlane ios mac_upload
```

Upload an existing signed macOS package to TestFlight

### ios mac_beta

```sh
[bundle exec] fastlane ios mac_beta
```

Build and upload the macOS app to TestFlight

### ios mac_direct_build

```sh
[bundle exec] fastlane ios mac_direct_build
```

Create the full-capability Mac app signed with Developer ID, without publishing

### ios mac_direct_notarize

```sh
[bundle exec] fastlane ios mac_direct_notarize
```

Notarize and staple the existing direct Mac app, then produce an installable ZIP

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
