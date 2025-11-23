# BobCam 개발 가이드 및 개선 로드맵

> 업데이트: 2025년 6월 8일  
> 현재 버전: v2 (main_stable.py 기준)

## 🏗️ 현재 시스템 아키텍처

### 코드 구조
```
Bob-Cam-New/
├── main_stable.py          # 안정 버전 (현재 운영)
├── main.py                 # 실험 버전
├── dev/                    # 개발 중인 기능들
│   ├── YOLO.py            # 객체 감지 실험
│   ├── yolov8n.pt         # YOLO 모델 파일
│   └── yolov10n.pt        # 최신 YOLO 모델
├── docs/research/         # 연구 문서
└── src/                   # 소스 코드 모듈
```

### 현재 감지 로직 (EatingStatus 클래스)
```python
# 핵심 파라미터
MOUTH_OPEN_THRESHOLD = 0.02      # 입 열림 임계값
HEIGHT_STD_THRESHOLD = 0.03      # 입 높이 변화 임계값  
RATIO_STD_THRESHOLD = 0.02       # 입 비율 변화 임계값
NO_EATING_TIMEOUT = 60           # 비식사 판단 시간 (2초)
EATING_CONFIRM_COUNT = 15        # 식사 확인 카운트 (0.5초)
```

### 감지 방식
1. **입술 랜드마크**: 상순(13), 하순(14), 입꼬리(61, 291)
2. **계산 지표**: 높이, 너비, 종횡비
3. **움직임 감지**: 표준편차 기반 변화량 측정
4. **시간적 필터링**: Hysteresis 적용

## 🎯 개선 목표

### 1. 감지 정확도 향상
- **현재**: ~75% (입술 움직임만)
- **목표**: ~92% (턱 + 식기구 + 입술 복합)

### 2. 놓치는 케이스 해결
- ❌ 입 다물고 턱으로만 씹기
- ❌ 미세한 턱 움직임
- ❌ 식기구 사용 중 일시적 멈춤

### 3. 오탐(False Positive) 감소
- ❌ 말하기, 하품, 음료 섭취
- ❌ 얼굴 움직임으로 인한 노이즈

## 🚀 단계별 개선 계획

### Phase 1: 턱 움직임 감지 (1주차)

#### 1.1 추가할 턱 랜드마크
```python
# MediaPipe FaceMesh 턱 포인트
JAW_LANDMARKS = {
    'lower_jaw': [172, 136, 150, 149, 176, 148, 152],
    'jaw_line': [377, 400, 378, 379, 365, 397, 288, 361, 323],
    'chin_tip': [175, 199, 428]  # 턱 끝점
}
```

#### 1.2 구현할 기능
```python
class AdvancedEatingStatus(EatingStatus):
    def __init__(self):
        super().__init__()
        self.jaw_height_history = deque(maxlen=60)
        self.jaw_width_history = deque(maxlen=60)
        
    def calculate_jaw_features(self, landmarks):
        # 턱 높이 (턱끝 - 입술 중앙) 거리
        # 턱 너비 (좌우 턱선) 거리
        # 턱 각도 변화
        pass
        
    def detect_chewing_pattern(self):
        # 0.5-3Hz 주파수 필터링
        # 리듬감 있는 턱 움직임 감지
        pass
```

#### 1.3 통합 로직
```python
def detect_eating_behavior(self, mouth_height, mouth_ratio):
    # 기존 입술 감지
    lip_states = super().detect_eating_behavior(mouth_height, mouth_ratio)
    
    # 새로운 턱 감지
    jaw_states = self.detect_jaw_movement()
    
    # 복합 판단
    final_eating = (
        lip_states['movement_state'] == '움직임' or
        jaw_states['chewing_detected'] == True
    )
    
    return {
        'is_eating': final_eating,
        'confidence': self.calculate_confidence(lip_states, jaw_states)
    }
```

### Phase 2: 식기구 감지 (2-3주차)

#### 2.1 YOLO 모델 통합
```python
class UtentsilDetector:
    def __init__(self):
        # dev/yolov8n.pt 활용
        self.model = YOLO('./dev/yolov8n.pt')
        self.target_classes = ['fork', 'knife', 'spoon']  # COCO 클래스
        
    def detect_near_mouth(self, frame, mouth_landmarks):
        # 입 중심 기준 ROI 설정 (반경 100px)
        mouth_center = self.get_mouth_center(mouth_landmarks)
        roi = self.create_roi(frame, mouth_center, radius=100)
        
        # ROI에서만 식기구 감지 (성능 최적화)
        detections = self.model(roi)
        return self.filter_utensils(detections)
```

#### 2.2 젓가락 감지 (커스텀 필요)
```python
# 젓가락은 COCO 데이터셋에 없으므로 별도 처리 필요
class ChopsticksDetector:
    def detect_chopsticks(self, frame, hand_landmarks):
        # 손 랜드마크에서 손가락 끝 감지
        # 두 개의 평행한 선형 객체 탐지
        # 입 근처 위치 확인
        pass
```

#### 2.3 통합 판단 로직
```python
def comprehensive_eating_detection(self, lip_status, jaw_status, utensil_status):
    confidence_factors = {
        'utensil_near_mouth': utensil_status.distance < 50,  # 50px 이내
        'rhythmic_jaw': jaw_status.rhythm_score > 0.7,
        'lip_movement': lip_status.movement_intensity > 0.5
    }
    
    # 우선순위 기반 판단
    if confidence_factors['utensil_near_mouth']:
        if confidence_factors['rhythmic_jaw'] or confidence_factors['lip_movement']:
            return True, 0.95  # 매우 높은 신뢰도
    
    # 식기구 없어도 턱 움직임이 확실하면
    if confidence_factors['rhythmic_jaw'] and confidence_factors['lip_movement']:
        return True, 0.8
        
    return False, 0.0
```

### Phase 3: 성능 최적화 (4주차)

#### 3.1 멀티스레딩 개선
```python
class OptimizedEatingMonitor:
    def __init__(self):
        self.frame_queue = queue.Queue(maxsize=3)
        self.face_queue = queue.Queue(maxsize=2)
        self.utensil_queue = queue.Queue(maxsize=1)
        
    def start_detection_threads(self):
        # Thread 1: 고속 얼굴 감지 (30 FPS)
        threading.Thread(target=self.face_detection_loop).start()
        
        # Thread 2: 저속 식기구 감지 (10 FPS)  
        threading.Thread(target=self.utensil_detection_loop).start()
        
        # Thread 3: 신호 처리 및 판단
        threading.Thread(target=self.signal_processing_loop).start()
```

#### 3.2 메모리 최적화
```python
# 순환 버퍼 사용으로 메모리 사용량 제한
class CircularBuffer:
    def __init__(self, size=180):  # 6초간 데이터 (30 FPS)
        self.buffer = np.zeros(size)
        self.size = size
        self.index = 0
        
    def push(self, value):
        self.buffer[self.index] = value
        self.index = (self.index + 1) % self.size
```

### Phase 4: 모바일 포팅 준비 (5-8주차)

#### 4.1 크로스 플랫폼 옵션 분석
1. **Flutter + MediaPipe**: 
   - 장점: 단일 코드베이스, 높은 성능
   - 단점: MediaPipe Flutter 플러그인 제한적
   
2. **React Native + MLKit**:
   - 장점: 네이티브 성능, 플랫폼별 최적화
   - 단점: 플랫폼별 개발 필요
   
3. **Kivy (Python 기반)**:
   - 장점: 현재 코드 재사용 가능
   - 단점: 성능 제약, 앱스토어 배포 복잡

#### 4.2 성능 벤치마킹
```python
# 모바일 대응 성능 목표
MOBILE_PERFORMANCE_TARGETS = {
    'fps': 30,                    # 초당 프레임
    'latency_ms': 50,            # 지연시간
    'memory_mb': 100,            # 메모리 사용량
    'battery_per_hour': 20,      # 시간당 배터리 소모율
    'cpu_usage': 30              # CPU 사용률
}
```

## 🧪 테스트 계획

### 1. 정확도 테스트
```python
# 테스트 시나리오
test_scenarios = [
    "normal_eating_spoon",      # 일반적인 숟가락 식사
    "closed_mouth_chewing",     # 입 다물고 씹기
    "talking_while_eating",     # 식사 중 대화
    "drinking_water",           # 물 마시기
    "yawning",                  # 하품
    "phone_call_gesture"        # 전화하는 제스처
]
```

### 2. 성능 테스트
```python
# 프로파일링 코드
import cProfile
import time

def performance_test():
    start_time = time.time()
    # 감지 로직 실행
    end_time = time.time()
    
    print(f"Processing time: {(end_time - start_time) * 1000:.2f}ms")
    print(f"FPS: {1 / (end_time - start_time):.1f}")
```

## 📊 예상 개선 효과

### 정확도 개선
| 시나리오 | 현재 (입술만) | Phase 1 (턱 추가) | Phase 2 (식기구 추가) |
|----------|---------------|-------------------|----------------------|
| 일반 식사 | 85% | 92% | **96%** |
| 입 다물고 씹기 | 30% | 80% | **85%** |
| 식사 중 대화 | 60% | 75% | **88%** |
| 전체 평균 | 75% | 85% | **92%** |

### 성능 영향
- CPU 사용량: +15% (턱 감지) + 10% (식기구 감지)
- 메모리: +20MB (YOLO 모델 로딩)
- 배터리: 모바일에서 시간당 +5% 추가 소모 예상

## 🔧 개발 환경 설정

### 필요 라이브러리 추가
```bash
# requirements 업데이트
pip install ultralytics  # YOLO
pip install scipy        # 신호 처리
pip install scikit-learn # 머신러닝 유틸
```

### 개발 브랜치 전략
```bash
# feature 브랜치 생성
git checkout -b feature/jaw-detection
git checkout -b feature/utensil-detection  
git checkout -b feature/mobile-optimization
```

## 📝 다음 액션 아이템

### 즉시 시작 가능 (이번 주)
1. [ ] `AdvancedEatingStatus` 클래스 구현
2. [ ] 턱 랜드마크 포인트 추가 
3. [ ] 기본 턱 움직임 감지 로직 구현

### 단기 목표 (1-2주)
1. [ ] YOLO 모델 통합 테스트
2. [ ] 식기구 감지 ROI 설정
3. [ ] 복합 판단 로직 구현

### 중기 목표 (1개월)
1. [ ] 전체 시스템 통합 테스트
2. [ ] 성능 최적화 및 튜닝
3. [ ] 사용자 테스트 및 피드백 수집

---

**다음 업데이트**: 실제 구현 결과 및 성능 측정 데이터 추가 예정
