# BobCam Reboot - 기술 스펙 문서

> **목적**: 아이가 밥을 잘 먹도록 유도하는 iOS 앱
> **버전**: MVP v1.0
> **작성일**: 2026-01-18
> **대상**: AI 에이전트 및 개발자

---

## 1. 프로젝트 개요

### 1.1 핵심 컨셉
- 비전 기반으로 아이의 "밥 먹는 행동"을 인식
- 잘 먹으면 **양의 피드백** (영상 재생)
- 안 먹으면 **음의 피드백** (영상 정지 + 넛지)

### 1.2 리부트 배경
기존 저장소에 입술 인식 기반 영상 재생 기능이 구현되어 있으나, 안정성과 완성도가 낮아 제대로 동작하지 않음. 기존 코드는 **참고만** 하고 **완전히 새롭게** 구현한다.

### 1.3 타겟 사용자
- **아이**: 4세 이상, 자율 식사 가능
- **부모**: 식사 중 개입을 줄이고 싶은 보호자

### 1.4 성공 기준
1. **부모 개입 감소**: "밥 먹어!" 말하는 횟수 감소
2. **아이 자발적 식사**: 아이가 스스로 먹으려고 함

---

## 2. 핵심 기능 명세

### 2.1 밥 먹는 행동 감지 (복합 판단)

#### 2.1.1 감지 신호
| 신호 | 설명 | 우선순위 |
|------|------|----------|
| **입술 움직임** | 씹는 리듬/속도 감지 | 1순위 (MVP 핵심) |
| **손/수저 위치** | 얼굴 근처에 손이 오는지 감지 | 2순위 (MVP 포함) |
| **시간 경과** | N초 동안 먹는 행동 없으면 트리거 | 보조 지표 |

#### 2.1.2 입술 움직임 감지
- **기술**: Vision Framework의 Face Landmarks
- **대상**: 입술(lips) 랜드마크 포인트
- **판단 기준**: 입술 포인트 간 거리 변화량, 변화 빈도
- **목표 정확도**: 80% 이상

#### 2.1.3 손/수저 위치 감지
- **기술**: Vision Framework의 Hand Pose Detection
- **판단 기준**: 손(hand)이 얼굴(face) 바운딩 박스 근처에 위치
- **근처 정의**: 얼굴 바운딩 박스 기준 1.5배 영역 내

#### 2.1.4 시간 임계값
- **기본값**: 5초
- **범위**: 1초 ~ 30초 (사용자 설정 가능)
- **동작**: N초간 "먹는 행동" 감지되지 않으면 영상 정지

### 2.2 영상 제어

#### 2.2.1 영상 콘텐츠 소스
| 소스 | 구현 방식 | 우선순위 |
|------|-----------|----------|
| **유튜브** | WKWebView 내재 | 1순위 |
| **사진첩** | PHPickerViewController | 2순위 |
| **로컬 영상** | 사전 다운로드 파일 | 3순위 |

#### 2.2.2 영상 정지 (음의 피드백)
```
상황별 전환 방식:
- 첫 번째 정지: Fade out (부드럽게)
- 반복 정지: 즉시 정지 (인과관계 명확화)
```

#### 2.2.3 영상 재생 (양의 피드백)
```
재생 전환 방식:
- 간단한 칭찬 메시지 표시 (예: "잘하고 있어!")
- 1-2초 후 영상 재생 (Fade in)
```

### 2.3 넛지 시스템

#### 2.3.1 넛지 트리거
- 영상이 정지된 상태에서 활성화

#### 2.3.2 넛지 표시 방식
```
화면 구성:
┌─────────────────────────┐
│                         │
│    [카메라 프리뷰]       │
│    (아이 자신의 얼굴)    │
│                         │
│    ─────────────────    │
│    "밥 먹자!" 메시지     │
│                         │
└─────────────────────────┘
```

#### 2.3.3 넛지 메시지
- **기본 메시지**: "밥 먹자!", "냠냠!", "한 입 더!"
- **커스터마이징**: 설정에서 부모가 직접 수정 가능

### 2.4 부모 제어 기능

#### 2.4.1 필수 버튼
| 버튼 | 기능 | 위치 |
|------|------|------|
| **일시 정지** | 모니터링 일시 중단 (물 마실 때 등) | 화면 상단 |
| **강제 재생** | 감지 무시하고 영상 강제 재생 | 화면 상단 |
| **설정** | 설정 화면으로 이동 | 화면 상단 |

#### 2.4.2 터치 제한
- 식사 중 아이의 터치는 **제한**
- 부모 전용 제어 영역 또는 특정 제스처로만 조작

---

## 3. 화면 구성

### 3.1 메인 화면 (식사 모드)

```
┌─────────────────────────────────────┐
│ [일시정지] [강제재생]        [설정] │  <- 부모 컨트롤 바
├─────────────────────────────────────┤
│                                     │
│                                     │
│                                     │
│         [영상 재생 영역]            │  <- 전체 화면 영상
│         (유튜브/로컬 영상)           │
│                                     │
│                                     │
│                                     │
└─────────────────────────────────────┘

* 카메라 프리뷰: 기본적으로 숨김
* 넛지 발동 시: 영상 대신 카메라 + 메시지 표시
```

### 3.2 영상 선택 화면

```
┌─────────────────────────────────────┐
│ [뒤로]        영상 선택        [완료] │
├─────────────────────────────────────┤
│                                     │
│  [유튜브에서 재생]                   │
│  ─────────────────────────────      │
│  [사진첩에서 선택]                   │
│  ─────────────────────────────      │
│  [저장된 영상]                       │
│    ┌─────┐ ┌─────┐ ┌─────┐         │
│    │썸네일│ │썸네일│ │썸네일│         │
│    └─────┘ └─────┘ └─────┘         │
│                                     │
└─────────────────────────────────────┘
```

### 3.3 설정 화면

```
┌─────────────────────────────────────┐
│ [뒤로]          설정                │
├─────────────────────────────────────┤
│                                     │
│  감지 설정                          │
│  ├─ 민감도        [━━━●━━] 높음    │
│  └─ 대기 시간     [5초 ▼]          │
│                                     │
│  넛지 설정                          │
│  ├─ 메시지 1      [밥 먹자!    ]    │
│  ├─ 메시지 2      [냠냠!      ]    │
│  └─ 메시지 3      [한 입 더!  ]    │
│                                     │
│  통계                               │
│  └─ [식사 기록 보기 >]              │
│                                     │
└─────────────────────────────────────┘
```

### 3.4 통계 화면

```
┌─────────────────────────────────────┐
│ [뒤로]        식사 기록             │
├─────────────────────────────────────┤
│                                     │
│  오늘                               │
│  ├─ 총 식사 시간: 25분              │
│  ├─ 영상 재생: 18분 (72%)           │
│  └─ 중단 횟수: 8회                  │
│                                     │
│  [일별 그래프]                      │
│  │    ▄                            │
│  │ ▄  █  ▄                         │
│  │ █  █  █  ▄                      │
│  └─월─화─수─목─────────────         │
│                                     │
│  최근 7일 평균                      │
│  ├─ 식사 시간: 23분                 │
│  └─ 중단 횟수: 10회                 │
│                                     │
└─────────────────────────────────────┘
```

---

## 4. 기술 아키텍처

### 4.1 전체 구조

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS App                              │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Views     │  │   Services   │  │    Models    │      │
│  │  (SwiftUI)   │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                 │                 │               │
│         ▼                 ▼                 ▼               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   State Management                   │   │
│  │              (ObservableObject / @Published)         │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Vision    │  │   AVFounda  │  │   WebKit     │      │
│  │  Framework   │  │    tion      │  │  (YouTube)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 주요 서비스

#### 4.2.1 VisionService
```swift
protocol VisionServiceProtocol: ObservableObject {
    var isEating: Bool { get }           // 현재 먹는 중인지
    var faceDetected: Bool { get }       // 얼굴 감지 여부
    var handNearFace: Bool { get }       // 손이 얼굴 근처인지
    var lipMovement: Double { get }      // 입술 움직임 정도 (0.0 ~ 1.0)

    func startProcessing()
    func stopProcessing()
    func processFrame(_ pixelBuffer: CVPixelBuffer)
}
```

**구현 세부사항**:
- 프레임 처리: 15fps (60fps 입력에서 스킵)
- 메모리 최적화: CVPixelBufferPool 사용
- 스레드 안전성: DispatchQueue 활용

#### 4.2.2 CameraService
```swift
protocol CameraServiceProtocol: ObservableObject {
    var isRunning: Bool { get }
    var previewLayer: AVCaptureVideoPreviewLayer? { get }

    func startCapture()
    func stopCapture()
    func setFrameDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate)
}
```

**구현 세부사항**:
- 전면 카메라 사용
- 해상도: 720p 권장
- 포커스: 자동

#### 4.2.3 VideoService
```swift
protocol VideoServiceProtocol: ObservableObject {
    var isPlaying: Bool { get }
    var currentSource: VideoSource? { get }

    func play()
    func pause()
    func fadeOut(duration: TimeInterval)
    func fadeIn(duration: TimeInterval)
    func loadVideo(from source: VideoSource)
}

enum VideoSource {
    case youtube(url: URL)
    case photoLibrary(asset: PHAsset)
    case local(url: URL)
}
```

#### 4.2.4 FeedbackService
```swift
protocol FeedbackServiceProtocol: ObservableObject {
    var currentState: FeedbackState { get }
    var nudgeMessage: String { get }

    func evaluateEatingState(_ isEating: Bool)
    func showNudge()
    func hideNudge()
    func showPraise()
}

enum FeedbackState {
    case playing           // 영상 재생 중
    case paused            // 일시 정지 (부모 제어)
    case nudging           // 넛지 표시 중
    case praising          // 칭찬 표시 중
    case waiting           // 먹는 행동 대기 중
}
```

#### 4.2.5 StatisticsService
```swift
protocol StatisticsServiceProtocol: ObservableObject {
    var todayStats: DailyStats { get }
    var weeklyStats: [DailyStats] { get }

    func startSession()
    func endSession()
    func recordPause()
    func recordResume()
}

struct DailyStats: Codable {
    let date: Date
    var totalDuration: TimeInterval      // 총 식사 시간
    var playbackDuration: TimeInterval   // 영상 재생 시간
    var pauseCount: Int                  // 중단 횟수
}
```

### 4.3 데이터 저장

#### 4.3.1 저장 위치
- **로컬 전용**: UserDefaults + FileManager
- **iCloud 동기화 없음**

#### 4.3.2 저장 데이터
```swift
// 설정 데이터
struct AppSettings: Codable {
    var sensitivity: Double          // 0.0 ~ 1.0
    var waitTimeSeconds: Int         // 1 ~ 30
    var nudgeMessages: [String]      // 최대 5개
}

// 통계 데이터
struct SessionHistory: Codable {
    var sessions: [MealSession]
}

struct MealSession: Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let stats: DailyStats
}
```

### 4.4 에러 처리

#### 4.4.1 에러 유형별 대응

| 에러 유형 | 대응 방식 |
|-----------|-----------|
| 얼굴 감지 실패 | 영상 계속 재생 + 재시도 |
| 손 감지 실패 | 입술만으로 판단 (Fallback) |
| 카메라 접근 불가 | 권한 요청 화면 표시 |
| 영상 로드 실패 | 에러 메시지 + 재선택 유도 |
| 유튜브 재생 오류 | 로컬 영상 전환 제안 |

---

## 5. 사용자 흐름

### 5.1 첫 실행

```
앱 실행
    │
    ▼
카메라 권한 요청
    │
    ├─ 허용 → 영상 선택 화면
    │
    └─ 거부 → 권한 필요 안내 → 설정 앱으로 이동
```

### 5.2 식사 세션

```
영상 선택
    │
    ▼
영상 재생 시작 (= 모니터링 시작)
    │
    ▼
┌─────────────────────────────────────┐
│         메인 루프                    │
│  ┌─────────────────────────────┐   │
│  │  먹는 행동 감지?             │   │
│  │      │                      │   │
│  │      ├─ Yes → 영상 계속 재생 │   │
│  │      │                      │   │
│  │      └─ No (5초 경과)        │   │
│  │           │                 │   │
│  │           ▼                 │   │
│  │      영상 정지 + 넛지 표시   │   │
│  │           │                 │   │
│  │           ▼                 │   │
│  │      먹기 시작?             │   │
│  │           │                 │   │
│  │           ├─ Yes → 칭찬 + 재생│  │
│  │           │                 │   │
│  │           └─ No → 넛지 유지  │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
    │
    ▼
영상 종료 또는 부모 종료 버튼
    │
    ▼
세션 통계 저장
```

### 5.3 부모 개입

```
식사 중
    │
    ├─ [일시 정지] 클릭
    │       │
    │       ▼
    │   모니터링 중단 + 영상 정지
    │       │
    │       ▼
    │   [재개] 클릭 → 원래 상태로
    │
    └─ [강제 재생] 클릭
            │
            ▼
        넛지 무시 + 즉시 영상 재생
            │
            ▼
        일정 시간 후 자동으로 모니터링 재개
```

---

## 6. 개발 우선순위

### Phase 1: 핵심 기능 (MVP)
1. **입술 감지 + 영상 제어**
   - Vision Framework 얼굴 랜드마크 감지
   - 입술 움직임 분석 알고리즘
   - 영상 재생/정지 제어

2. **손/얼굴 근접 감지**
   - Hand Pose Detection
   - 얼굴-손 거리 계산

3. **기본 영상 재생**
   - 유튜브 WebView 재생
   - 사진첩 영상 선택

### Phase 2: 피드백 시스템
4. **넛지 시스템**
   - 카메라 프리뷰 표시
   - 메시지 오버레이

5. **부모 제어**
   - 일시 정지/강제 재생 버튼
   - 터치 제한 시스템

### Phase 3: 설정 및 통계
6. **설정 화면**
   - 민감도 조절
   - 시간 임계값 설정
   - 넛지 메시지 커스터마이징

7. **통계 기능**
   - 세션 기록
   - 일별/주별 통계 표시

---

## 7. 기술적 고려사항

### 7.1 성능 요구사항
| 항목 | 목표값 |
|------|--------|
| 프레임 처리율 | 15fps |
| 판단 지연 | < 200ms |
| 메모리 사용 | < 150MB |
| 배터리 | 충전 중 사용 (제약 없음) |

### 7.2 디바이스 환경
- **거리**: 50-80cm
- **조명**: 실내 일반 조명
- **배치**: 테이블 위, 아이 정면
- **충전**: 충전 케이블 연결 상태

### 7.3 알려진 제약사항

#### 7.3.1 유튜브 WebView
- YouTube 정책에 따라 일부 기능 제한 가능
- 광고 스킵 자동화 불가
- Fallback: 로컬 영상 사용

#### 7.3.2 Vision Framework
- 조명 조건에 따라 정확도 변동
- 손 감지는 얼굴 감지보다 정확도 낮음
- Fallback: 입술만으로 판단

### 7.4 테스트 계획
- **초기 테스트**: 1-3끼 식사로 빠른 피드백
- **반복 개선**: 테스트 결과 기반 파라미터 조정

---

## 8. 기존 코드 참고 사항

### 8.1 참고할 파일
- `BobCamAgent/VisionService.swift`: Vision 처리 기본 구조
- `BobCamAgent/CameraService.swift`: 카메라 캡처 구조
- `BobCamAgent/VideoService.swift`: 영상 재생 구조

### 8.2 주의사항
- 기존 코드는 **안정성이 낮음**
- 구조와 아이디어만 참고
- 알고리즘과 상태 관리는 **새로 설계**

---

## 9. 파일 구조 (권장)

```
BobCamAgent/
├── App/
│   ├── BobCamAgentApp.swift
│   └── AppDelegate.swift
│
├── Views/
│   ├── MainView.swift              # 메인 식사 화면
│   ├── VideoSelectionView.swift    # 영상 선택
│   ├── SettingsView.swift          # 설정
│   ├── StatisticsView.swift        # 통계
│   └── Components/
│       ├── NudgeOverlay.swift      # 넛지 오버레이
│       ├── PraiseOverlay.swift     # 칭찬 오버레이
│       ├── ParentControlBar.swift  # 부모 제어 바
│       └── CameraPreview.swift     # 카메라 프리뷰
│
├── Services/
│   ├── VisionService.swift         # 얼굴/손 감지
│   ├── CameraService.swift         # 카메라 캡처
│   ├── VideoService.swift          # 영상 재생
│   ├── FeedbackService.swift       # 피드백 로직
│   └── StatisticsService.swift     # 통계 관리
│
├── Models/
│   ├── AppSettings.swift           # 설정 모델
│   ├── MealSession.swift           # 세션 모델
│   ├── FeedbackState.swift         # 상태 모델
│   └── VideoSource.swift           # 영상 소스 모델
│
├── Utilities/
│   ├── Constants.swift             # 상수 정의
│   ├── Extensions/                 # Swift 확장
│   └── Helpers/                    # 유틸리티 함수
│
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── Info.plist
```

---

## 10. 수락 기준 (Acceptance Criteria)

### 10.1 MVP 완료 기준
- [ ] 카메라로 아이 얼굴 인식
- [ ] 입술 움직임으로 "먹는 중" 판단
- [ ] 손이 얼굴 근처에 오면 "먹는 중" 판단
- [ ] 5초간 안 먹으면 영상 정지
- [ ] 넛지 화면 표시 (카메라 + 메시지)
- [ ] 먹기 시작하면 칭찬 + 영상 재생
- [ ] 유튜브 또는 로컬 영상 재생
- [ ] 사진첩에서 영상 선택
- [ ] 일시 정지/강제 재생 버튼 동작
- [ ] 설정에서 민감도/시간 조절 가능
- [ ] 식사 통계 기록 및 표시

### 10.2 품질 기준
- [ ] 감지 정확도 80% 이상
- [ ] 앱 크래시 없음
- [ ] 30분 이상 연속 사용 가능
- [ ] 메모리 누수 없음

---

## 부록 A: 용어 정의

| 용어 | 정의 |
|------|------|
| **먹는 행동** | 입술 움직임 또는 손이 얼굴 근처에 있는 상태 |
| **넛지** | 밥 먹도록 유도하는 시각적 피드백 |
| **세션** | 영상 선택부터 종료까지의 한 끼 식사 |
| **민감도** | 입술 움직임 감지 임계값 조절 파라미터 |
| **대기 시간** | 먹는 행동 없이 기다리는 최대 시간 |

---

## 부록 B: 설정 기본값

```swift
extension AppSettings {
    static let defaultSettings = AppSettings(
        sensitivity: 0.5,           // 중간 민감도
        waitTimeSeconds: 5,         // 5초 대기
        nudgeMessages: [
            "밥 먹자!",
            "냠냠!",
            "한 입 더!"
        ]
    )
}
```

---

**문서 끝**
