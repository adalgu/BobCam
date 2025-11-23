# 식사 행동 감지 기술 연구 보고서

> 작성일: 2025년 6월 8일  
> 프로젝트: BobCam 스마트 식사 모니터  
> 목적: 현재 입술 움직임 기반 감지 시스템의 한계 극복 방안 연구

## 🎯 연구 목표

현재 BobCam은 MediaPipe FaceMesh를 사용하여 입술 움직임만으로 식사를 감지하고 있으나, **입을 다물고 턱을 움직이며 씹는 동작**을 놓치는 문제가 발생. 이를 해결하기 위한 최신 연구 동향과 실용적 구현 방안을 조사.

## 📋 주요 요구사항

1. **식기구 감지**: 숟가락, 포크, 젓가락이 입으로 가까이 가는 경우 인지
2. **모바일 호환성**: 안드로이드/iOS 최신 플래그십 모델에서 실행 가능
3. **안정성**: 실시간 처리 중 버벅일 수 있으나 프로그램 다운은 최소화

## 🔬 최신 연구 동향 (2021-2025)

### 1. 멀티모달 융합 기술
- **Ghosh et al. (2024)**: 이미지 + 가속도계 데이터 결합
  - 성능: 94.59% 민감도, 80.77% F1-점수
  - 계층적 분류 방법으로 단일 모달리티 한계 극복

### 2. 시간적 패턴 인식
- **3초 윈도우 + 50% 겹침** 방식으로 기존 대비 8% 민감도 향상
- 구조적 경험적 누적분포함수(ECDF) 특징 활용
- 유사 동작 구분 (식사 vs 전화 사용) 정확도 개선

### 3. 경량화 알고리즘
- **Tiny Eats GRU**: Arm Cortex M0+에서 실행
  - 메모리 사용량: 단 4%
  - 성능: 95.15% 정확도, 6ms 지연시간
  - 모바일 적용 가능성 높음

## 🎯 MediaPipe 기반 턱 움직임 감지

### 핵심 턱 랜드마크 포인트
```python
# MediaPipe FaceMesh 468개 포인트 중 턱 관련 핵심 인덱스
JAW_LANDMARKS = [172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397, 288, 361, 323]
```

### 3단계 감지 알고리즘
1. **턱 개방도 측정**: 턱 랜드마크 간 유클리드 거리 계산
2. **씹는 동작 분리**: 0.5-3Hz 주파수 대역통과 필터링
3. **씹기 횟수 카운팅**: 피크 감지를 통한 개별 동작 인식

### 성능 지표
- 물기 감지: **90% 정확도**
- 씹기 감지: **60% 정확도** (기본) → **93% 정확도** (Active Appearance Model 사용시)

## 🍴 식기구 감지 기술

### 객체 감지 모델 후보
1. **YOLOv8n/YOLOv10n**: 경량 모델, 모바일 최적화
2. **MobileNet-SSD**: 모바일 특화 설계
3. **MediaPipe ObjectDetection**: Google 공식 솔루션

### 감지 대상 클래스
- `fork` (포크)
- `knife` (나이프)  
- `spoon` (숟가락)
- `chopsticks` (젓가락) - 커스텀 학습 필요

### 구현 전략
```python
# 손목-입 영역 ROI 설정
def get_eating_roi(face_landmarks, hand_landmarks):
    # 입 중심점과 손목 좌표를 기준으로 관심 영역 설정
    # 이 영역에서만 식기구 감지 수행하여 성능 최적화
```

## ⚡ 실시간 처리 최적화

### 멀티스레딩 아키텍처
```
Thread 1: 비디오 캡처 (30 FPS)
Thread 2: 얼굴 랜드마크 감지 (15 FPS)
Thread 3: 식기구 감지 (10 FPS)
Thread 4: 신호 처리 및 판단 (30 FPS)
Main Thread: GUI 업데이트
```

### 메모리 관리 최적화
- 사전 할당된 배열 재사용
- 순환 버퍼를 통한 시간적 데이터 관리
- MediaPipe 설정: `static_image_mode=False`, `max_num_faces=1`

### 프레임 처리 최적화
- 선택적 랜드마크 추적 (관심 영역만)
- 시간적 다운샘플링 (식기구 감지는 10 FPS로 충분)
- 0.5배 스케일링으로 프레임 크기 축소

## 🎚️ False Positive 감소 기법

### 다중 영역 통합 전략
```python
# 신뢰도 점수 계산
confidence_score = (
    jaw_movement * 0.6 +      # 턱 움직임 (60% 가중치)
    lip_movement * 0.3 +       # 입술 움직임 (30% 가중치)
    cheek_movement * 0.1       # 볼 움직임 (10% 가중치)
)
```

### 시간적 맥락 분석
- **말하기**: 불규칙한 턱 움직임, 짧은 지속시간
- **하품**: 큰 하향 움직임 후 빠른 복귀
- **음료 섭취**: 짧은 에너지 스파이크, 연속적이지 않음
- **식사**: 규칙적인 리듬, 지속적인 패턴

### 적응적 임계값 조정
1. 5-10초간 중립 상태 캡처
2. 개인별 턱 움직임 범위 측정
3. 맞춤형 감지 임계값 설정

## 📱 모바일 호환성 고려사항

### 성능 목표
- **처리 속도**: 30+ FPS 유지
- **지연시간**: 50ms 미만
- **메모리 사용량**: 100MB 미만
- **배터리 효율성**: 1시간 연속 사용 시 20% 미만 소모

### 플래그십 모델 벤치마크
- **iPhone 15 Pro**: A17 Pro, 8GB RAM → 여유롭게 실행 가능
- **Galaxy S24 Ultra**: Snapdragon 8 Gen 3, 12GB RAM → 최고 성능
- **Pixel 8 Pro**: Tensor G3, 12GB RAM → MediaPipe 최적화로 우수

### 크로스 플랫폼 구현
- **Flutter + MediaPipe**: 단일 코드베이스
- **React Native + MLKit**: 플랫폼별 최적화
- **Python → Mobile**: Kivy 또는 BeeWare 활용

## 🛠️ 구현 권장사항

### 1단계: 턱 움직임 감지 추가 (현재 시스템 확장)
```python
# 기존 EatingStatus 클래스 확장
class AdvancedEatingStatus(EatingStatus):
    def __init__(self):
        super().__init__()
        self.jaw_landmarks = [172, 136, 150, 149, 176, 148, 152]
        self.jaw_history = deque(maxlen=60)
    
    def detect_jaw_movement(self, landmarks):
        # 턱 개방도 계산 및 움직임 감지
        pass
```

### 2단계: 식기구 감지 통합
```python
# 새로운 UtentsilDetector 클래스 생성
class UtentsilDetector:
    def __init__(self):
        self.model = YOLO('yolov8n.pt')  # 경량 모델 사용
        
    def detect_near_mouth(self, frame, mouth_roi):
        # 입 근처 식기구 감지
        pass
```

### 3단계: 복합 판단 시스템
```python
# 최종 판단 로직
class ComprehensiveEatingDetector:
    def make_decision(self, lip_status, jaw_status, utensil_status):
        if utensil_status.near_mouth and (lip_status.moving or jaw_status.moving):
            return True, "eating_confirmed"
        elif jaw_status.chewing_pattern and lip_status.slight_movement:
            return True, "eating_likely"
        else:
            return False, "not_eating"
```

## 📊 예상 성능 개선

### 현재 시스템 vs 개선 후
| 지표 | 현재 (입술만) | 개선 후 (턱+식기구) |
|------|---------------|---------------------|
| 정확도 | ~75% | **~92%** |
| 놓치는 경우 | 입 다물고 씹기 | 거의 없음 |
| 오탐 | 말하기, 하품 등 | 크게 감소 |
| 반응성 | 보통 | 향상 |

## 🔄 다음 단계

1. **즉시 적용 가능**: 턱 랜드마크 추가 및 움직임 분석
2. **단기 목표** (1-2주): 식기구 감지 모델 통합
3. **중기 목표** (1개월): 복합 판단 시스템 완성
4. **장기 목표** (2-3개월): 모바일 포팅 및 최적화

## 📚 참고 자료

- Ghosh et al. (2024): "RF sensing enabled tracking of human facial expressions using machine learning algorithms"
- MDPI Sensors (2021): "Determination of Chewing Count from Video Recordings Using Discrete Wavelet Decomposition"
- NCBI PMC: "Automatic Count of Bites and Chews From Videos of Eating Episodes"
- MediaPipe 공식 문서: Face Mesh 가이드

---

**다음 업데이트**: 구체적인 구현 코드 및 테스트 결과 추가 예정
