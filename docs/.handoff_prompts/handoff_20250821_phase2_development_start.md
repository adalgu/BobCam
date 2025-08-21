
@Actor: claude-code

@Goal: BobCam-iOS 앱의 Phase 2 개발을 완료하고, 실제 사용 및 앱 스토어 출시를 위한 최종 준비를 마칩니다. 핵심 목표는 립 감지 알고리즘의 정확도를 70% 이상으로 끌어올리고, 사용자 편의 기능을 구현하는 것입니다.

@Current-Progress:
- **아키텍처 리팩토링 완료**: 핵심 로직을 `OptimizedLipDetectionService`로 분리하고, EMA 스무딩 및 `CircularBuffer`를 이용한 고급 알고리즘을 적용했습니다.
- **모니터링 시스템 통합**: `AccuracyMonitor`와 `PerformanceMonitor`를 통합하여 FPS, 처리 시간, IoU, Jitter 등 핵심 지표를 실시간으로 측정할 수 있는 기반을 마련했습니다.
- **사용자 인터페이스 개선**: 사용자가 직접 감지 민감도를 조절하고, 수동으로 비디오 재생을 제어할 수 있는 `StatusBar`를 구현했습니다.
- **기본 통합 테스트 통과**: `Phase2ValidationTest`를 통해 새로운 모듈들이 구조적으로 올바르게 통합되었음을 확인했습니다.

@Next-Steps:

1.  **알고리즘 튜닝 및 정확도 70% 달성 (가장 중요)**
    -   **테스트 환경 구축**: 사전 녹화된 비디오 파일을 사용하여 앱의 감지 로직을 테스트할 수 있는 테스트 하네스를 구축합니다.
    -   **데이터 수집 및 레이블링**: 다양한 아이들의 식사 영상을 확보하고, 각 프레임별로 실제 식사 여부(Ground Truth)를 수동으로 레이블링합니다.
    -   **파라미터 최적화**: `LipDetectionConfiguration`에 정의된 파라미터들(`historySize`, `eatingPatternThreshold`, `emaAlpha` 등)을 체계적으로 조정하며, Ground Truth 데이터와 비교하여 정확도를 70% 이상으로 끌어올립니다.
    -   **디버그 UI 구현**: 튜닝 과정을 시각적으로 확인하기 위해, 실시간으로 입술 랜드마크, 계산된 거리, 버퍼 상태 등을 화면에 오버레이하는 디버그 모드를 구현합니다.

2.  **사용자 비디오 선택 기능 구현**
    -   현재 하드코딩된 `sample_video.mp4`를 실제 사용자 비디오로 대체합니다.
    -   `PHPickerViewController`를 사용하여 사용자가 자신의 사진 보관함에서 비디오를 선택할 수 있는 기능을 구현합니다.
    -   선택된 비디오는 `UserDefaults` 등을 통해 저장하여, 다음 앱 실행 시 기본 비디오로 사용되도록 합니다.
    -   `VideoService`가 선택된 비디오 URL을 처리할 수 있도록 로직을 수정합니다.

3.  **설정 화면 구현**
    -   현재 플레이스홀더 상태인 `SettingsView`를 실제 기능이 동작하도록 구현합니다.
    -   주요 설정 항목:
        -   기본 재생 비디오 변경 기능
        -   앱 정보 및 개인정보처리방침 안내
        -   디버그 모드 활성화/비활성화 토글 (개발자용)

4.  **최종 폴리싱 및 테스트**
    -   앱의 전반적인 UI/UX를 점검하고 다듬습니다.
    -   권한 변경, 비디오 로딩 실패 등 다양한 예외 상황에 대한 처리가 안정적으로 동작하는지 테스트합니다.
    -   앱 내 모든 사용자 안내 문구를 최종 검토합니다.

@File-Context:
- `BobCam-iOS/VisionService.swift`: 핵심 서비스 로직 및 모니터링 델리게이트
- `BobCam-iOS/LipDetectionImproved.swift`: 튜닝해야 할 핵심 알고리즘
- `BobCam-iOS/ContentView.swift`: 메인 뷰 및 서비스 통합
- `BobCam-iOS/VideoService.swift`: 비디오 선택 기능 추가 필요
- `BobCam-iOS/StatusBar.swift`: 사용자 컨트롤 UI
- `BobCam-iOS/SettingsView.swift`: 구현이 필요한 설정 화면
- `docs/iOS-Development-TODO.md`: 기존 TODO 리스트 참고

@Acceptance-Criteria:
- 립 감지 알고리즘이 다양한 테스트 비디오에서 70% 이상의 평균 정확도를 기록함.
- 사용자가 사진 보관함에서 비디오를 선택하고, 이를 기본 비디오로 설정할 수 있음.
- 디버그 모드에서 실시간 성능/정확도 지표가 화면에 표시됨.
- 설정 화면의 모든 기능이 정상적으로 동작함.
- 앱이 안정적이며, 앱 스토어에 제출할 수 있는 수준의 완성도를 갖춤.

@Action:
위 내용을 바탕으로, `@Next-Steps`에 명시된 작업들을 완료하기 위한 구체적이고 단계적인 개발 계획을 제시해 주세요.
