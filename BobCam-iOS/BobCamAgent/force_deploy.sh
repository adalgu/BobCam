#!/bin/bash

echo "🚀 BobCam 강제 재배포 스크립트 - Nuclear Option"
echo "============================================"

# 1. 완전 클린
echo "1️⃣ 완전 클린 빌드..."
rm -rf build/
rm -rf DerivedData/
xcodebuild clean -project BobCamAgent.xcodeproj -scheme BobCamAgent

# 2. 새 빌드 번호로 아카이브
echo "2️⃣ 새 빌드 번호로 아카이브..."
BUILD_NUMBER=$(date +"%Y%m%d.%H%M")
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" BobCamAgent/Info.plist
xcodebuild archive -project BobCamAgent.xcodeproj -scheme BobCamAgent -configuration Release -archivePath build/BobCamAgent.xcarchive DEVELOPMENT_TEAM="T6L9Q5DN5W" CODE_SIGN_IDENTITY="Apple Development"

# 3. 새 IPA 생성
echo "3️⃣ 새 IPA 생성..."
xcodebuild -exportArchive -archivePath build/BobCamAgent.xcarchive -exportOptionsPlist build/ExportOptions.plist -exportPath build/

# 4. 기기에서 완전 삭제
echo "4️⃣ 기기에서 앱 완전 삭제..."
xcrun devicectl device list apps --device-id $1 | grep "com.bobcam.ios.app" && xcrun devicectl device uninstall app --device-id $1 "com.bobcam.ios.app"

# 5. 잠시 대기
echo "5️⃣ 3초 대기..."
sleep 3

# 6. 새 앱 설치
echo "6️⃣ 새 앱 설치..."
xcrun devicectl device install app --device-id $1 build/BobCamAgent.ipa

echo "✅ 완료! 빌드 번호: $BUILD_NUMBER"
