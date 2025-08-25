#!/bin/bash

echo "🚀 BobCam 단순 배포 스크립트"
echo "============================="

# 1. Clean build directory
echo "1️⃣ Clean build..."
rm -rf build/

# 2. Build for device directly (development build)
echo "2️⃣ Build for device..."
xcodebuild -project BobCamAgent.xcodeproj -scheme BobCamAgent -configuration Debug -destination 'platform=iOS,id=00008110-0011714C2201801E' -allowProvisioningUpdates

# 3. Uninstall existing app
echo "3️⃣ Uninstalling old app..."
xcrun devicectl device uninstall app --device 00008110-0011714C2201801E "com.bobcam.ios.app" || echo "App not found, continuing..."

# 4. Install new app
echo "4️⃣ Installing new app directly from build..."
xcrun devicectl device install app --device 00008110-0011714C2201801E /Users/gunn.kim/Library/Developer/Xcode/DerivedData/BobCamAgent-*/Build/Products/Debug-iphoneos/BobCamAgent.app

echo "✅ 배포 완료!"
