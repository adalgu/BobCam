"""
식기구 감지 모듈
YOLO 모델을 사용하여 숟가락, 포크, 젓가락을 감지하고
입 근처에서의 식기구 사용 패턴을 분석합니다.
"""

import cv2
import numpy as np
import time
from collections import deque
from typing import Dict, List, Tuple, Optional

try:
    from ultralytics import YOLO
    YOLO_AVAILABLE = True
    print("✅ YOLO 모듈 로드 성공")
except ImportError:
    YOLO_AVAILABLE = False
    print("⚠️ YOLO 모듈 없음 - 식기구 감지 기능 비활성화")


class UtensilDetector:
    """
    YOLO 모델을 사용한 식기구 감지 클래스
    """
    
    def __init__(self, model_path="./dev/yolov8n.pt"):
        self.model = None
        self.model_path = model_path
        
        # COCO 데이터셋의 식기구 클래스 번호
        self.UTENSIL_CLASSES = {
            'fork': 42,      # 포크
            'knife': 43,     # 나이프  
            'spoon': 44      # 숟가락
        }
        
        # 감지 설정
        self.confidence_threshold = 0.5  # 감지 신뢰도 임계값
        self.mouth_roi_radius = 150      # 입 중심 ROI 반경 (픽셀)
        
        # 식기구 사용 패턴 추적
        self.utensil_history = deque(maxlen=90)  # 3초간 기록 (30fps)
        self.last_detection_time = 0
        self.detection_count = 0
        
        # 모델 로드
        self.load_model()
        
    def load_model(self):
        """YOLO 모델 로드"""
        if not YOLO_AVAILABLE:
            print("⚠️ YOLO 라이브러리가 설치되지 않음")
            return False
            
        try:
            self.model = YOLO(self.model_path)
            print(f"✅ YOLO 모델 로드 완료: {self.model_path}")
            return True
        except Exception as e:
            print(f"❌ YOLO 모델 로드 실패: {e}")
            return False
    
    def get_mouth_center(self, mouth_landmarks) -> Tuple[int, int]:
        """입 중심점 계산"""
        try:
            # 입 중심을 상하좌우 극값의 중점으로 계산
            upper_lip = mouth_landmarks[13]
            lower_lip = mouth_landmarks[14]
            left_corner = mouth_landmarks[61]
            right_corner = mouth_landmarks[291]
            
            center_x = int((left_corner.x + right_corner.x) / 2)
            center_y = int((upper_lip.y + lower_lip.y) / 2)
            
            return center_x, center_y
        except:
            return 0, 0
    
    def create_mouth_roi(self, frame, mouth_center: Tuple[int, int]) -> Tuple[np.ndarray, Tuple[int, int, int, int]]:
        """입 중심 기준 ROI 생성"""
        h, w = frame.shape[:2]
        cx, cy = mouth_center
        
        # ROI 좌표 계산 (화면 경계 고려)
        x1 = max(0, cx - self.mouth_roi_radius)
        y1 = max(0, cy - self.mouth_roi_radius)
        x2 = min(w, cx + self.mouth_roi_radius)
        y2 = min(h, cy + self.mouth_roi_radius)
        
        roi = frame[y1:y2, x1:x2]
        roi_coords = (x1, y1, x2, y2)
        
        return roi, roi_coords
    
    def detect_utensils_in_roi(self, roi: np.ndarray, roi_coords: Tuple[int, int, int, int]) -> List[Dict]:
        """ROI에서 식기구 감지"""
        if self.model is None:
            return []
        
        try:
            # YOLO 감지 실행
            results = self.model(roi, verbose=False)
            detections = []
            
            x1, y1, x2, y2 = roi_coords
            
            for result in results:
                if result.boxes is not None:
                    for box in result.boxes:
                        class_id = int(box.cls)
                        confidence = float(box.conf)
                        
                        # 식기구 클래스이고 신뢰도가 충분한 경우
                        if class_id in self.UTENSIL_CLASSES.values() and confidence >= self.confidence_threshold:
                            # ROI 좌표를 전체 이미지 좌표로 변환
                            bbox = box.xyxy[0].cpu().numpy()
                            abs_x1 = int(bbox[0] + x1)
                            abs_y1 = int(bbox[1] + y1)
                            abs_x2 = int(bbox[2] + x1)
                            abs_y2 = int(bbox[3] + y1)
                            
                            # 클래스 이름 찾기
                            utensil_name = None
                            for name, id in self.UTENSIL_CLASSES.items():
                                if id == class_id:
                                    utensil_name = name
                                    break
                            
                            detection = {
                                'class': utensil_name,
                                'confidence': confidence,
                                'bbox': (abs_x1, abs_y1, abs_x2, abs_y2),
                                'center': ((abs_x1 + abs_x2) // 2, (abs_y1 + abs_y2) // 2)
                            }
                            detections.append(detection)
            
            return detections
            
        except Exception as e:
            print(f"식기구 감지 오류: {e}")
            return []
    
    def calculate_distance_to_mouth(self, utensil_center: Tuple[int, int], mouth_center: Tuple[int, int]) -> float:
        """식기구와 입 사이의 거리 계산"""
        ux, uy = utensil_center
        mx, my = mouth_center
        return np.sqrt((ux - mx)**2 + (uy - my)**2)
    
    def detect_utensil_to_mouth_action(self, frame, mouth_landmarks) -> Dict:
        """식기구 → 입 동작 감지"""
        mouth_center = self.get_mouth_center(mouth_landmarks)
        
        # 입 중심이 유효하지 않으면 감지 불가
        if mouth_center == (0, 0):
            return {
                'detected': False,
                'utensils': [],
                'closest_distance': float('inf'),
                'action_detected': False
            }
        
        # ROI 생성 및 식기구 감지
        roi, roi_coords = self.create_mouth_roi(frame, mouth_center)
        detections = self.detect_utensils_in_roi(roi, roi_coords)
        
        # 감지된 식기구들의 거리 계산
        utensil_distances = []
        for detection in detections:
            distance = self.calculate_distance_to_mouth(detection['center'], mouth_center)
            detection['distance_to_mouth'] = distance
            utensil_distances.append(distance)
        
        # 가장 가까운 식기구 거리
        closest_distance = min(utensil_distances) if utensil_distances else float('inf')
        
        # 식기구 → 입 동작 판단 (거리 기준)
        action_detected = closest_distance < 80  # 80픽셀 이내면 "입에 가까움"
        
        # 이력 추가
        self.utensil_history.append({
            'timestamp': time.time(),
            'action_detected': action_detected,
            'closest_distance': closest_distance,
            'detections': detections
        })
        
        if action_detected:
            self.last_detection_time = time.time()
            self.detection_count += 1
        
        return {
            'detected': len(detections) > 0,
            'utensils': detections,
            'closest_distance': closest_distance,
            'action_detected': action_detected,
            'mouth_center': mouth_center
        }
    
    def draw_detections(self, frame, detection_result: Dict):
        """감지 결과를 프레임에 그리기"""
        if not detection_result['detected']:
            return frame
        
        mouth_center = detection_result.get('mouth_center', (0, 0))
        
        # 입 중심 표시
        if mouth_center != (0, 0):
            cv2.circle(frame, mouth_center, 5, (255, 0, 255), -1)  # 보라색 점
            cv2.circle(frame, mouth_center, self.mouth_roi_radius, (255, 0, 255), 2)  # ROI 원
        
        # 식기구 바운딩 박스 그리기
        for utensil in detection_result['utensils']:
            bbox = utensil['bbox']
            confidence = utensil['confidence']
            utensil_name = utensil['class']
            distance = utensil.get('distance_to_mouth', 0)
            
            x1, y1, x2, y2 = bbox
            
            # 거리에 따른 색상 결정
            if distance < 80:
                color = (0, 255, 0)  # 초록색 (가까움)
                thickness = 3
            else:
                color = (0, 255, 255)  # 노란색 (감지됨)
                thickness = 2
            
            # 바운딩 박스 그리기
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, thickness)
            
            # 라벨 텍스트
            label = f"{utensil_name} {confidence:.2f} ({distance:.0f}px)"
            cv2.putText(frame, label, (x1, y1-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)
            
            # 중심점에서 입까지 선 그리기
            utensil_center = utensil['center']
            cv2.line(frame, utensil_center, mouth_center, color, 1)
        
        return frame
    
    def get_last_action_time(self) -> float:
        """마지막 식기구 → 입 동작 시간 반환"""
        return self.last_detection_time
    
    def get_time_since_last_action(self) -> float:
        """마지막 동작 이후 경과 시간 반환"""
        if self.last_detection_time == 0:
            return 0
        return time.time() - self.last_detection_time
    
    def get_detection_stats(self) -> Dict:
        """감지 통계 정보 반환"""
        recent_actions = [h for h in self.utensil_history if h['action_detected']]
        
        return {
            'total_detections': self.detection_count,
            'recent_actions': len(recent_actions),
            'last_action_time': self.last_detection_time,
            'time_since_last': self.get_time_since_last_action(),
            'history_length': len(self.utensil_history)
        }


class ChopsticksDetector:
    """
    젓가락 감지를 위한 별도 클래스 (YOLO에서 지원하지 않음)
    """
    
    def __init__(self):
        self.last_detection_time = 0
        
    def detect_chopsticks(self, frame, hand_landmarks=None) -> Dict:
        """
        젓가락 감지 (현재는 플레이스홀더)
        실제 구현시 손 랜드마크와 선형 객체 감지 조합 필요
        """
        # TODO: 실제 젓가락 감지 로직 구현
        # 1. 손 랜드마크에서 손가락 끝 감지
        # 2. 두 개의 평행한 선형 객체 탐지
        # 3. 입 근처 위치 확인
        
        return {
            'detected': False,
            'confidence': 0.0,
            'action_detected': False
        }
