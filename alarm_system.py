from meal_timing_analyzer import MealTimingAnalyzer
from voice_trigger_manager import VoiceTriggerManager


class SmartAlarmSystem:
    def __init__(self):
        self.timing_analyzer = MealTimingAnalyzer()
        self.voice_trigger = VoiceTriggerManager()
        self.alarm_modes = ["voice_trigger", "sound_alert", "visual_flash"]
        self.current_alarm_mode = "voice_trigger"

    def check_eating_status(self, utensil_data, mouth_data, jaw_data):
        """
        종합 분석으로 알람 필요성을 판단합니다.
        이 메소드는 메인 루프에서 주기적으로 호출되어야 합니다.
        """
        # 1. 식기구 기반 타이밍 분석
        # utensil_data에서 "식기구->입" 동작이 감지되면 timing_analyzer.update_utensil_event() 호출 필요
        # 이 부분은 utensil_detector.py 와의 연동이 필요합니다.
        # 예시: if utensil_data['action'] == 'utensil_to_mouth':
        #           self.timing_analyzer.update_utensil_event()

        pause_detected, idle_time = self.timing_analyzer.detect_eating_pause()

        # 2. 기존 입술+턱 감지 보조 활용 (main_integrated.py의 로직과 연동 필요)
        # traditional_eating = self.detect_traditional_eating(mouth_data, jaw_data)
        traditional_eating = False  # 임시값

        # 3. 종합 판단
        if pause_detected and not traditional_eating:
            self.trigger_alarm(idle_time)

    def trigger_alarm(self, idle_time):
        """
        단계별 알람 시스템
        """
        print(f"알람 트리거 확인: 경과 시간 {idle_time:.1f}초")

        if idle_time > 60:  # 1분 강한 알람
            self.play_strong_alert()
        elif idle_time > 30:  # 30초 음성 트리거
            if self.current_alarm_mode == "voice_trigger":
                self.voice_trigger.play_voice_trigger()
            elif self.current_alarm_mode == "sound_alert":
                self.play_gentle_reminder()
        elif idle_time > 15:  # 15초 경고
            self.play_gentle_reminder()

    def play_gentle_reminder(self):
        """가벼운 알림음을 재생합니다."""
        print("🔔 띠링! 식사를 계속하세요.")
        # TODO: 실제 사운드 파일 재생 로직 추가

    def play_strong_alert(self):
        """강한 경고음을 재생합니다."""
        print("🚨🚨🚨 식사 시간이 너무 길어지고 있습니다!")
        # TODO: 실제 사운드 파일 재생 로직 추가

    def set_alarm_mode(self, mode):
        """알람 모드를 설정합니다. ('voice_trigger', 'sound_alert', 'visual_flash')"""
        if mode in self.alarm_modes:
            self.current_alarm_mode = mode
            print(f"알람 모드 변경: {mode}")
