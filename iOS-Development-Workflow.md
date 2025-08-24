# iOS 개발 워크플로우 가이드

## 프로젝트 구조
```
BobCam-iOS/
└── BobCamAgent/
    ├── BobCamAgent.xcodeproj        # Xcode 프로젝트 파일
    ├── BobCamAgent/                 # 메인 앱 소스코드
    │   ├── ContentView.swift        # 메인 UI
    │   ├── VisionService.swift      # 립 감지 서비스
    │   └── ...
    └── BobCamAgentTests/            # 테스트 파일들
```

## 개발 워크플로우

### 방법 1: Xcode GUI 사용 (권장)

1. **Xcode에서 프로젝트 열기**
   ```bash
   open BobCam-iOS/BobCamAgent/BobCamAgent.xcodeproj
   ```

2. **기기 선택**
   - Xcode 상단의 기기 선택 드롭다운에서 "iPhone 15 Pro" 시뮬레이터 또는 실제 iPhone 선택

3. **빌드 및 실행**
   - 플레이 버튼(▶️) 클릭 또는 `Cmd+R`
   - 자동으로 빌드 → 설치 → 실행

4. **최신 코드 확인**
   - Xcode에서 파일을 열어 최근 변경사항 확인
   - Git 히스토리: `View > Version Editor > Show Comparison View`

### 방법 2: 터미널 명령어 사용

1. **시뮬레이터에서 빌드 및 실행**
   ```bash
   # 프로젝트 루트 디렉토리에서 실행
   cd /Users/gunn.kim/study/BobCam
   
   # iPhone 15 Pro 시뮬레이터에서 실행
   xcodebuild -project BobCam-iOS/BobCamAgent/BobCamAgent.xcodeproj \
              -scheme BobCamAgent \
              -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
              build
   
   # 실행 (빌드 후 자동 설치됨)
   xcodebuild -project BobCam-iOS/BobCamAgent/BobCamAgent.xcodeproj \
              -scheme BobCamAgent \
              -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
              run
   ```

2. **실제 iPhone에 설치**
   ```bash
   # iPhone이 USB로 연결된 상태에서
   xcodebuild -project BobCam-iOS/BobCamAgent/BobCamAgent.xcodeproj \
              -scheme BobCamAgent \
              -destination 'generic/platform=iOS' \
              build
   ```

### 방법 3: 빠른 빌드 확인

1. **빌드만 확인 (설치 없이)**
   ```bash
   cd /Users/gunn.kim/study/BobCam
   xcodebuild -project BobCam-iOS/BobCamAgent/BobCamAgent.xcodeproj \
              -scheme BobCamAgent \
              -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
              build
   ```

## 최신 앱 확인 방법

### 1. 코드 변경사항 확인
```bash
# 최근 커밋 확인
git log --oneline -5

# 현재 브랜치 확인
git branch

# 워킹 디렉토리 상태 확인
git status
```

### 2. 앱 버전 확인
- Xcode에서: `BobCamAgent.xcodeproj` > `BobCamAgent` 타겟 > `General` 탭
- `Version`과 `Build` 번호 확인

### 3. 빌드 타임스탬프 확인
- 앱 실행 후 콘솔 로그에서 빌드 시간 확인
- Xcode: `View > Debug Area > Show Debug Area` (⌘⇧Y)

### 4. 시뮬레이터에서 앱 삭제 후 재설치
```bash
# 시뮬레이터 리셋 (모든 앱 삭제)
xcrun simctl erase all

# 또는 특정 앱만 삭제
xcrun simctl uninstall booted com.bobcam.BobCamAgent
```

## 개발 중 주의사항

### 1. 자동 빌드 설정 확인
- Xcode: `Product > Scheme > Edit Scheme...`
- `Build Configuration`이 `Debug`로 설정되어 있는지 확인

### 2. 캐시 정리
```bash
# Xcode 파생 데이터 삭제
rm -rf ~/Library/Developer/Xcode/DerivedData

# 또는 Xcode에서: Product > Clean Build Folder (⌘⇧K)
```

### 3. 코드 서명 문제 해결
- 실제 기기 설치 시 Apple Developer 계정 필요
- Xcode: `Signing & Capabilities` 탭에서 Team 설정

## 추천 워크플로우

1. **일반적인 개발**: Xcode GUI 사용 (방법 1)
2. **CI/CD나 자동화**: 터미널 명령어 사용 (방법 2)
3. **빠른 컴파일 체크**: 빌드만 확인 (방법 3)

## 현재 프로젝트 상태

```bash
# 현재 브랜치: feature/macbook-claude/app-brain-storming
# 최신 커밋: 0efba05 feat: Complete Phase 1.1 & 1.2 Implementation
# 현재 빌드 버전: 20250824.1214 (앱에서 확인 가능)
# 주요 개선사항:
# - 식사 감지 정확도 향상 (VisionService.swift)
# - 실시간 상태 배너 복원 (ContentView.swift)
# - MultiModalEatingDetectionService 통합
# - 앱 내 빌드 버전 표시 추가
```

## 빌드 버전 확인 방법

### 1. 앱 실행 화면에서 확인
- 앱을 실행하면 우상단 (설정 버튼 위)에 `v20250824.1214` 형태로 현재 빌드 버전이 표시됩니다.

### 2. Settings 화면에서 확인
- Settings 화면을 열면 "앱 정보" 섹션에서 상세한 빌드 정보를 확인할 수 있습니다:
  - 버전: 1.0
  - 빌드: 20250824.1214
  - 빌드 시간: DEBUG 모드에서는 현재 시간, Release 모드에서는 실제 빌드 시간

### 3. 수동 빌드 버전 업데이트
새로운 빌드를 만들 때마다 다음과 같이 빌드 번호를 업데이트할 수 있습니다:

```bash
# Info.plist에서 CFBundleVersion 값을 현재 날짜/시간으로 변경
# 형식: YYYYMMDD.HHMM
# 예: 20250824.1214 (2025년 8월 24일 12시 14분)
```

### 4. 자동 빌드 버전 업데이트 (향후)
`Scripts/update_build_info.sh` 스크립트가 준비되어 있어 Xcode Build Phases에 추가하면 자동으로 Git 커밋 해시와 빌드 시간이 업데이트됩니다.

## 문제 해결

### 빌드 실패 시
1. `Product > Clean Build Folder` (⌘⇧K)
2. Xcode 재시작
3. 터미널에서 `xcodebuild clean` 실행

### 앱이 예전 버전으로 보일 때
1. 시뮬레이터에서 앱 삭제
2. `Product > Clean Build Folder`
3. 다시 빌드 및 실행

### 실제 기기 설치 문제
1. iPhone이 개발자 모드로 설정되어 있는지 확인
2. Xcode에서 Apple ID 로그인 상태 확인
3. `Signing & Capabilities`에서 Team 설정 확인