            "mouth_ratio": [0.3] * 60,
            "jaw_height": [0.08] * 60,
            "expected": False
        }
    }
    
    return scenarios

def test_basic_vs_advanced():
    """기본 감지 vs 고급 감지 성능 비교"""
    print("🧪 기본 감지 vs 고급 감지 성능 비교 테스트")
    print("=" * 50)
    
    try:
        # 모듈 임포트 테스트
        from advanced_eating_status import AdvancedEatingStatus
        print("✅ AdvancedEatingStatus 모듈 로드 성공")
        
        # 더미 랜드마크 클래스
        class DummyLandmark:
            def __init__(self, x, y, z=0):
                self.x, self.y, self.z = x, y, z
        
        # 더미 랜드마크 생성 (468개 포인트)
        def create_dummy_landmarks(jaw_height_offset=0):
            landmarks = []
            for i in range(468):
                if i == 13:  # 상순
                    landmarks.append(DummyLandmark(0.5, 0.6, 0))
                elif i == 14:  # 하순
                    landmarks.append(DummyLandmark(0.5, 0.62, 0))
                elif i == 61:  # 좌측 입꼬리
                    landmarks.append(DummyLandmark(0.45, 0.61, 0))
                elif i == 291:  # 우측 입꼬리
                    landmarks.append(DummyLandmark(0.55, 0.61, 0))
                elif i == 175:  # 턱끝
                    landmarks.append(DummyLandmark(0.5, 0.7 + jaw_height_offset, 0))
                elif i == 172:  # 좌측 턱선
                    landmarks.append(DummyLandmark(0.4, 0.68 + jaw_height_offset, 0))
                elif i == 397:  # 우측 턱선
                    landmarks.append(DummyLandmark(0.6, 0.68 + jaw_height_offset, 0))
                else:
                    landmarks.append(DummyLandmark(0.5, 0.5, 0))
            return landmarks
        
    except ImportError as e:
        print(f"❌ 고급 감지 모듈 로드 실패: {e}")
        return False
    
    # 기본 감지 클래스 (간단 구현)
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
    
    # 테스트 데이터 생성
    scenarios = generate_test_data()
    
    results = {
        "basic": {"correct": 0, "total": 0},
        "advanced": {"correct": 0, "total": 0}
    }
    
    print(f"📊 {len(scenarios)}가지 시나리오 테스트 중...\n")
    
    for scenario_name, data in scenarios.items():
        print(f"🔍 테스트: {data['description']}")
        
        # 기본 감지 테스트
        basic_detector = BasicEatingStatus()
        basic_result = None
        
        for i in range(len(data['mouth_height'])):
            result = basic_detector.detect_eating_behavior(
                data['mouth_height'][i], 
                data['mouth_ratio'][i]
            )
            if i == len(data['mouth_height']) - 1:
                basic_result = result['is_eating']
        
        # 고급 감지 테스트
        advanced_detector = AdvancedEatingStatus()
        advanced_result = None
        
        for i in range(len(data['mouth_height'])):
            # 턱 높이 변화를 반영한 더미 랜드마크
            jaw_offset = (data['jaw_height'][i] - 0.08) * 0.1  # 정규화
            landmarks = create_dummy_landmarks(jaw_offset)
            
            result = advanced_detector.detect_eating_behavior(
                data['mouth_height'][i], 
                data['mouth_ratio'][i],
                landmarks
            )
            if i == len(data['mouth_height']) - 1:
                advanced_result = result['is_eating']
                confidence = result.get('confidence', 0.0)
                method = result.get('detection_method', 'unknown')
        
        # 결과 평가
        expected = data['expected']
        basic_correct = (basic_result == expected)
        advanced_correct = (advanced_result == expected)
        
        results["basic"]["total"] += 1
        results["advanced"]["total"] += 1
        
        if basic_correct:
            results["basic"]["correct"] += 1
        if advanced_correct:
            results["advanced"]["correct"] += 1
        
        # 결과 출력
        print(f"   예상: {'식사' if expected else '비식사'}")
        print(f"   기본 감지: {'식사' if basic_result else '비식사'} {'✅' if basic_correct else '❌'}")
        print(f"   고급 감지: {'식사' if advanced_result else '비식사'} {'✅' if advanced_correct else '❌'}")
        if advanced_result:
            print(f"   신뢰도: {confidence:.2f}, 방법: {method}")
        print()
    
    # 최종 결과
    print("📈 최종 결과")
    print("=" * 30)
    basic_accuracy = (results["basic"]["correct"] / results["basic"]["total"]) * 100
    advanced_accuracy = (results["advanced"]["correct"] / results["advanced"]["total"]) * 100
    
    print(f"기본 감지 정확도: {basic_accuracy:.1f}% ({results['basic']['correct']}/{results['basic']['total']})")
    print(f"고급 감지 정확도: {advanced_accuracy:.1f}% ({results['advanced']['correct']}/{results['advanced']['total']})")
    print(f"정확도 향상: {advanced_accuracy - basic_accuracy:+.1f}%p")
    
    if advanced_accuracy > basic_accuracy:
        print("🎉 고급 감지가 더 정확합니다!")
    elif advanced_accuracy == basic_accuracy:
        print("🤔 두 방식의 정확도가 동일합니다.")
    else:
        print("⚠️ 기본 감지가 더 정확합니다. 알고리즘 조정이 필요할 수 있습니다.")
    
    return True

def test_jaw_detection_features():
    """턱 감지 기능 단독 테스트"""
    print("\n🦴 턱 감지 기능 단독 테스트")
    print("=" * 30)
    
    try:
        from advanced_eating_status import AdvancedEatingStatus
        
        detector = AdvancedEatingStatus()
        
        # 더미 랜드마크 생성
        class DummyLandmark:
            def __init__(self, x, y, z=0):
                self.x, self.y, self.z = x, y, z
        
        def create_test_landmarks(jaw_height, jaw_width, jaw_angle_factor=1.0):
            landmarks = []
            for i in range(468):
                if i == 175:  # 턱끝
                    landmarks.append(DummyLandmark(0.5, 0.7 + jaw_height, 0))
                elif i == 172:  # 좌측 턱선
                    landmarks.append(DummyLandmark(0.5 - jaw_width/2, 0.68, 0))
                elif i == 397:  # 우측 턱선
                    landmarks.append(DummyLandmark(0.5 + jaw_width/2, 0.68, 0))
                else:
                    landmarks.append(DummyLandmark(0.5, 0.5, 0))
            return landmarks
        
        print("🔧 턱 특징 계산 테스트...")
        
        # 정적 상태
        static_landmarks = create_test_landmarks(0, 0.1)
        jaw_height, jaw_width, jaw_angle = detector.calculate_jaw_features(static_landmarks)
        print(f"정적 상태 - 턱 높이: {jaw_height:.4f}, 너비: {jaw_width:.4f}, 각도: {jaw_angle:.4f}")
        
        # 턱 벌린 상태
        open_landmarks = create_test_landmarks(0.02, 0.12)
        jaw_height, jaw_width, jaw_angle = detector.calculate_jaw_features(open_landmarks)
        print(f"턱 벌림 - 턱 높이: {jaw_height:.4f}, 너비: {jaw_width:.4f}, 각도: {jaw_angle:.4f}")
        
        print("\n🎵 씹기 패턴 감지 테스트...")
        
        # 씹기 패턴 시뮬레이션 (1.5Hz 주파수)
        for i in range(90):  # 3초간 데이터
            t = i / 30.0  # 30 FPS
            # 1.5Hz 사인파 + 노이즈
            jaw_movement = 0.08 + 0.01 * np.sin(2 * np.pi * 1.5 * t) + 0.002 * np.random.randn()
            detector.jaw_height_history.append(jaw_movement)
        
        chewing_info = detector.detect_chewing_pattern()
        print(f"씹기 감지: {chewing_info['detected']}")
        print(f"리듬 점수: {chewing_info['rhythm_score']:.3f}")
        print(f"주요 주파수: {chewing_info['frequency']:.2f} Hz")
        
        return True
        
    except Exception as e:
        print(f"❌ 턱 감지 테스트 실패: {e}")
        return False

def main():
    """메인 테스트 실행"""
    print("🚀 BobCam Phase 1 기능 테스트 시작")
    print("=" * 60)
    
    # 환경 확인
    print("📋 환경 확인...")
    try:
        import numpy
        import scipy
        print(f"✅ NumPy: {numpy.__version__}")
        print(f"✅ SciPy: {scipy.__version__}")
    except ImportError as e:
        print(f"❌ 필수 라이브러리 누락: {e}")
        print("pip install numpy scipy 를 실행해주세요.")
        return
    
    print()
    
    # 기능 테스트들 실행
    tests = [
        ("기본 vs 고급 감지 비교", test_basic_vs_advanced),
        ("턱 감지 기능 단독", test_jaw_detection_features),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🧪 {test_name} 테스트 시작")
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
        print("이제 main_enhanced.py를 실행해서 실제 앱을 테스트해보세요.")
    else:
        print("⚠️ 일부 테스트가 실패했습니다. 문제를 확인해주세요.")

if __name__ == "__main__":
    main()
