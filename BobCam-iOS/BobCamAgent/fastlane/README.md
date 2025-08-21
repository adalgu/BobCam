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

### ios build_debug

```sh
[bundle exec] fastlane ios build_debug
```

Build Debug version

### ios build_release

```sh
[bundle exec] fastlane ios build_release
```

Build Release version

### ios archive

```sh
[bundle exec] fastlane ios archive
```

Archive and create IPA

### ios test

```sh
[bundle exec] fastlane ios test
```

Run all tests

### ios test_unit

```sh
[bundle exec] fastlane ios test_unit
```

Run unit tests only

### ios test_ui

```sh
[bundle exec] fastlane ios test_ui
```

Run UI tests only

### ios lint

```sh
[bundle exec] fastlane ios lint
```

Run SwiftLint for code quality

### ios lint_fix

```sh
[bundle exec] fastlane ios lint_fix
```

Auto-fix SwiftLint violations

### ios coverage

```sh
[bundle exec] fastlane ios coverage
```

Generate code coverage report

### ios ci

```sh
[bundle exec] fastlane ios ci
```

Complete CI pipeline - Build, Test, and Quality checks

### ios cd

```sh
[bundle exec] fastlane ios cd
```

Continuous Deployment - Archive and prepare for distribution

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Release to App Store

### ios setup

```sh
[bundle exec] fastlane ios setup
```

Setup development environment

### ios clean

```sh
[bundle exec] fastlane ios clean
```

Clean build artifacts

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
