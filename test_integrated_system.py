#!/usr/bin/env python3
"""
BobCam v3.0 통합 시스템 테스트 스크립트
새로운 모듈들이 제대로 로드되는지 확인합니다.
"""

import sys
import os

def test_imports():
    """모든 모듈 임포트 테스트"""
    print("🧪 BobCam v3.0 모듈 테스트 시작...\n")
    
    # 기본 라이브러리 테스트
    print("1. 기본 라이브러리 테스트:")
    try:
        import cv2
        print(f"   ✅ OpenCV: {cv2.__version__}")
    except ImportError as e:
        print(f"   ❌ OpenCV: {e}")
    
    try:
        import mediapipe as mp
        print(f"   ✅ MediaPipe: {mp.__version__}")
    except ImportError as e:
        print(f"   ❌ MediaPipe: {e}")
    
    try:
        import numpy as np
        print(f"   ✅ NumPy: {np.__version__}")
    except ImportError as e:
        print(f"   ❌ NumPy: {e}")
    
    # YOLO 테스트
    print("\n2. YOLO 모듈 테스트:")
    try:
        from ultralytics import YOLO
        print("   ✅ Ultralytics YOLO 사용 가능")
        
        # 모델 파일 확인
        model_path = "./dev/yolov8n.pt"
        if os.path.exists(model_path):
            print(f"   ✅ YOLO 모델 파일 존재: {model_path}")
        else:
            print(f"   ⚠️ YOLO 모델 파일 없음: {model_path}")
            print("      다운로드 필요: https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt")
    except ImportError as e:
        print(f"   ❌ YOLO: {e}")
    
    # 알람 시스템 테스트
    print("\n3. 알람 시스템 테스트:")
    try:
        import pygame
        print(f"   ✅ Pygame: {pygame.version.ver}")
    except ImportError as e:
        print(f"   ❌ Pygame: {e}")
    
    # 커스텀 모듈 테스트
    print("\n4. 커스텀 모듈 테스트:")
    try:
        from advanced_eating_status import AdvancedEatingStatus
        print("   ✅ 고급 감지 모듈 (AdvancedEatingStatus)")
    except ImportError as e:
        print(f"   ❌ 고급 감지 모듈: {e}")
    
    try:
        from utensil_detector import UtensilDetector
        print("   ✅ 식기구 감지 모듈 (UtensilDetector)")
    except ImportError as e:
        print(f"   ❌ 식기구 감지 모듈: {e}")
    
    try:
        from integrated_alarm_system import IntegratedAlarmSystem
        print("   ✅ 통합 알람 시스템 (IntegratedAlarmSystem)")
    except ImportError as e:
        print(f"   ❌ 통합 알람 시스템: {e}")

def test_yolo_model():
    """YOLO 모델 로드 테스트"""
    print("\n5. YOLO 모델 로드 테스트:")
    try:
        from ultralytics import YOLO
        
        model_path = "./dev/yolov8n.pt"
        if os.path.exists(model_path):
            model = YOLO(model_path)
            print(f"   ✅ YOLO 모델 로드 성공: {model_path}")
            
            # 지원 클래스 확인
            class_names = model.names
            utensil_classes = {42: 'fork', 43: 'knife', 44: 'spoon'}
            print("   📋 식기구 클래스:")
            for class_id, name in utensil_classes.items():
                if class_id in class_names:
                    print(f"      ✅ {class_id}: {class_names[class_id]} ({name})")
                else:
                    print(f"      ❌ {class_id}: {name} (없음)")
        else:
            print(f"   ⚠️ 모델 파일 없음: {model_path}")
            print("      YOLO 모델 다운로드 명령:")
            print("      wget https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt -P ./dev/")
            
    except Exception as e:
        print(f"   ❌ YOLO 테스트 실패: {e}")

def test_alarm_system():
    """알람 시스템 테스트"""
    print("\n6. 알람 시스템 기능 테스트:")
    try:
        from integrated_alarm_system import IntegratedAlarmSystem
        
        alarm = IntegratedAlarmSystem()
        print("   ✅ 알람 시스템 초기화 성공")
        
        # 기본 설정 확인
        print(f"   📋 기본 설정:")
        print(f"      • 식기구 타임아웃: {alarm.utensil_timeout}초")
        print(f"      • 씹기 타임아웃: {alarm.chewing_timeout}초")
        print(f"      • 알람 쿨다운: {alarm.alarm_cooldown}초")
        
        # 가짜 데이터로 테스트
        utensil_result = {'detected': True, 'action_detected': True}
        eating_result = {'is_eating': False, 'confidence': 0.3}
        
        status = alarm.process_combined_status(utensil_result, eating_result)
        print("   ✅ 통합 상태 처리 테스트 성공")
        
        alarm.cleanup()
        
    except Exception as e:
        print(f"   ❌ 알람 시스템 테스트 실패: {e}")

def main():
    print("=" * 60)
    print("🍽️ BobCam v3.0 통합 시스템 테스트")
    print("=" * 60)
    
    test_imports()
    test_yolo_model()
    test_alarm_system()
    
    print("\n" + "=" * 60)
    print("📋 테스트 완료!")
    print("\n🚀 모든 테스트가 통과하면 다음 명령으로 앱을 실행하세요:")
    print("   python3 main_integrated.py")
    print("=" * 60)

if __name__ == "__main__":
    main()
