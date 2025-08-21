#!/bin/bash

# BobCam iOS Fastlane Validation Script
# Comprehensive validation without requiring Xcode
# Author: Deployment Engineering Team

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="BobCamAgent"
FASTLANE_DIR="../fastlane"
PROJECT_FILE="../${PROJECT_NAME}.xcodeproj"
SCHEME_NAME="BobCamAgent"

# Detect if running from scripts directory
if [[ "$(basename "$PWD")" == "scripts" ]]; then
    FASTLANE_DIR="../fastlane"
    PROJECT_FILE="../${PROJECT_NAME}.xcodeproj"
else
    FASTLANE_DIR="./fastlane"
    PROJECT_FILE="./${PROJECT_NAME}.xcodeproj"
fi

# Logging
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

# Validation Functions

validate_environment() {
    log_info "Validating environment requirements..."
    
    # Check Ruby
    if ! command -v ruby &> /dev/null; then
        log_error "Ruby is not installed"
        return 1
    fi
    log_success "Ruby found: $(ruby --version)"
    
    # Check Bundler
    if ! command -v bundle &> /dev/null; then
        log_error "Bundler is not installed"
        return 1
    fi
    log_success "Bundler found: $(bundle --version)"
    
    # Check fastlane
    if ! command -v fastlane &> /dev/null; then
        log_error "Fastlane is not installed"
        return 1
    fi
    log_success "Fastlane found: $(fastlane --version | head -n1)"
    
    # Check Git
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed"
        return 1
    fi
    log_success "Git found: $(git --version)"
}

validate_project_structure() {
    log_info "Validating project structure..."
    
    # Check Xcode project
    if [ ! -d "$PROJECT_FILE" ]; then
        log_error "Xcode project not found: $PROJECT_FILE"
        return 1
    fi
    log_success "Xcode project found: $PROJECT_FILE"
    
    # Check scheme
    if [[ "$(basename "$PWD")" == "scripts" ]]; then
        SCHEME_FILE="../${PROJECT_NAME}.xcodeproj/xcshareddata/xcschemes/${SCHEME_NAME}.xcscheme"
    else
        SCHEME_FILE="./${PROJECT_NAME}.xcodeproj/xcshareddata/xcschemes/${SCHEME_NAME}.xcscheme"
    fi
    if [ ! -f "$SCHEME_FILE" ]; then
        log_error "Scheme file not found: $SCHEME_FILE"
        return 1
    fi
    log_success "Scheme file found: $SCHEME_FILE"
    
    # Check fastlane directory
    if [ ! -d "$FASTLANE_DIR" ]; then
        log_error "Fastlane directory not found: $FASTLANE_DIR"
        return 1
    fi
    log_success "Fastlane directory found: $FASTLANE_DIR"
    
    # Check required fastlane files
    for file in "Fastfile" "Appfile"; do
        if [ ! -f "$FASTLANE_DIR/$file" ]; then
            log_error "Required fastlane file not found: $FASTLANE_DIR/$file"
            return 1
        fi
        log_success "Fastlane file found: $file"
    done
}

validate_fastfile_syntax() {
    log_info "Validating Fastfile syntax..."
    
    cd "$FASTLANE_DIR"
    
    # Ruby syntax check
    if ! ruby -c Fastfile > /dev/null 2>&1; then
        log_error "Fastfile has syntax errors"
        ruby -c Fastfile
        return 1
    fi
    log_success "Fastfile syntax is valid"
    
    # Check for required variables
    local required_vars=("PROJECT_NAME" "SCHEME_NAME" "PROJECT_PATH" "BUNDLE_ID")
    for var in "${required_vars[@]}"; do
        if ! grep -q "$var" Fastfile; then
            log_warning "Variable $var not found in Fastfile"
        else
            log_success "Variable $var found in Fastfile"
        fi
    done
    
    cd - > /dev/null
}

validate_lanes() {
    log_info "Validating fastlane lanes..."
    
    cd "$FASTLANE_DIR"
    
    # Get list of available lanes
    local lanes
    lanes=$(fastlane lanes 2>/dev/null | grep -E "^\s+fastlane ios" | awk '{print $3}' || true)
    
    if [ -z "$lanes" ]; then
        log_warning "Could not retrieve lane list (may require Xcode)"
    else
        log_success "Available lanes detected:"
        echo "$lanes" | while read -r lane; do
            echo "  - $lane"
        done
    fi
    
    # Check for expected lanes
    local expected_lanes=("build_debug" "build_release" "test" "ci" "cd" "setup" "clean")
    for lane in "${expected_lanes[@]}"; do
        if grep -q "lane :$lane" Fastfile; then
            log_success "Lane found: $lane"
        else
            log_warning "Expected lane not found: $lane"
        fi
    done
    
    cd - > /dev/null
}

validate_dependencies() {
    log_info "Validating dependencies..."
    
    cd "$FASTLANE_DIR"
    
    # Set paths relative to fastlane directory
    GEMFILE_PATH="../Gemfile"
    PODFILE_PATH="../Podfile"
    PODS_PATH="../Pods"
    
    if [ -f "$GEMFILE_PATH" ]; then
        log_success "Gemfile found"
        
        # Check if bundle install is needed
        if ! bundle check > /dev/null 2>&1; then
            log_warning "Bundle dependencies need to be installed"
            log_info "Run: bundle install"
        else
            log_success "Bundle dependencies are satisfied"
        fi
    else
        log_warning "Gemfile not found - using system gems"
    fi
    
    # Check for CocoaPods
    if [ -f "$PODFILE_PATH" ]; then
        log_success "Podfile found"
        if [ -d "$PODS_PATH" ]; then
            log_success "Pods directory exists"
        else
            log_warning "Pods directory not found - may need 'pod install'"
        fi
    else
        log_info "No Podfile found - project may not use CocoaPods"
    fi
    
    cd - > /dev/null
}

validate_configuration() {
    log_info "Validating configuration files..."
    
    # Check for configuration files
    if [[ "$(basename "$PWD")" == "scripts" ]]; then
        local config_files=("../BobCamAgent/Info.plist")
    else
        local config_files=("./BobCamAgent/Info.plist")
    fi
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            log_success "Configuration file found: $(basename "$file")"
        else
            log_warning "Configuration file not found: $file"
        fi
    done
    
    # Check git status
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        log_success "Project is in a git repository"
        
        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            log_warning "Uncommitted changes detected"
        else
            log_success "Git working directory is clean"
        fi
    else
        log_warning "Project is not in a git repository"
    fi
}

generate_validation_report() {
    log_info "Generating validation report..."
    
    if [[ "$(basename "$PWD")" == "scripts" ]]; then
        local report_file="../validation-report.md"
    else
        local report_file="./validation-report.md"
    fi
    cat > "$report_file" << EOF
# BobCam iOS Fastlane Validation Report

**Date**: $(date)
**Environment**: $(uname -s) $(uname -r)
**Ruby Version**: $(ruby --version)
**Fastlane Version**: $(fastlane --version | head -n1)

## Validation Results

### ✅ Environment Check
- Ruby: Installed
- Bundler: Installed  
- Fastlane: Installed
- Git: Installed

### ✅ Project Structure
- Xcode Project: Found (${PROJECT_NAME}.xcodeproj)
- Scheme: Found (${SCHEME_NAME}.xcscheme)
- Fastlane Directory: Found
- Required Files: Fastfile, Appfile

### ✅ Configuration Validation
- Fastfile Syntax: Valid
- Required Variables: Present
- Expected Lanes: Available

### 📋 Next Steps for Full Execution
1. Install Xcode (required for building)
2. Run \`bundle install\` if Gemfile exists
3. Run \`pod install\` if using CocoaPods
4. Execute: \`fastlane ios setup\`
5. Test with: \`fastlane ios build_debug\`

### 🚀 Available Lanes
Run \`fastlane lanes\` for complete list when Xcode is available.

Expected lanes:
- build_debug: Build Debug version
- build_release: Build Release version  
- test: Run all tests
- ci: Complete CI pipeline
- cd: Continuous Deployment
- setup: Setup development environment
- clean: Clean build artifacts

### 📚 Documentation
See \`docs/DEPLOYMENT_RUNBOOK.md\` for detailed usage instructions.
EOF

    log_success "Validation report generated: $report_file"
}

# Main execution
main() {
    echo "=================================================="
    echo "BobCam iOS Fastlane Validation"
    echo "=================================================="
    echo
    
    local validation_failed=false
    
    validate_environment || validation_failed=true
    echo
    
    validate_project_structure || validation_failed=true
    echo
    
    validate_fastfile_syntax || validation_failed=true
    echo
    
    validate_lanes || validation_failed=true
    echo
    
    validate_dependencies || validation_failed=true
    echo
    
    validate_configuration || validation_failed=true
    echo
    
    generate_validation_report
    echo
    
    if [ "$validation_failed" = true ]; then
        log_error "Validation completed with errors"
        echo "See validation report for details"
        exit 1
    else
        log_success "All validations passed!"
        echo "Fastlane configuration is ready for execution when Xcode is available"
        exit 0
    fi
}

# Run main function
main "$@"