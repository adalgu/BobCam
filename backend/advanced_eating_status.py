import numpy as np
from collections import deque
import time
from typing import Dict, Tuple, List, Optional


class AdvancedEatingStatus:
    """
    입술 + 턱 움직임을 복합적으로 분석하여 식사 상태를 감지하는 고급 클래스.
    기존 EatingStatus의 기능을 모두 포함하면서 턱 움직임 감지를 추가합니다.
    """

    def __init__(self):
        # === 기존 입술 감지 설정 ===
        self.MOUTH_OPEN_THRESHOLD = 0.02  # 입이 열렸다고 판단하는 높이 임계값
        self.HEIGHT_STD_THRESHOLD = 0.03  # 입 높이 변화(움직임) 임계값
        self.RATIO_STD_THRESHOLD = 0.02  # 입 비율 변화(움직임) 임계값
        
        # === 새로운 턱 감지 설정 ===
        self.JAW_HEIGHT_STD_THRESHOLD = 0.015  # 턱 높이 변화 임계값
        self.JAW_WIDTH_STD_THRESHOLD = 0.01   # 턱 너비 변화 임계값
        self.CHEWING_FREQUENCY_MIN = 0.5       # 씹기 동작 최소 주파수 (Hz)
        self.CHEWING_FREQUENCY_MAX = 3.0       # 씹기 동작 최대 주파수 (Hz)
        
        # === 타이밍 설정 ===
        self.NO_EATING_TIMEOUT = 60  # 2초 (30fps * 2)
        self.EATING_CONFIRM_COUNT = 15  # 0.5초 (30fps * 0.5)
        
        # === 상태 변수 ===
        # 기존 입술 데이터
        self.height_history = deque(maxlen=60)  # 2초간의 입 높이 데이터
        self.ratio_history = deque(maxlen=60)   # 2초간의 입 비율 데이터
        
        # 새로운 턱 데이터
        self.jaw_height_history = deque(maxlen=60)  # 2초간의 턱 높이 데이터
        self.jaw_width_history = deque(maxlen=60)   # 2초간의 턱 너비 데이터
        self.jaw_angle_history = deque(maxlen=60)   # 2초간의 턱 각도 데이터
        
        # 감지 상태
        self.is_eating = False
        self.last_eating_time = time.time()
        self.eating_counter = 0
        self.not_eating_counter = 0
        self.consecutive_eating_sessions = 0
        
        # 디버그용 추가 정보
        self.last_confidence = 0.0
        self.detection_method = "none"  # "lips", "jaw", "combined"
        
        # MediaPipe 턱 랜드마크 인덱스 (연구에서 찾은 핵심 포인트들)
        self.JAW_LANDMARKS = {
            'lower_jaw': [172, 136, 150, 149, 176, 148, 152],
            'jaw_line': [377, 400, 378, 379, 365, 397, 288, 361, 323],
            'chin_tip': [175, 199, 428]
        }

    def calculate_mouth_features(self, landmarks) -> Tuple[float, float, float]:
        """기존 입술 특징 계산 (호환성 유지)"""
        try:
            # Key landmarks for mouth
            upper_lip = landmarks[13]
            lower_lip = landmarks[14]
            left_corner = landmarks[61]
            right_corner = landmarks[291]

            # Calculate height, width, and aspect ratio
            height = abs(upper_lip.y - lower_lip.y)
            width = abs(right_corner.x - left_corner.x)

            # Avoid division by zero
            aspect_ratio = height / width if width > 0.01 else 0.0

            return height, width, aspect_ratio
        except Exception:
            return 0.0, 0.0, 0.0

    def calculate_jaw_features(self, landmarks) -> Tuple[float, float, float]:
        """새로운 턱 특징 계산"""
        try:
            # 턱끝과 입술 중앙 간의 거리 (턱 높이)
            chin_tip = landmarks[175]  # 턱끝
            mouth_center_y = (landmarks[13].y + landmarks[14].y) / 2  # 입 중앙
            jaw_height = abs(chin_tip.y - mouth_center_y)
            
            # 좌우 턱선 너비
            left_jaw = landmarks[172]
            right_jaw = landmarks[397]
            jaw_width = abs(right_jaw.x - left_jaw.x)
            
            # 턱 각도 (턱끝에서 양쪽 턱선으로의 각도)
            # 벡터 계산을 통한 턱 개방 각도
            left_vector = np.array([left_jaw.x - chin_tip.x, left_jaw.y - chin_tip.y])
            right_vector = np.array([right_jaw.x - chin_tip.x, right_jaw.y - chin_tip.y])
            
            # 두 벡터 사이의 각도 계산
            cos_angle = np.dot(left_vector, right_vector) / (
                np.linalg.norm(left_vector) * np.linalg.norm(right_vector) + 1e-8
            )
            jaw_angle = np.arccos(np.clip(cos_angle, -1.0, 1.0))
            
            return jaw_height, jaw_width, jaw_angle
            
        except Exception as e:
            return 0.0, 0.0, 0.0

    def detect_chewing_pattern(self) -> Dict[str, any]:
        """턱 움직임에서 씹기 패턴 감지"""
        if len(self.jaw_height_history) < self.jaw_height_history.maxlen:
            return {"detected": False, "rhythm_score": 0.0, "frequency": 0.0}
        
        try:
            # 턱 높이 데이터를 numpy 배열로 변환
            jaw_data = np.array(self.jaw_height_history)
            
            # FFT를 사용한 주파수 분석
            fft = np.fft.fft(jaw_data)
            freqs = np.fft.fftfreq(len(jaw_data), d=1/30.0)  # 30 FPS 가정
            
            # 씹기 주파수 대역 (0.5-3Hz) 에너지 계산
            chewing_mask = (freqs >= self.CHEWING_FREQUENCY_MIN) & (freqs <= self.CHEWING_FREQUENCY_MAX)
            chewing_energy = np.sum(np.abs(fft[chewing_mask]))
            total_energy = np.sum(np.abs(fft)) + 1e-8
            
            # 리듬 점수 계산 (0-1 범위)
            rhythm_score = min(chewing_energy / total_energy * 3.0, 1.0)
            
            # 주요 주파수 찾기
            max_freq_idx = np.argmax(np.abs(fft[chewing_mask]))
            dominant_frequency = freqs[chewing_mask][max_freq_idx] if len(freqs[chewing_mask]) > 0 else 0.0
            
            # 씹기 패턴 감지 판단
            chewing_detected = rhythm_score > 0.3 and abs(dominant_frequency) > 0.5
            
            return {
                "detected": chewing_detected,
                "rhythm_score": rhythm_score,
                "frequency": abs(dominant_frequency)
            }
            
        except Exception as e:
            return {"detected": False, "rhythm_score": 0.0, "frequency": 0.0}

    def detect_eating_behavior(self, mouth_height: float, mouth_aspect_ratio: float, 
                             landmarks=None) -> Dict[str, any]:
        """
        통합 식사 감지 (입술 + 턱 복합 분석)
        """
        # 기존 입술 데이터 추가
        self.height_history.append(mouth_height)
        self.ratio_history.append(mouth_aspect_ratio)
        
        # 턱 데이터 계산 및 추가 (랜드마크가 제공된 경우)
        if landmarks is not None:
            jaw_height, jaw_width, jaw_angle = self.calculate_jaw_features(landmarks)
            self.jaw_height_history.append(jaw_height)
            self.jaw_width_history.append(jaw_width)
            self.jaw_angle_history.append(jaw_angle)
        
        # 기본 상태 설정
        states = {
            "is_eating": self.is_eating,
            "mouth_state": "닫힘",
            "movement_state": "멈춤",
            "jaw_state": "정적",
            "confidence": 0.0,
            "detection_method": "none"
        }

        if len(self.height_history) < self.height_history.maxlen:
            return states  # 데이터가 충분히 쌓일 때까지 대기

        # === 1. 입 열림/닫힘 상태 결정 ===
        if mouth_height > self.MOUTH_OPEN_THRESHOLD:
            states["mouth_state"] = "열림"

        # === 2. 입술 움직임 감지 ===
        height_std = np.std(self.height_history)
        ratio_std = np.std(self.ratio_history)
        
        lips_moving = (height_std > self.HEIGHT_STD_THRESHOLD or 
                      ratio_std > self.RATIO_STD_THRESHOLD)
        
        if lips_moving:
            states["movement_state"] = "움직임"

        # === 3. 턱 움직임 감지 ===
        jaw_movement_detected = False
        chewing_info = {"detected": False, "rhythm_score": 0.0}
        
        if landmarks is not None and len(self.jaw_height_history) >= self.jaw_height_history.maxlen:
            # 턱 움직임 표준편차 계산
            jaw_height_std = np.std(self.jaw_height_history)
            jaw_width_std = np.std(self.jaw_width_history)
            
            # 턱 움직임 기본 감지
            jaw_movement_detected = (jaw_height_std > self.JAW_HEIGHT_STD_THRESHOLD or 
                                   jaw_width_std > self.JAW_WIDTH_STD_THRESHOLD)
            
            # 씹기 패턴 감지
            chewing_info = self.detect_chewing_pattern()
            
            if jaw_movement_detected or chewing_info["detected"]:
                states["jaw_state"] = "움직임"

        # === 4. 통합 판단 및 신뢰도 계산 ===
        confidence_factors = {
            'lips_moving': lips_moving,
            'jaw_moving': jaw_movement_detected,
            'chewing_pattern': chewing_info["detected"],
            'rhythm_score': chewing_info.get("rhythm_score", 0.0)
        }
        
        # 가중치 기반 신뢰도 계산
        confidence = 0.0
        detection_method = "none"
        
        if confidence_factors['chewing_pattern'] and confidence_factors['lips_moving']:
            # 가장 확실한 경우: 입술 + 씹기 패턴
            confidence = 0.95
            detection_method = "combined"
            eating_detected = True
        elif confidence_factors['chewing_pattern']:
            # 씹기 패턴만 확실한 경우
            confidence = 0.8
            detection_method = "jaw"
            eating_detected = True
        elif confidence_factors['lips_moving'] and confidence_factors['jaw_moving']:
            # 입술 + 턱 움직임
            confidence = 0.75
            detection_method = "combined"
            eating_detected = True
        elif confidence_factors['lips_moving']:
            # 기존 입술 감지만
            confidence = 0.6
            detection_method = "lips"
            eating_detected = True
        elif confidence_factors['jaw_moving'] and confidence_factors['rhythm_score'] > 0.2:
            # 턱 움직임만 (약한 신호)
            confidence = 0.5
            detection_method = "jaw"
            eating_detected = True
        else:
            eating_detected = False
        
        # === 5. 시간적 필터링 (Hysteresis) ===
        if eating_detected:
            self.eating_counter += 1
            self.not_eating_counter = 0
        else:
            self.not_eating_counter += 1
            self.eating_counter = 0

        # 최종 식사 상태 결정
        if self.eating_counter > self.EATING_CONFIRM_COUNT:
            if not self.is_eating:
                self.is_eating = True
                self.consecutive_eating_sessions += 1
            self.last_eating_time = time.time()
        elif self.not_eating_counter > self.NO_EATING_TIMEOUT:
            if self.is_eating:
                self.is_eating = False
                self.consecutive_eating_sessions = 0

        # 상태 업데이트
        states.update({
            "is_eating": self.is_eating,
            "confidence": confidence,
            "detection_method": detection_method,
            "chewing_rhythm_score": chewing_info.get("rhythm_score", 0.0),
            "chewing_frequency": chewing_info.get("frequency", 0.0)
        })
        
        self.last_confidence = confidence
        self.detection_method = detection_method
        
        return states

    def get_debug_info(self) -> Dict[str, any]:
        """디버깅용 상세 정보 반환"""
        return {
            "eating_counter": self.eating_counter,
            "not_eating_counter": self.not_eating_counter,
            "consecutive_sessions": self.consecutive_eating_sessions,
            "last_confidence": self.last_confidence,
            "detection_method": self.detection_method,
            "data_lengths": {
                "mouth_height": len(self.height_history),
                "mouth_ratio": len(self.ratio_history),
                "jaw_height": len(self.jaw_height_history),
                "jaw_width": len(self.jaw_width_history),
                "jaw_angle": len(self.jaw_angle_history)
            }
        }
