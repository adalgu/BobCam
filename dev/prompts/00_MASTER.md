# BobCam Reboot - 마스터 개발 프롬프트

## 프로젝트 개요

BobCam은 **아이가 밥을 잘 먹도록 유도하는 iOS 앱**입니다. 비전 기반으로 아이의 "밥 먹는 행동"을 인식하고, 잘 먹으면 영상을 재생하고, 안 먹으면 영상을 정지하고 넛지를 표시합니다.

## 필수 참고 문서

개발 전 반드시 다음 문서를 읽어주세요:
- **SPEC 문서**: `/Users/macmini/study/01-active/BobCam/dev/docs/SPEC.md`
- **프로젝트 가이드**: `/Users/macmini/study/01-active/BobCam/CLAUDE.md`

## 개발 원칙

### 1. 리부트 원칙
- 기존 코드(`BobCamAgent/`)는 **참고만** 하고 **새로 구현**
- 기존 코드의 안정성이 낮으므로 구조와 아이디어만 참고
- 알고리즘과 상태 관리는 완전히 새로 설계

### 2. 코드 품질
- Protocol-Oriented Design 적용
- MVVM 아키텍처 (SwiftUI + ObservableObject)
- 명확한 에러 처리
- 메모리 누수 방지 (weak self, CVPixelBufferPool)

### 3. 테스트 가능성
- 서비스를 Protocol로 추상화
- 의존성 주입 패턴 사용
- Mock 객체로 테스트 가능하게 설계

## 개발 순서

### Phase 1: 핵심 기능 (MVP 필수)
프롬프트: `01_PHASE1_CORE.md`
1. 프로젝트 초기 설정 (기존 파일 정리)
2. VisionService: 입술 움직임 감지
3. VisionService: 손/얼굴 근접 감지
4. CameraService: 카메라 캡처
5. VideoService: 영상 재생/정지
6. 기본 통합 테스트

### Phase 2: 피드백 시스템
프롬프트: `02_PHASE2_FEEDBACK.md`
1. FeedbackService: 상태 관리
2. 넛지 UI (카메라 + 메시지)
3. 칭찬 UI
4. 부모 제어 (일시정지/강제재생)
5. 터치 제한 시스템

### Phase 3: 설정 및 통계
프롬프트: `03_PHASE3_SETTINGS.md`
1. 영상 선택 화면 (유튜브/사진첩/로컬)
2. 설정 화면 (민감도/시간/메시지)
3. StatisticsService: 통계 기록
4. 통계 화면
5. 데이터 영속화

## 기술 스택

| 영역 | 기술 |
|------|------|
| UI | SwiftUI |
| 상태관리 | ObservableObject, @Published |
| 비전 | Vision Framework (Face Landmarks, Hand Pose) |
| 카메라 | AVFoundation |
| 영상 | AVPlayer, WKWebView (YouTube) |
| 저장 | UserDefaults, FileManager |

## 핵심 서비스 인터페이스

```swift
// VisionService
protocol VisionServiceProtocol: ObservableObject {
    var isEating: Bool { get }
    var faceDetected: Bool { get }
    var handNearFace: Bool { get }
    var lipMovement: Double { get }
    func startProcessing()
    func stopProcessing()
    func processFrame(_ pixelBuffer: CVPixelBuffer)
}

// CameraService
protocol CameraServiceProtocol: ObservableObject {
    var isRunning: Bool { get }
    func startCapture()
    func stopCapture()
}

// VideoService
protocol VideoServiceProtocol: ObservableObject {
    var isPlaying: Bool { get }
    func play()
    func pause()
    func fadeOut(duration: TimeInterval)
    func fadeIn(duration: TimeInterval)
}

// FeedbackService
protocol FeedbackServiceProtocol: ObservableObject {
    var currentState: FeedbackState { get }
    func evaluateEatingState(_ isEating: Bool)
}

// StatisticsService
protocol StatisticsServiceProtocol: ObservableObject {
    var todayStats: DailyStats { get }
    func startSession()
    func endSession()
    func recordPause()
}
```

## 파일 구조

```
BobCamAgent/
├── App/
│   └── BobCamAgentApp.swift
├── Views/
│   ├── MainView.swift
│   ├── VideoSelectionView.swift
│   ├── SettingsView.swift
│   ├── StatisticsView.swift
│   └── Components/
├── Services/
│   ├── VisionService.swift
│   ├── CameraService.swift
│   ├── VideoService.swift
│   ├── FeedbackService.swift
│   └── StatisticsService.swift
├── Models/
│   ├── AppSettings.swift
│   ├── MealSession.swift
│   └── FeedbackState.swift
└── Utilities/
    ├── Constants.swift
    └── Extensions/
```

## 수락 기준 (전체)

- [ ] 입술 움직임으로 "먹는 중" 판단 (정확도 80%+)
- [ ] 손이 얼굴 근처에 오면 "먹는 중" 판단
- [ ] 5초간 안 먹으면 영상 정지
- [ ] 넛지 화면 표시 (카메라 + 메시지)
- [ ] 먹기 시작하면 칭찬 + 영상 재생
- [ ] 유튜브/로컬 영상 재생
- [ ] 사진첩에서 영상 선택
- [ ] 일시 정지/강제 재생 버튼
- [ ] 설정에서 민감도/시간 조절
- [ ] 식사 통계 기록 및 표시
- [ ] 30분 이상 안정적 동작

## 시작하기

1. SPEC.md 문서를 먼저 읽으세요
2. Phase 1 프롬프트(`01_PHASE1_CORE.md`)부터 순서대로 진행
3. 각 Phase 완료 후 통합 테스트 수행
4. 다음 Phase로 진행

---

**다음 단계**: `01_PHASE1_CORE.md` 프롬프트 실행
