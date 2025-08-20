import time


class MealTimingAnalyzer:
    def __init__(self):
        self.last_utensil_to_mouth_time = None  # 마지막 식기구 -> 입 동작 시간
        self.idle_threshold = 15.0  # 15초 대기 임계값
        self.adaptive_threshold_enabled = True  # 개인별 적응형 임계값 활성화 여부
        self.eating_sessions = []  # 식사 세션 히스토리 (속도, 간격 등)

    def update_utensil_event(self):
        """식기구가 입에 닿았을 때 호출됩니다."""
        self.last_utensil_to_mouth_time = time.time()
        # TODO: 식사 속도 및 간격 계산 로직 추가

    def calculate_idle_time(self):
        """마지막 식사 동작 이후 경과 시간을 계산합니다."""
        if self.last_utensil_to_mouth_time is None:
            return 0.0
        return time.time() - self.last_utensil_to_mouth_time

    def calculate_adaptive_threshold(self):
        """개인별 식사 패턴을 기반으로 적응형 임계값을 계산합니다."""
        if not self.adaptive_threshold_enabled or not self.eating_sessions:
            return self.idle_threshold

        # TODO: eating_sessions를 분석하여 개인화된 임계값 계산
        # 예: 평균 식사 간격의 1.5배

        # 임시로 기본값 반환
        return self.idle_threshold

    def detect_eating_pause(self):
        """
        식기구 사용 패턴을 분석하여 식사 중단을 감지합니다.

        Returns:
            tuple: (중단 여부, 경과 시간)
        """
        time_since_last_bite = self.calculate_idle_time()
        personal_threshold = self.calculate_adaptive_threshold()

        if time_since_last_bite > personal_threshold:
            return True, time_since_last_bite

        return False, time_since_last_bite
