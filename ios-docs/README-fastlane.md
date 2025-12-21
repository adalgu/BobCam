# BobCam iOS - fastlane Automation Setup

This document describes the fastlane automation setup for the BobCam iOS project, enabling automated builds, testing, and deployment workflows.

## 🚀 Quick Start

### Prerequisites

- macOS with Xcode 15.0+
- Ruby 2.6+ (recommended: 3.2+)
- Bundler gem installed
- iOS Developer Account (for distribution)

### Installation

1. **Install Dependencies**
   ```bash
   cd BobCam-iOS
   bundle install
   ```

2. **Setup Development Environment**
   ```bash
   bundle exec fastlane setup
   ```

3. **Create Xcode Project** (if not exists)
   ```bash
   ./create_xcode_project.sh
   ```

## 📦 Available Lanes

### Build Lanes

| Lane | Description | Usage |
|------|-------------|--------|
| `build_debug` | Build Debug configuration | `bundle exec fastlane build_debug` |
| `build_release` | Build Release configuration | `bundle exec fastlane build_release` |
| `archive` | Create archive and IPA | `bundle exec fastlane archive` |

### Test Lanes

| Lane | Description | Usage |
|------|-------------|--------|
| `test` | Run all tests with coverage | `bundle exec fastlane test` |
| `test_unit` | Run unit tests only | `bundle exec fastlane test_unit` |
| `test_ui` | Run UI tests only | `bundle exec fastlane test_ui` |

### Quality Assurance

| Lane | Description | Usage |
|------|-------------|--------|
| `lint` | Run SwiftLint analysis | `bundle exec fastlane lint` |
| `lint_fix` | Auto-fix SwiftLint violations | `bundle exec fastlane lint_fix` |
| `coverage` | Generate code coverage report | `bundle exec fastlane coverage` |

### CI/CD Pipelines

| Lane | Description | Usage |
|------|-------------|--------|
| `ci` | Complete CI pipeline | `bundle exec fastlane ci` |
| `cd` | Continuous deployment | `bundle exec fastlane cd` |
| `beta` | Deploy to TestFlight | `bundle exec fastlane beta` |
| `release` | Release to App Store | `bundle exec fastlane release` |

### Utility Lanes

| Lane | Description | Usage |
|------|-------------|--------|
| `setup` | Setup development environment | `bundle exec fastlane setup` |
| `clean` | Clean build artifacts | `bundle exec fastlane clean` |

## 🔧 Configuration

### 1. Appfile Configuration

Edit `fastlane/Appfile` with your development details:

```ruby
app_identifier("com.bobcam.ios.app")
apple_id("your-apple-id@example.com")
team_id("YOUR_TEAM_ID")
```

### 2. Code Signing Setup

For automatic code signing, configure match or manual provisioning:

```bash
# Option 1: Using match (recommended)
bundle exec fastlane match init

# Option 2: Manual provisioning
# Configure in Xcode project settings
```

### 3. Environment Variables

Set these environment variables for CI/CD:

```bash
# Required for App Store Connect
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="your-app-specific-password"
export APP_STORE_CONNECT_API_KEY_ID="your-api-key-id"
export APP_STORE_CONNECT_API_ISSUER_ID="your-issuer-id"
export APP_STORE_CONNECT_API_KEY="your-api-key-content"

# Required for match
export MATCH_PASSWORD="your-match-password"
```

## 🏗️ Project Structure

```
BobCam-iOS/
├── fastlane/
│   ├── Appfile          # App configuration
│   ├── Fastfile         # Lane definitions
│   ├── builds/          # Generated IPAs
│   ├── test_output/     # Test results
│   ├── logs/           # Build logs
│   └── coverage/       # Coverage reports
├── .github/
│   └── workflows/
│       └── ios-ci.yml   # GitHub Actions
├── BobCamAgent/         # Xcode project
├── .swiftlint.yml      # SwiftLint config
├── Gemfile             # Ruby dependencies
├── Podfile             # CocoaPods dependencies
└── README-fastlane.md  # This file
```

## 🤖 GitHub Actions Integration

The project includes a comprehensive GitHub Actions workflow (`.github/workflows/ios-ci.yml`) that:

### On Pull Requests:
- ✅ Runs quality checks (SwiftLint)
- 🔨 Builds Debug configuration
- 🧪 Executes all tests
- 📊 Generates coverage reports
- 💬 Comments results on PR

### On Main Branch Push:
- 🔨 Builds Release configuration
- 📦 Creates archive and IPA
- 🚀 Deploys to TestFlight (optional)

### Required Secrets:

Add these secrets to your GitHub repository:

```
MATCH_PASSWORD
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_API_ISSUER_ID
APP_STORE_CONNECT_API_KEY
```

## 📱 Development Workflow

### 1. Feature Development
```bash
# Start new feature
git checkout -b feature/new-feature

# Run quality checks during development
bundle exec fastlane lint
bundle exec fastlane test_unit

# Commit changes
git add .
git commit -m "feat: implement new feature"
git push origin feature/new-feature
```

### 2. Pull Request Process
```bash
# Create PR - GitHub Actions will automatically:
# - Run full CI pipeline
# - Report test results
# - Check code quality
```

### 3. Release Process
```bash
# Merge to main triggers:
# - Release build
# - Archive creation
# - TestFlight deployment (if configured)

# Manual release
bundle exec fastlane release
```

## 🔍 Code Quality Standards

### SwiftLint Rules
- Line length: 120 characters (warning), 150 (error)
- Function body length: 60 lines (warning), 100 (error)
- File length: 500 lines (warning), 800 (error)
- Custom rules for documentation and force unwrapping

### Test Coverage
- Minimum 70% code coverage target
- Unit tests for all business logic
- UI tests for critical user flows

### Build Requirements
- Clean builds with zero warnings
- All tests must pass
- SwiftLint analysis must pass

## 🚨 Troubleshooting

### Common Issues

**1. Bundle Install Fails**
```bash
# Use local bundle installation
bundle config set --local path vendor/bundle
bundle install
```

**2. Code Signing Issues**
```bash
# Reset provisioning profiles
bundle exec fastlane match nuke development
bundle exec fastlane match nuke distribution
bundle exec fastlane match
```

**3. Test Failures on CI**
```bash
# Check simulator availability
xcrun simctl list devices available
```

**4. SwiftLint Not Found**
```bash
# Install SwiftLint
brew install swiftlint
# Or via CocoaPods (already in Podfile)
pod install
```

### Debug Commands

```bash
# Verbose fastlane output
bundle exec fastlane [lane] --verbose

# Clean everything
bundle exec fastlane clean
rm -rf DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset fastlane
rm -rf ~/.fastlane
```

## 📚 Additional Resources

- [fastlane Documentation](https://docs.fastlane.tools/)
- [SwiftLint Rules](https://github.com/realm/SwiftLint/blob/main/Rules.md)
- [GitHub Actions for iOS](https://docs.github.com/en/actions/learn-github-actions)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)

## 🆘 Support

For issues specific to this fastlane setup:
1. Check this README for common solutions
2. Review fastlane logs in `fastlane/logs/`
3. Check GitHub Actions workflow results
4. Ensure all environment variables are properly set

---

*Generated for BobCam iOS Project - Production-ready fastlane automation*