#!/bin/bash

# update_build_info.sh
# 빌드 시 Git 커밋 해시와 빌드 타임스탬프를 Info.plist에 자동 추가

set -e

# Git 커밋 해시 가져오기
GIT_COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# 빌드 타임스탬프 생성
BUILD_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 빌드 번호를 현재 시간 기반으로 자동 증가
BUILD_NUMBER=$(date '+%y%m%d%H%M')

# Info.plist 경로
INFO_PLIST_PATH="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

echo "🔨 빌드 정보 업데이트 중..."
echo "   Git 커밋: ${GIT_COMMIT_HASH}"
echo "   빌드 시간: ${BUILD_TIMESTAMP}"
echo "   빌드 번호: ${BUILD_NUMBER}"

# Info.plist가 존재하는 경우에만 업데이트
if [ -f "${INFO_PLIST_PATH}" ]; then
    # Git 커밋 해시 추가
    /usr/libexec/PlistBuddy -c "Add :GitCommitHash string ${GIT_COMMIT_HASH}" "${INFO_PLIST_PATH}" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :GitCommitHash ${GIT_COMMIT_HASH}" "${INFO_PLIST_PATH}"
    
    # 빌드 타임스탬프 추가
    /usr/libexec/PlistBuddy -c "Add :BuildTimestamp string ${BUILD_TIMESTAMP}" "${INFO_PLIST_PATH}" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :BuildTimestamp ${BUILD_TIMESTAMP}" "${INFO_PLIST_PATH}"
    
    # 빌드 번호 자동 업데이트
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${INFO_PLIST_PATH}"
    
    echo "✅ 빌드 정보가 성공적으로 업데이트되었습니다."
else
    echo "❌ Info.plist 파일을 찾을 수 없습니다: ${INFO_PLIST_PATH}"
    exit 1
fi