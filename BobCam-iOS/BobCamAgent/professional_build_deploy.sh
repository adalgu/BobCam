#!/bin/bash

# Professional iOS Build & Deployment Script for BobCam
# Following iOS-builder specialist recommendations

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DEVICE_ID="A93D20BE-2726-58A7-A496-C5D61682D081"
WORKSPACE="BobCamAgent.xcworkspace"
SCHEME="BobCamAgent"

echo -e "${GREEN}🔨 BobCam Professional Build & Deploy Process${NC}"
echo -e "${YELLOW}Following iOS-builder specialist methodology${NC}"
echo ""

# Step 1: Clean Environment
echo -e "${GREEN}Step 1: Cleaning build environment...${NC}"
echo "🧹 Cleaning Derived Data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/

echo "🧹 Cleaning CocoaPods cache..."
pod cache clean --all

echo "🧹 Removing CocoaPods generated files..."
rm -rf Pods/ Podfile.lock BobCamAgent.xcworkspace

echo "📦 Reinstalling CocoaPods dependencies..."
pod install

# Step 2: Verify Device Connectivity
echo -e "${GREEN}Step 2: Verifying device connectivity...${NC}"
if xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -showdestinations | grep -q "$DEVICE_ID"; then
    echo "✅ Target device ($DEVICE_ID) is connected and available"
else
    echo -e "${RED}❌ Target device not found. Please ensure device is connected and trusted.${NC}"
    exit 1
fi

# Step 3: Clean Build
echo -e "${GREEN}Step 3: Performing clean build...${NC}"
xcodebuild clean -workspace "$WORKSPACE" -scheme "$SCHEME"

# Step 4: Build for Device
echo -e "${GREEN}Step 4: Building for target device...${NC}"
xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" \
  -destination "platform=iOS,id=$DEVICE_ID" build

# Step 5: Find Built App
echo -e "${GREEN}Step 5: Locating built application...${NC}"
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "BobCamAgent.app" | head -1)
if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ Built app not found${NC}"
    exit 1
fi
echo "📱 App found at: $APP_PATH"

# Step 6: Deploy to Device
echo -e "${GREEN}Step 6: Deploying to device...${NC}"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo ""
echo -e "${GREEN}✅ Build and deployment complete!${NC}"
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Launch the BobCam app on your device"
echo "2. Grant camera permissions when prompted"
echo "3. To test video playback:"
echo "   - Tap the 'Select Video' button in the video area"
echo "   - Choose a video from your photo library"
echo "   - Start eating to trigger video playback"
echo ""
echo -e "${YELLOW}⚠️ Important Note:${NC}"
echo "The app requires a video to be selected before playback can work."
echo "This is the expected behavior based on the current implementation."