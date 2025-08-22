# HANDOFF — 랜드마크 오버레이 디버그 (현재 상태 & 다음 작업)

작성일: 2025-08-22  
작성자: 자동 정리 에이전트

## 1) 목적

랜드마크(입술) 디버그 오버레이를 활성화하면 앱이 종료(crash)되는 문제를 조사하고 안전한 패치(스냅샷/미러링 방어)를 적용했습니다. 이 핸드오프는 다음 에이전트가 이어서 검증 및 남은 문제를 해결할 수 있도록 현재 상태, 변경사항, 재현 절차 및 우선 순위 To‑do를 정리합니다.

## 2) 요약 — 지금까지 한 일 (완료)

- 문제: 디버그에서 "랜드마크 오버레이 토글 활성화 시 앱 종료" 보고
- 원인(실제 크래시 로그): NSException — "\*\*\* -[AVCaptureConnection setVideoMirrored:] Cannot be set when automaticallyAdjustsVideoMirroring is YES"
- 적용한 방어 패치(빠른 안전 패치)
  1. LandmarksOverlayView.swift
     - VNFaceLandmarks2D / VNFaceObservation 직접 보관으로 인한 스레드/메모리 문제 의심 → Vision 객체를 직접 저장하지 않고 normalizedPoints를 CGPoint 배열로 스냅샷하여 저장/그리도록 변경.
     - LandmarkFrame 구조체를 VNFaceLandmarks2D 보관에서 [CGPoint] 스냅샷 보관으로 변경.
     - updateLandmarks(...)에서 메인 스레드로 안전하게 스냅샷을 복사하고 setNeedsDisplay() 호출.
  2. DebugCameraView.swift
     - AVCaptureVideoPreviewLayer 연결 시 isVideoMirrored 설정에서 발생하는 예외를 방지하기 위해 `connection.automaticallyAdjustsVideoMirroring`를 false로 설정한 뒤 `isVideoMirrored = true`를 설정하도록 변경.
- 빌드/설치 작업
  - CocoaPods 설치: `pod install --repo-update` (BobCam-iOS/BobCamAgent)
  - Debug 빌드 및 장비 설치: xcodebuild로 Debug 빌드 및 설치(장비 id 사용)
  - 빌드, 설치 성공(로컬 연결된 device에 설치됨)

## 3) 수정된 파일 (중요)

- BobCam-iOS/BobCamAgent/BobCamAgent/DebugOverlay/LandmarksOverlayView.swift
  - VNFaceLandmarks2D → CGPoint 스냅샷 구조로 변경
  - LandmarkFrame 재정의 (outerLips: [CGPoint], innerLips: [CGPoint]?, boundingBox: CGRect, timestamp)
  - draw/drawCurrentLandmarks 등의 함수가 스냅샷 배열 기반으로 동작하도록 변경
- BobCam-iOS/BobCamAgent/BobCamAgent/DebugOverlay/DebugCameraView.swift
  - AVCaptureVideoPreviewLayer.connection 미러링 설정 로직에 자동 미러링 해제(automaticallyAdjustsVideoMirroring = false) 추가
- (빌드 시) Pods 프로젝트에 `pod install` 수행 — SwiftLint 등 의존성 설치

## 4) 재현 절차 (간략)

1. Xcode에서 BobCamAgent scheme, Destination: 물리 iPhone 선택
2. Run (Cmd+R) 또는 아래 커맨드 사용:
   - cd BobCam-iOS/BobCamAgent
   - xcodebuild -workspace BobCamAgent.xcworkspace -scheme BobCamAgent -configuration Debug -destination 'id=<DEVICE_ID>' clean build install
3. 앱 실행 → (Debug 빌드일 때) Debug overlay의 "mouth" 토글(빠른 플로팅 또는 설정 내)을 눌러 Landmarks Overlay 활성화
4. 정상: 오버레이가 보이고 앱이 유지. 실패: 앱이 종료(crash).

현재 재현 결과: 첫 테스트에서 예외(automaticallyAdjustsVideoMirroring 관련)로 앱이 종료됨. 위의 mirroring 방어 패치를 적용 후 다시 빌드/설치함.

## 5) 현재 상태 (2025-08-22 17:00 KST)

- 방어 패치 적용: 완료 (LandmarksOverlayView + DebugCameraView 수정)
- CocoaPods 재설치 및 Debug 빌드/장치 설치: 완료
- 검증: 사용자가 토글 테스트를 수행했고 최초 크래시 로그(automaticallyAdjustsVideoMirroring 예외)를 제공함. 이후 미러링 패치 적용 후 테스트 필요(사용자가 아직 재현 결과를 최종 보고하지 않음).
- 남은 의심 지점:
  - VNFaceLandmarks2D 객체의 안전성(스레드/백핑): 스냅샷으로 완화했음 — 추가 메모리/경계 검사 필요.
  - draw() 내에 인덱스 접근 경계 검사(이미 적용된 getAveragePoint 안전 검사 있음).
  - UI 업데이트 호출이 항상 메인 스레드에서 이루어지는지 (이미 DispatchQueue.main에서 setNeedsDisplay를 보장하도록 변경됨).

## 6) 우선순위 To‑do (다음 에이전트가 수행할 작업)

- [ ] 1. 장치에서 오버레이 토글을 다시 실행하여 크래시 재현 여부를 확인하고 결과를 기록
  - 성공: "오버레이 활성화 → 앱 유지" 보고
  - 실패: 새 crash report (Xcode Devices → View Device Logs) 및 Xcode 콘솔 출력 제공
- [ ] 2. (만약 지속적으로 크래시가 발생하면) Exception Breakpoint 추가해서 정확한 스택 프레임(파일/라인) 캡처
- [ ] 3. LandmarksOverlayView.draw / 트레일 드로잉 경로에 대해 추가 방어: 빈 배열/0으로 나누기, 인덱스 범위 초과 검사 강화
- [ ] 4. VisionService → DebugCameraUIView 데이터 전달 경로 재검증:
  - VisionService에서 publish한 값이 UI로 전달되기까지 항상 메인 스레드에서 이루어지는지 확인
  - 필요한 경우 `@MainActor` 또는 DispatchQueue.main.async로 강제
- [ ] 5. 장기: Thread Sanitizer / Address Sanitizer로 실행해 데이터 레이스/메모리 문제 탐지(단, 성능 저하 유의)
- [ ] 6. 테스트 시나리오 문서화 및 자동화(가능하면 간단한 UI automation으로 토글 테스트)
- [ ] 7. 변경사항을 Git에 커밋하고 PR 생성 (커밋 메시지에 이 핸드오프 요약 포함)

## 7) 참조 (핵심 로그 & 메모)

- 최초 크래시 예외:  
  `NSException * "*** -[AVCaptureConnection setVideoMirrored:] Cannot be set when automaticallyAdjustsVideoMirroring is YES"`  
  (이로 인해 DebugCameraView의 previewLayer 연결부가 문제로 지목되어 미러링 방어 패치 적용)
- 변경 커밋 해시(현재 작업 기준): cc86270849ad54754b1fc7eea6a6357b5abfe051
- 변경 파일 목록(위 섹션 참조)

## 8) 환경 & 빌드 관련 (간단)

- 개발 OS: macOS (M1/arm64 호환, Xcode 16.x 계열)
- 대상 iOS 최소: 15.0
- 사용한 명령(또는 매뉴얼 빌드 흐름) 정리는 별도 `XCODE-BUILD-MANUAL.md`에 제공됨 (이 파일과 함께 제공).

## 9) 연락 & 기타

- 다음 에이전트는 위 To‑do 첫 항목(장치에서의 재검증)을 수행하고, 그 결과(성공/실패 + 로그)를 이 핸드오프에 붙여서 이어받아 작업을 계속하십시오.
