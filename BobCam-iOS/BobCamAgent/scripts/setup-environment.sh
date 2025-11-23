#!/bin/bash

# BobCam iOS Environment Setup Script
# Comprehensive development environment configuration
# Author: Deployment Engineering Team

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="BobCamAgent"
MIN_XCODE_VERSION="15.0"
MIN_IOS_VERSION="17.0"
RUBY_VERSION="3.0.0"

# Logging functions
log_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Helper functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

version_compare() {
    printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1
}

# Environment validation functions
check_macos() {
    log_info "Checking macOS compatibility..."
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "This setup script requires macOS"
        exit 1
    fi
    
    local macos_version=$(sw_vers -productVersion)
    log_success "macOS version: $macos_version"
    
    # Check for minimum macOS version (macOS 12.0 for Xcode 15)
    if [[ $(version_compare "12.0" "$macos_version") == "$macos_version" && "$macos_version" != "12.0" ]]; then
        log_warning "macOS 12.0 or later recommended for Xcode 15+"
    fi
}

check_xcode() {
    log_info "Checking Xcode installation..."
    
    if ! command_exists xcodebuild; then
        log_error "Xcode not found. Please install Xcode from the App Store"
        log_info "Visit: https://apps.apple.com/app/xcode/id497799835"
        exit 1
    fi
    
    local xcode_version=$(xcodebuild -version | head -n1 | awk '{print $2}')
    log_success "Xcode version: $xcode_version"
    
    # Check minimum version
    if [[ $(version_compare "$MIN_XCODE_VERSION" "$xcode_version") == "$xcode_version" && "$xcode_version" != "$MIN_XCODE_VERSION" ]]; then
        log_warning "Xcode $MIN_XCODE_VERSION or later recommended"
    fi
    
    # Check Xcode license
    if ! xcodebuild -checkFirstLaunchStatus; then
        log_warning "Xcode license not accepted. Running license acceptance..."
        sudo xcodebuild -license accept || {
            log_error "Failed to accept Xcode license"
            exit 1
        }
    fi
    
    # Check Command Line Tools
    if ! xcode-select -p >/dev/null 2>&1; then
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_info "Please complete the Command Line Tools installation and re-run this script"
        exit 0
    fi
    
    log_success "Xcode Command Line Tools: $(xcode-select -p)"
}

setup_homebrew() {
    log_info "Setting up Homebrew..."
    
    if ! command_exists brew; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for M1/M2 Macs
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        log_success "Homebrew already installed: $(brew --version | head -n1)"
    fi
    
    # Update Homebrew
    log_info "Updating Homebrew..."
    brew update || log_warning "Failed to update Homebrew"
}

setup_ruby() {
    log_info "Setting up Ruby environment..."
    
    # Install rbenv if not present
    if ! command_exists rbenv; then
        log_info "Installing rbenv..."
        brew install rbenv ruby-build
        
        # Add rbenv to shell profile
        if ! grep -q 'rbenv init' ~/.zshrc; then
            echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
        fi
        
        # Initialize rbenv in current session
        eval "$(rbenv init - zsh)"
    else
        log_success "rbenv already installed: $(rbenv --version)"
    fi
    
    # Install required Ruby version
    local current_ruby=$(ruby --version | awk '{print $2}')
    log_info "Current Ruby version: $current_ruby"
    
    if [[ $(version_compare "$RUBY_VERSION" "$current_ruby") == "$current_ruby" && "$current_ruby" != "$RUBY_VERSION" ]]; then
        log_info "Installing Ruby $RUBY_VERSION..."
        rbenv install "$RUBY_VERSION"
        rbenv global "$RUBY_VERSION"
        rbenv rehash
    fi
    
    # Install/update Bundler
    log_info "Setting up Bundler..."
    gem install bundler || log_warning "Failed to install Bundler"
    
    log_success "Ruby environment ready"
}

setup_fastlane() {
    log_info "Setting up Fastlane..."
    
    # Navigate to project directory
    cd "$(dirname "$0")/.."
    
    # Install gems from Gemfile
    if [[ -f "Gemfile" ]]; then
        log_info "Installing gems from Gemfile..."
        bundle install
        log_success "Bundle install completed"
    else
        # Install fastlane globally if no Gemfile
        log_info "Installing fastlane globally..."
        gem install fastlane
    fi
    
    # Verify fastlane installation
    if command_exists fastlane; then
        log_success "Fastlane installed: $(fastlane --version | head -n1)"
    else
        log_error "Fastlane installation failed"
        exit 1
    fi
}

setup_cocoapods() {
    log_info "Setting up CocoaPods..."
    
    # Install CocoaPods
    if ! command_exists pod; then
        log_info "Installing CocoaPods..."
        gem install cocoapods
        pod setup
    else
        log_success "CocoaPods already installed: $(pod --version)"
    fi
    
    # Install project dependencies
    if [[ -f "Podfile" ]]; then
        log_info "Installing pod dependencies..."
        pod install --repo-update
        log_success "Pod install completed"
    else
        log_info "No Podfile found - skipping pod install"
    fi
}

setup_development_tools() {
    log_info "Setting up development tools..."
    
    # SwiftLint
    if ! command_exists swiftlint; then
        log_info "Installing SwiftLint..."
        brew install swiftlint
    else
        log_success "SwiftLint already installed: $(swiftlint version)"
    fi
    
    # SwiftFormat (optional)
    if ! command_exists swiftformat; then
        log_info "Installing SwiftFormat..."
        brew install swiftformat
    else
        log_success "SwiftFormat already installed: $(swiftformat --version)"
    fi
    
    # Sourcery (optional code generation)
    if ! command_exists sourcery; then
        log_info "Installing Sourcery..."
        brew install sourcery
    else
        log_success "Sourcery already installed: $(sourcery --version)"
    fi
    
    # iOS Simulator management
    log_info "Setting up iOS Simulators..."
    
    # List available runtimes
    local available_runtimes=$(xcrun simctl list runtimes | grep "iOS" | grep -v "watchOS" | grep -v "tvOS")
    log_info "Available iOS runtimes:"
    echo "$available_runtimes"
    
    # Create required simulators if they don't exist
    local iphone_15_pro="iPhone 15 Pro"
    if ! xcrun simctl list devices | grep -q "$iphone_15_pro"; then
        log_info "Creating iPhone 15 Pro simulator..."
        xcrun simctl create "$iphone_15_pro" com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro com.apple.CoreSimulator.SimRuntime.iOS-17-0 || log_warning "Failed to create iPhone 15 Pro simulator"
    fi
}

setup_directories() {
    log_info "Setting up project directories..."
    
    # Create required directories
    local directories=(
        "fastlane/builds"
        "fastlane/test_output"
        "fastlane/logs"
        "fastlane/coverage"
        "scripts"
        "docs"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_success "Created directory: $dir"
        fi
    done
    
    # Create .gitignore entries
    local gitignore_entries=(
        "fastlane/builds/*"
        "fastlane/test_output/*"
        "fastlane/logs/*"
        "fastlane/coverage/*"
        "!fastlane/builds/.gitkeep"
        "!fastlane/test_output/.gitkeep"
        "!fastlane/logs/.gitkeep"
        "!fastlane/coverage/.gitkeep"
        "validation-report.md"
        ".env"
        "*.ipa"
        "*.dSYM.zip"
    )
    
    for entry in "${gitignore_entries[@]}"; do
        if ! grep -q "$entry" .gitignore 2>/dev/null; then
            echo "$entry" >> .gitignore
        fi
    done
    
    # Create .gitkeep files
    for dir in "${directories[@]}"; do
        if [[ "$dir" == fastlane/* && ! -f "$dir/.gitkeep" ]]; then
            touch "$dir/.gitkeep"
        fi
    done
}

setup_environment_variables() {
    log_info "Setting up environment variables..."
    
    # Create .env.template file
    cat > .env.template << EOF
# BobCam iOS Environment Variables Template
# Copy this file to .env and fill in your values

# App Store Connect API
APP_STORE_CONNECT_ISSUER_ID=your_issuer_id
APP_STORE_CONNECT_KEY_ID=your_key_id
APP_STORE_CONNECT_PRIVATE_KEY_PATH=path_to_private_key.p8

# Code Signing
MATCH_PASSWORD=your_match_password
MATCH_GIT_URL=git_repo_for_certificates
MATCH_TYPE=appstore

# Apple Developer Account
APPLE_ID=your_apple_id@email.com
APPLE_PASSWORD=app_specific_password

# Fastlane
FASTLANE_SESSION=session_for_2fa_bypass
FASTLANE_SKIP_UPDATE_CHECK=1
FASTLANE_HIDE_CHANGELOG=1

# CI/CD
SLACK_WEBHOOK_URL=your_slack_webhook_url
TEAMS_WEBHOOK_URL=your_teams_webhook_url

# Development
ENVIRONMENT=development
DEBUG=true
VERBOSE_LOGGING=false
EOF
    
    log_success "Created .env.template file"
    log_info "Copy .env.template to .env and configure your values"
}

validate_setup() {
    log_header "Validating Environment Setup"
    
    # Run validation script
    if [[ -f "scripts/validate-fastlane.sh" ]]; then
        ./scripts/validate-fastlane.sh
    else
        log_warning "Validation script not found - manual validation required"
    fi
    
    # Test basic fastlane functionality
    log_info "Testing fastlane setup..."
    if bundle exec fastlane ios setup; then
        log_success "Fastlane setup lane executed successfully"
    else
        log_warning "Fastlane setup lane failed - check configuration"
    fi
}

generate_setup_report() {
    log_info "Generating setup report..."
    
    cat > setup-report.md << EOF
# BobCam iOS Environment Setup Report

**Date**: $(date)
**Environment**: $(uname -s) $(uname -r)
**User**: $(whoami)

## System Information
- macOS Version: $(sw_vers -productVersion)
- Xcode Version: $(xcodebuild -version | head -n1)
- Ruby Version: $(ruby --version)
- Bundler Version: $(bundle --version)
- Fastlane Version: $(fastlane --version | head -n1)

## Installed Tools
- Homebrew: $(brew --version | head -n1)
- CocoaPods: $(pod --version)
- SwiftLint: $(swiftlint version)
- SwiftFormat: $(command_exists swiftformat && swiftformat --version || echo "Not installed")
- Sourcery: $(command_exists sourcery && sourcery --version || echo "Not installed")

## Project Status
- Project Directory: $(pwd)
- Git Repository: $(git rev-parse --is-inside-work-tree 2>/dev/null || echo "Not a git repository")
- Current Branch: $(git branch --show-current 2>/dev/null || echo "N/A")
- Last Commit: $(git log -1 --pretty=format:"%h %s" 2>/dev/null || echo "N/A")

## Next Steps
1. Configure .env file with your credentials
2. Run fastlane ios setup to initialize the project
3. Test with fastlane ios build_debug
4. Setup GitHub Actions secrets for CI/CD
5. Configure code signing with match

## Documentation
- Deployment Runbook: docs/DEPLOYMENT_RUNBOOK.md
- Validation Script: scripts/validate-fastlane.sh
- Environment Template: .env.template

---
Generated by BobCam iOS Setup Script
EOF
    
    log_success "Setup report generated: setup-report.md"
}

print_completion_message() {
    log_header "Setup Complete!"
    
    echo -e "${GREEN}"
    cat << "EOF"
  ____        _      ____                    ___ ___  ____  
 | __ )  ___ | |__  / ___|__ _ _ __ ___      |_ _/ _ \/ ___| 
 |  _ \ / _ \| '_ \| |   / _` | '_ ` _ \      | | | | \___ \ 
 | |_) | (_) | |_) | |__| (_| | | | | | |     | | |_| |___) |
 |____/ \___/|_.__/ \____\__,_|_| |_| |_|    |___\___/|____/ 
                                                             
 Development Environment Ready!
EOF
    echo -e "${NC}"
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Review and configure .env file"
    echo "2. Run: fastlane ios setup"
    echo "3. Test build: fastlane ios build_debug"
    echo "4. Setup CI/CD secrets in GitHub"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "- Deployment Runbook: docs/DEPLOYMENT_RUNBOOK.md"
    echo "- Setup Report: setup-report.md"
    echo ""
    echo -e "${GREEN}Happy coding! 🚀${NC}"
}

# Main execution
main() {
    log_header "BobCam iOS Environment Setup"
    
    check_macos
    check_xcode
    setup_homebrew
    setup_ruby
    setup_fastlane
    setup_cocoapods
    setup_development_tools
    setup_directories
    setup_environment_variables
    validate_setup
    generate_setup_report
    print_completion_message
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --minimal)
            MINIMAL_SETUP=true
            shift
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --help)
            echo "BobCam iOS Environment Setup Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --minimal          Skip optional development tools"
            echo "  --skip-validation  Skip environment validation"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@"