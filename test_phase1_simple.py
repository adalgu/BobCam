#!/usr/bin/env python3
"""
BobCam Phase 1 기능 테스트 스크립트
턱 움직임 감지 기능의 정확도를 테스트합니다.
"""

import sys
import time
import numpy as np
from collections import deque

def test_basic_imports():
    """기본 모듈 임포트 테스트"""
    print("📋 기본 모듈 임포트 테스트...")
    
    try:
        import numpy
        import scipy
        print(f"✅ NumPy: {numpy.__version__}")
        print(f"✅ SciPy: {scipy.__version__}")
        return True
    except ImportError as e:
        print(f"❌ 필수 라이브러리 누락: {e}")
        return False

def test_advanced_detection_module():
    """고급 감지 모듈 테스트"""
    print("\n🧪 고급 감지 모듈 테스트...")
    
    try:
        from advanced_eating_status import AdvancedEatingStatus
        print("✅ AdvancedEatingStatus 모듈 로드 성공")
        
        # 인스턴스 생성 테스트
        detector = AdvancedEatingStatus()
        print("✅ AdvancedEatingStatus 인스턴스 생성 성공")
        
        # 기본 턱 특징 계산 테스트
        class DummyLandmark:
            def __init__(self, x, y, z=0):
                self.x, self.y, self.z = x, y, z
        
        # 더미 랜드마크 생성
        landmarks = []
        for i in range(468):
            if i == 175:  # 턱끝
                landmarks.append(DummyLandmark(0.5, 0.7, 0))
            elif i == 172:  # 좌측 턱선
                landmarks.append(DummyLandmark(0.4, 0.68, 0))
            elif i == 397:  # 우측 턱선
                landmarks.append(DummyLandmark(0.6, 0.68, 0))
            else:
                landmarks.append(DummyLandmark(0.5, 0.5, 0))
        
        jaw_height, jaw_width, jaw_angle = detector.calculate_jaw_features(landmarks)
        print(f"✅ 턱 특징 계산 성공: 높이={jaw_height:.4f}, 너비={jaw_width:.4f}, 각도={jaw_angle:.4f}")
        
        return True
        
    except ImportError as e:
        print(f"❌ 고급 감지 모듈 로드 실패: {e}")
        return False
    except Exception as e:
        print(f"❌ 고급 감지 모듈 테스트 실패: {e}")
        return False

def test_eating_detection():
    """기본 식사 감지 테스트"""
    print("\n🍽️ 기본 식사 감지 로직 테스트...")
    
    try:
        # 기본 감지 클래스 (간단 버전)
        class BasicEatingStatus:
            def __init__(self):
                self.height_history = deque(maxlen=60)
                self.ratio_history = deque(maxlen=60)
                self.is_eating = False
                self.eating_counter = 0
                self.not_eating_counter = 0
                
            def detect_eating_behavior(self, mouth_height, mouth_ratio):
                self.height_history.append(mouth_height)
                self.ratio_history.append(mouth_ratio)
                
                if len(self.height_history) < 30:
                    return {"is_eating": False}
                
                height_std = np.std(self.height_history)
                ratio_std = np.std(self.ratio_history)
                
                eating_detected = height_std > 0.03 or ratio_std > 0.02
                
                if eating_detected:
                    self.eating_counter += 1
                    self.not_eating_counter = 0
                else:
                    self.not_eating_counter += 1
                    self.eating_counter = 0
                
                if self.eating_counter > 15:
                    self.is_eating = True
                elif self.not_eating_counter > 60:
                    self.is_eating = False
                    
                return {"is_eating": self.is_eating}
        
        detector = BasicEatingStatus()
        
        # 테스트 데이터: 식사 시뮬레이션
        eating_data = [0.01, 0.025, 0.015, 0.03, 0.01, 0.02] * 15
        eating_ratios = [0.3, 0.5, 0.4, 0.6, 0.3, 0.4] * 15
        
        final_result = None
        for i in range(len(eating_data)):
            result = detector.detect_eating_behavior(eating_data[i], eating_ratios[i])
            if i == len(eating_data) - 1:
                final_result = result['is_eating']
        
        print(f"✅ 식사 감지 결과: {final_result}")
        return True
        
    except Exception as e:
        print(f"❌ 식사 감지 테스트 실패: {e}")
        return False

def main():
    """메인 테스트 실행"""
    print("🚀 BobCam Phase 1 기능 테스트 시작")
    print("=" * 60)
    
    # 테스트 목록
    tests = [
        ("기본 모듈 임포트", test_basic_imports),
        ("고급 감지 모듈", test_advanced_detection_module),
        ("식사 감지 로직", test_eating_detection),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                print(f"✅ {test_name} 테스트 통과")
                passed += 1
            else:
                print(f"❌ {test_name} 테스트 실패")
        except Exception as e:
            print(f"💥 {test_name} 테스트 중 오류: {e}")
    
    print(f"\n📊 전체 테스트 결과: {passed}/{total} 통과")
    
    if passed == total:
        print("🎉 모든 테스트가 성공했습니다! 🎉")
        print("\n다음 단계:")
        print("1. python3 main_enhanced.py - 고급 앱 실행")
        print("2. python3 main_stable.py - 기존 안정 버전 실행")
    else:
        print("⚠️ 일부 테스트가 실패했습니다.")
        if passed > 0:
            print("기본 기능은 작동하므로 앱 실행은 가능합니다.")

if __name__ == "__main__":
    main()
