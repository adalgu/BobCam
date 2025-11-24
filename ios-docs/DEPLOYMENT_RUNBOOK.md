# BobCam iOS Deployment Runbook

## Table of Contents
1. [Quick Start Guide](#quick-start-guide)
2. [Environment Setup](#environment-setup)
3. [Fastlane Lanes Reference](#fastlane-lanes-reference)
4. [CI/CD Pipeline](#cicd-pipeline)
5. [Troubleshooting](#troubleshooting)
6. [Production Deployment](#production-deployment)
7. [Rollback Procedures](#rollback-procedures)

## Quick Start Guide

### Prerequisites Checklist
- [ ] Xcode 15.0+ installed
- [ ] iOS 17.0+ simulator/device
- [ ] Apple Developer Account (for distribution)
- [ ] Git repository access
- [ ] Ruby 2.7+ and Bundler

### First-Time Setup
```bash
# 1. Clone and navigate to project
cd BobCam-iOS/BobCamAgent

# 2. Install dependencies
bundle install

# 3. Setup development environment
fastlane ios setup

# 4. Validate configuration
./scripts/validate-fastlane.sh

# 5. Test basic build
fastlane ios build_debug
```

### Daily Development Workflow
```bash
# Build and test cycle
fastlane ios ci              # Full CI pipeline
fastlane ios test            # Run tests only
fastlane ios build_debug     # Debug build for testing
```

## Environment Setup

### Development Environment
```bash
# Required tools installation
# 1. Install Xcode from App Store
# 2. Install Xcode Command Line Tools
xcode-select --install

# 3. Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 4. Install Ruby and Bundler
brew install ruby
gem install bundler

# 5. Install project dependencies
bundle install

# 6. Setup CocoaPods (if Podfile exists)
pod install
```

### CI/CD Environment
```bash
# GitHub Actions / CI environment setup
# See .github/workflows/ios-ci.yml for full configuration

# Required secrets in GitHub:
# - APPLE_ID: Apple Developer Account email
# - APPLE_PASSWORD: App-specific password  
# - MATCH_PASSWORD: Password for certificate storage
# - FASTLANE_SESSION: Session for 2FA bypass
```

### Production Environment
```bash
# App Store deployment requirements
# 1. Apple Developer Program membership
# 2. Distribution certificate and provisioning profile
# 3. App Store Connect access
# 4. Configured match for code signing
```

## Fastlane Lanes Reference

### Build Lanes

#### `fastlane ios build_debug`
**Purpose**: Build Debug version for development and testing
**Environment**: Requires Xcode
**Output**: Built app in derived data
**Usage**:
```bash
fastlane ios build_debug
```

#### `fastlane ios build_release`
**Purpose**: Build Release version with optimizations
**Environment**: Requires Xcode
**Output**: Built app in derived data
**Usage**:
```bash
fastlane ios build_release
```

#### `fastlane ios archive`
**Purpose**: Create IPA for distribution
**Environment**: Requires Xcode + Distribution Certificate
**Output**: IPA file in `./fastlane/builds/`
**Usage**:
```bash
fastlane ios archive
```

### Test Lanes

#### `fastlane ios test`
**Purpose**: Run comprehensive test suite
**Environment**: Requires Xcode + iOS Simulator
**Output**: Test results in `./fastlane/test_output/`
**Coverage**: Code coverage report generated
**Usage**:
```bash
fastlane ios test
```

#### `fastlane ios test_unit`
**Purpose**: Run unit tests only (faster execution)
**Environment**: Requires Xcode + iOS Simulator
**Output**: Unit test results only
**Usage**:
```bash
fastlane ios test_unit
```

#### `fastlane ios test_ui`
**Purpose**: Run UI tests only
**Environment**: Requires Xcode + iOS Simulator
**Output**: UI test results
**Usage**:
```bash
fastlane ios test_ui
```

### Quality Assurance Lanes

#### `fastlane ios lint`
**Purpose**: Run SwiftLint for code quality analysis
**Environment**: Requires SwiftLint installation
**Output**: Lint report with violations
**Usage**:
```bash
fastlane ios lint
```

#### `fastlane ios lint_fix`
**Purpose**: Auto-fix SwiftLint violations
**Environment**: Requires SwiftLint installation
**Output**: Modified source files
**Usage**:
```bash
fastlane ios lint_fix
```

#### `fastlane ios coverage`
**Purpose**: Generate detailed code coverage report
**Environment**: Requires Xcode
**Output**: Coverage report in `./fastlane/coverage/`
**Usage**:
```bash
fastlane ios coverage
```

### CI/CD Pipeline Lanes

#### `fastlane ios ci`
**Purpose**: Complete Continuous Integration pipeline
**Includes**: Lint → Build Debug → Test → Coverage → Build Release
**Environment**: Full CI environment
**Duration**: 5-10 minutes typical
**Usage**:
```bash
fastlane ios ci
```

#### `fastlane ios cd`
**Purpose**: Continuous Deployment pipeline
**Includes**: Clean git check → Full CI → Archive → Ready for distribution
**Environment**: Production CI environment
**Usage**:
```bash
fastlane ios cd
```

### App Store Lanes

#### `fastlane ios beta`
**Purpose**: Deploy to TestFlight for beta testing
**Environment**: Requires App Store Connect access
**Output**: Build uploaded to TestFlight
**Usage**:
```bash
fastlane ios beta
```

#### `fastlane ios release`
**Purpose**: Release to App Store
**Environment**: Requires App Store Connect access + main branch
**Output**: Build submitted for App Store review
**Usage**:
```bash
# Ensure on main branch
git checkout main
fastlane ios release
```

### Utility Lanes

#### `fastlane ios setup`
**Purpose**: Setup development environment
**Creates**: Required directories, installs dependencies
**Usage**:
```bash
fastlane ios setup
```

#### `fastlane ios clean`
**Purpose**: Clean build artifacts and derived data
**Removes**: Build outputs, test results, logs
**Usage**:
```bash
fastlane ios clean
```

## CI/CD Pipeline

### Pipeline Architecture
```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│   Trigger   │───▶│   Build      │───▶│    Test     │───▶│   Deploy     │
│  (Git Push) │    │  (fastlane)  │    │ (fastlane)  │    │ (fastlane)   │
└─────────────┘    └──────────────┘    └─────────────┘    └──────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
  Code Changes        Debug + Release     Unit + UI Tests    TestFlight/
  Git Webhook          Build Process      Code Coverage      App Store
```

### GitHub Actions Integration
```yaml
# .github/workflows/ios-ci.yml (Future Implementation)
name: iOS CI/CD Pipeline
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Run CI Pipeline
        run: fastlane ios ci
      
  deploy:
    needs: test
    runs-on: macos-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to TestFlight
        run: fastlane ios beta
```

### Pipeline Stages

#### Stage 1: Code Quality
- SwiftLint static analysis
- Code formatting validation
- Security vulnerability scanning

#### Stage 2: Build
- Debug build for testing
- Release build for distribution
- Archive creation with proper signing

#### Stage 3: Testing
- Unit test execution
- UI test automation
- Code coverage analysis
- Performance benchmarking

#### Stage 4: Deployment
- TestFlight beta deployment
- App Store submission
- Release tagging and documentation

## Troubleshooting

### Common Issues and Solutions

#### Build Failures

**Issue**: "No Xcode Installation Found"
```bash
# Solution: Install Xcode and accept license
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

**Issue**: "Scheme not found"
```bash
# Solution: Verify scheme exists and is shared
ls -la *.xcodeproj/xcshareddata/xcschemes/
# Ensure BobCamAgent.xcscheme exists
```

**Issue**: "Code signing error"
```bash
# Solution: Setup automatic code signing or match
# Edit project settings in Xcode or use:
fastlane match development
fastlane match appstore
```

#### Test Failures

**Issue**: "Simulator not available"
```bash
# Solution: List and create iOS simulator
xcrun simctl list devices
xcrun simctl create "iPhone 15 Pro Test" com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro com.apple.CoreSimulator.SimRuntime.iOS-17-0
```

**Issue**: "Test timeout"
```bash
# Solution: Increase timeout in fastlane configuration
# Add to run_tests action:
# test_timeout: 300
```

#### Dependency Issues

**Issue**: "Bundle install fails"
```bash
# Solution: Clear bundle cache and reinstall
bundle clean --force
bundle install
```

**Issue**: "Pod install fails"
```bash
# Solution: Update CocoaPods and clear cache
pod repo update
pod cache clean --all
pod install --repo-update
```

#### CI/CD Issues

**Issue**: "GitHub Actions failing"
```bash
# Solution: Check required secrets are set
# Go to GitHub repo → Settings → Secrets and variables → Actions
# Verify: APPLE_ID, APPLE_PASSWORD, MATCH_PASSWORD, FASTLANE_SESSION
```

**Issue**: "Fastlane session expired"
```bash
# Solution: Regenerate FASTLANE_SESSION
fastlane spaceauth -u your.apple.id@email.com
# Copy output to GitHub secrets
```

### Debug Commands

```bash
# Validate fastlane configuration
fastlane ios lanes
./scripts/validate-fastlane.sh

# Check Xcode and tools
xcode-select -p
xcodebuild -version
xcrun simctl list devices

# Verify project configuration
xcodebuild -list -project BobCamAgent.xcodeproj
xcodebuild -showBuildSettings -project BobCamAgent.xcodeproj -scheme BobCamAgent

# Test individual components
bundle exec fastlane ios build_debug --verbose
bundle exec fastlane ios test_unit --verbose
```

### Log Analysis

**Build Logs**: `./fastlane/logs/`
**Test Results**: `./fastlane/test_output/`
**Coverage Reports**: `./fastlane/coverage/`

```bash
# View recent logs
ls -la fastlane/logs/
tail -f fastlane/logs/fastlane.log

# Analyze test results
open fastlane/test_output/report.html
cat fastlane/test_output/report.junit
```

## Production Deployment

### Pre-Deployment Checklist

#### Code Quality
- [ ] All tests passing locally
- [ ] SwiftLint violations resolved
- [ ] Code coverage above 80%
- [ ] Security scan completed
- [ ] Performance benchmarks validated

#### Build Verification
- [ ] Debug build successful
- [ ] Release build successful
- [ ] Archive creation successful
- [ ] IPA size within limits (<200MB)

#### App Store Preparation
- [ ] App Store Connect metadata updated
- [ ] Screenshots and descriptions current
- [ ] Privacy policy reviewed
- [ ] Age rating appropriate
- [ ] In-app purchases configured (if applicable)

### Deployment Process

#### Step 1: Final Validation
```bash
# Clean environment
fastlane ios clean

# Full CI pipeline
fastlane ios ci

# Verify all outputs
ls -la fastlane/builds/
ls -la fastlane/test_output/
```

#### Step 2: Production Build
```bash
# Ensure on main branch
git checkout main
git pull origin main

# Create production archive
fastlane ios archive

# Upload to TestFlight
fastlane ios beta
```

#### Step 3: TestFlight Testing
- Internal testing with development team
- External testing with beta testers
- Performance monitoring
- Crash reporting analysis

#### Step 4: App Store Submission
```bash
# Final release to App Store
fastlane ios release

# Monitor submission status
# Check App Store Connect for review progress
```

### Post-Deployment Monitoring

#### Immediate Checks (0-24 hours)
- App Store Connect processing status
- TestFlight distribution success
- Initial crash reports
- Performance metrics baseline

#### Ongoing Monitoring (1-7 days)
- User adoption metrics
- Crash rate analysis
- Performance degradation detection
- App Store review sentiment

## Rollback Procedures

### Emergency Rollback Scenarios

#### Scenario 1: Critical Bug in Production
```bash
# Immediate actions:
# 1. Remove app from sale (if necessary)
# 2. Prepare hotfix branch
git checkout -b hotfix/critical-bug-fix

# 3. Apply minimal fix
# 4. Fast-track deployment
fastlane ios ci
fastlane ios beta  # Internal testing only
fastlane ios release  # Expedited review request
```

#### Scenario 2: TestFlight Issues
```bash
# 1. Stop TestFlight distribution
# 2. Notify beta testers
# 3. Revert to previous build
# 4. Investigate and fix issues
```

### Rollback Checklist

#### Pre-Rollback Assessment
- [ ] Identify root cause of issue
- [ ] Assess impact severity
- [ ] Determine rollback vs. hotfix strategy
- [ ] Notify stakeholders

#### Rollback Execution
- [ ] Stop current deployment
- [ ] Revert to last known good version
- [ ] Update monitoring and alerts
- [ ] Communicate status to users

#### Post-Rollback Actions
- [ ] Conduct incident post-mortem
- [ ] Update deployment procedures
- [ ] Implement additional safeguards
- [ ] Plan fix and re-deployment

### Version Management

```bash
# Tagging releases
git tag v1.0.0
git push origin v1.0.0

# Creating rollback point
git checkout v1.0.0
git checkout -b rollback/v1.0.0
fastlane ios archive
```

## Appendix

### Configuration Files Reference
- `Fastfile`: Main fastlane configuration
- `Appfile`: App-specific settings
- `Gemfile`: Ruby dependencies
- `Podfile`: CocoaPods dependencies
- `.swiftlint.yml`: Code quality rules

### Useful Commands Reference
```bash
# Fastlane
fastlane lanes                    # List available lanes
fastlane action build_app         # Action documentation
fastlane action run_tests         # Test action docs

# Xcode
xcodebuild -list                  # List schemes and targets
xcodebuild clean                  # Clean build
xcodebuild archive               # Create archive

# iOS Simulator
xcrun simctl list                # List simulators
xcrun simctl boot                # Start simulator
xcrun simctl shutdown            # Stop simulator

# Git
git flow init                    # Initialize git flow
git flow release start           # Start release branch
git flow release finish          # Complete release
```

### Support and Resources
- **Apple Developer Documentation**: https://developer.apple.com/documentation/
- **Fastlane Documentation**: https://docs.fastlane.tools/
- **GitHub Actions for iOS**: https://github.com/actions/runner-images/blob/main/images/macos/macos-13-Readme.md
- **SwiftLint Rules**: https://realm.github.io/SwiftLint/rule-directory.html

---
**Document Version**: 1.0  
**Last Updated**: 2025-08-21  
**Maintained By**: Deployment Engineering Team