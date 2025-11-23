#!/bin/bash

# BobCam iOS Project Creation Script
# This script creates a proper Xcode project structure for the existing Swift files

set -e  # Exit on any error

echo "🚀 Creating BobCam iOS Xcode Project..."

# Project variables
PROJECT_NAME="BobCamAgent"
BUNDLE_ID="com.bobcam.ios.app"
TEAM_ID="YOUR_TEAM_ID"  # Replace with actual team ID
APP_NAME="BobCam"

# Directories
PROJECT_DIR="$PROJECT_NAME"
SOURCE_DIR="$PROJECT_DIR/$PROJECT_NAME"

# Create project directory structure
echo "📁 Creating project directory structure..."
mkdir -p "$SOURCE_DIR"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Resources"
mkdir -p "$PROJECT_DIR/$PROJECT_NAME/Supporting Files"
mkdir -p "$PROJECT_DIR/${PROJECT_NAME}Tests"
mkdir -p "$PROJECT_DIR/${PROJECT_NAME}UITests"

# Move existing Swift files to the proper location
echo "📦 Moving existing Swift files..."
for file in *.swift; do
    if [ -f "$file" ] && [ "$file" != "create_xcode_project.sh" ]; then
        mv "$file" "$SOURCE_DIR/"
        echo "  Moved: $file"
    fi
done

# Move Info.plist
if [ -f "Info.plist" ]; then
    mv "Info.plist" "$SOURCE_DIR/Info.plist"
    echo "  Moved: Info.plist"
fi

# Move supporting directories
for dir in Monitoring Utils ParameterTuning DebugOverlay; do
    if [ -d "$dir" ]; then
        mv "$dir" "$SOURCE_DIR/"
        echo "  Moved directory: $dir"
    fi
done

# Create basic test files
echo "🧪 Creating basic test files..."

# Unit Tests
cat > "$PROJECT_DIR/${PROJECT_NAME}Tests/${PROJECT_NAME}Tests.swift" << EOF
import XCTest
@testable import $PROJECT_NAME

final class ${PROJECT_NAME}Tests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testVisionServiceInitialization() throws {
        // Test VisionService can be initialized
        let visionService = VisionService()
        XCTAssertNotNil(visionService)
        XCTAssertEqual(visionService.serviceState, .idle)
    }
    
    func testCameraServiceInitialization() throws {
        // Test CameraService can be initialized
        let cameraService = CameraService()
        XCTAssertNotNil(cameraService)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
EOF

# UI Tests
cat > "$PROJECT_DIR/${PROJECT_NAME}UITests/${PROJECT_NAME}UITests.swift" << EOF
import XCTest

final class ${PROJECT_NAME}UITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    func testAppLaunch() throws {
        // Test basic app launch
        let app = XCUIApplication()
        app.launch()
        
        // Check if the app launches without crashing
        XCTAssertTrue(app.exists)
    }
}
EOF

# UI Tests Launch Tests
cat > "$PROJECT_DIR/${PROJECT_NAME}UITests/${PROJECT_NAME}UITestsLaunchTests.swift" << EOF
import XCTest

final class ${PROJECT_NAME}UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot
        // For example, logging into a test account or navigating to a certain feature

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
EOF

echo "✅ Xcode project structure created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Open Xcode and create a new iOS project with name '$PROJECT_NAME'"
echo "2. Set Bundle Identifier to '$BUNDLE_ID'"
echo "3. Choose SwiftUI as the interface"
echo "4. Add the created source files to your project"
echo "5. Configure your Team ID in the project settings"
echo "6. Run: bundle exec fastlane setup"
echo ""
echo "📁 Project structure:"
echo "  $PROJECT_DIR/"
echo "  ├── $PROJECT_NAME/"
echo "  │   ├── Swift source files"
echo "  │   ├── Info.plist"
echo "  │   └── Supporting directories"
echo "  ├── ${PROJECT_NAME}Tests/"
echo "  └── ${PROJECT_NAME}UITests/"
echo ""
echo "🎉 Ready for fastlane automation!"