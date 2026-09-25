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

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
