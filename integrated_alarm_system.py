"""
통합 알람 시스템
기존 입술+턱 감지와 새로운 식기구 감지를 결합하여
두 가지 알람 조건을 관리합니다.
"""

import time
import threading
import pygame
import os
from typing import Dict, Optional


class IntegratedAlarmSystem:
    """
    통합 알람 시스템
    - 조건 1: 식기구 사용 후 특정 시간(기본 40초) 경과
    - 조건 2: 씹지 않을 때 (기존 입술+턱 감지)
    """
    
    def __init__(self):
        # 알람 조건 설정
        self.utensil_timeout = 40.0  # 식기구 사용 후 알람까지의 시간 (초)
        self.chewing_timeout = 5.0   # 씹지 않을 때 알람까지의 시간 (초)
        
        # 상태 변수
        self.last_utensil_action_time = 0
        self.last_chewing_time = time.time()
        self.is_currently_eating = False
        
        # 알람 상태
        self.utensil_alarm_active = False
        self.chewing_alarm_active = False
        self.last_alarm_time = 0
        self.alarm_cooldown = 10.0  # 알람 간 최소 간격 (초)
        
        # 사운드 시스템 초기화
        self.init_sound_system()
        
        # 알람 메시지
        self.alarm_messages = {
            'utensil_timeout': "🍴 밥을 계속 먹어야 해요!",
            'not_chewing': "😋 잘 씹어서 먹어요!",
            'both': "🍽️ 밥을 먹고 잘 씹어요!"
        }
        
    def init_sound_system(self):
        """사운드 시스템 초기화"""
        try:
            pygame.mixer.init()
            self.sound_available = True
            print("✅ 사운드 시스템 초기화 완료")
        except Exception as e:
            print(f"⚠️ 사운드 시스템 초기화 실패: {e}")
            self.sound_available = False
    
    def update_utensil_action(self, utensil_detected: bool, action_detected: bool):
        """식기구 사용 상태 업데이트"""
        if action_detected:
            self.last_utensil_action_time = time.time()
            if self.utensil_alarm_active:
                self.utensil_alarm_active = False
                print("✅ 식기구 알람 해제 - 음식을 먹기 시작함")
    
    def update_chewing_status(self, is_eating: bool, eating_confidence: float = 0.0):
        """씹기 상태 업데이트"""
        if is_eating:
            self.last_chewing_time = time.time()
            self.is_currently_eating = True
            if self.chewing_alarm_active:
                self.chewing_alarm_active = False
                print("✅ 씹기 알람 해제 - 씹기 시작함")
        else:
            self.is_currently_eating = False
    
    def check_alarm_conditions(self) -> Dict:
        """알람 조건 체크"""
        current_time = time.time()
        
        # 조건 1: 식기구 사용 후 시간 경과
        time_since_utensil = current_time - self.last_utensil_action_time if self.last_utensil_action_time > 0 else 0
        utensil_alarm_needed = (
            self.last_utensil_action_time > 0 and 
            time_since_utensil > self.utensil_timeout and
            not self.utensil_alarm_active
        )
        
        # 조건 2: 씹지 않음
        time_since_chewing = current_time - self.last_chewing_time
        chewing_alarm_needed = (
            time_since_chewing > self.chewing_timeout and
            not self.is_currently_eating and
            not self.chewing_alarm_active
        )
        
        # 알람 쿨다운 체크
        can_trigger_alarm = (current_time - self.last_alarm_time) > self.alarm_cooldown
        
        return {
            'utensil_alarm_needed': utensil_alarm_needed and can_trigger_alarm,
            'chewing_alarm_needed': chewing_alarm_needed and can_trigger_alarm,
            'time_since_utensil': time_since_utensil,
            'time_since_chewing': time_since_chewing,
            'can_trigger_alarm': can_trigger_alarm
        }
    
    def trigger_alarm(self, alarm_type: str):
        """알람 실행"""
        current_time = time.time()
        
        # 쿨다운 체크
        if (current_time - self.last_alarm_time) < self.alarm_cooldown:
            return
        
        message = self.alarm_messages.get(alarm_type, "밥을 먹어요!")
        
        # 알람 상태 설정
        if alarm_type == 'utensil_timeout':
            self.utensil_alarm_active = True
        elif alarm_type == 'not_chewing':
            self.chewing_alarm_active = True
        elif alarm_type == 'both':
            self.utensil_alarm_active = True
            self.chewing_alarm_active = True
        
        self.last_alarm_time = current_time
        
        # 알람 실행 (별도 스레드)
        alarm_thread = threading.Thread(
            target=self._execute_alarm,
            args=(message, alarm_type),
            daemon=True
        )
        alarm_thread.start()
        
        print(f"🚨 알람 실행: {message} (타입: {alarm_type})")
    
    def _execute_alarm(self, message: str, alarm_type: str):
        """실제 알람 실행 (별도 스레드에서 실행)"""
        try:
            # 1. 콘솔 메시지
            print(f"\n{'='*50}")
            print(f"🚨 {message}")
            print(f"{'='*50}\n")
            
            # 2. 시스템 사운드 재생
            if self.sound_available:
                self._play_alarm_sound(alarm_type)
            
            # 3. 시각적 알림 (터미널)
            for i in range(3):
                print(f"🔔 {message}")
                time.sleep(0.5)
                
        except Exception as e:
            print(f"알람 실행 오류: {e}")
    
    def _play_alarm_sound(self, alarm_type: str):
        """알람 사운드 재생"""
        try:
            # 기본 시스템 벨 사운드
            print('\a')  # 시스템 벨
            
            # 추가 사운드 파일이 있다면 재생
            sound_files = {
                'utensil_timeout': 'sounds/eating_reminder.wav',
                'not_chewing': 'sounds/chewing_reminder.wav',
                'both': 'sounds/general_reminder.wav'
            }
            
            sound_file = sound_files.get(alarm_type)
            if sound_file and os.path.exists(sound_file):
                pygame.mixer.Sound(sound_file).play()
                
        except Exception as e:
            print(f"사운드 재생 오류: {e}")
    
    def process_combined_status(self, utensil_result: Dict, eating_result: Dict) -> Dict:
        """통합 상태 처리 및 알람 판단"""
        
        # 식기구 상태 업데이트
        self.update_utensil_action(
            utensil_result.get('detected', False),
            utensil_result.get('action_detected', False)
        )
        
        # 씹기 상태 업데이트
        self.update_chewing_status(
            eating_result.get('is_eating', False),
            eating_result.get('confidence', 0.0)
        )
        
        # 알람 조건 체크
        alarm_conditions = self.check_alarm_conditions()
        
        # 알람 실행 결정
        if alarm_conditions['utensil_alarm_needed'] and alarm_conditions['chewing_alarm_needed']:
            self.trigger_alarm('both')
        elif alarm_conditions['utensil_alarm_needed']:
            self.trigger_alarm('utensil_timeout')
        elif alarm_conditions['chewing_alarm_needed']:
            self.trigger_alarm('not_chewing')
        
        # 상태 정보 반환
        return {
            'utensil_alarm_active': self.utensil_alarm_active,
            'chewing_alarm_active': self.chewing_alarm_active,
            'time_since_utensil': alarm_conditions['time_since_utensil'],
            'time_since_chewing': alarm_conditions['time_since_chewing'],
            'last_utensil_action': self.last_utensil_action_time,
            'last_chewing_time': self.last_chewing_time,
            'alarm_conditions': alarm_conditions
        }
    
    def get_status_text(self) -> str:
        """현재 상태를 텍스트로 반환"""
        current_time = time.time()
        
        # 시간 계산
        time_since_utensil = current_time - self.last_utensil_action_time if self.last_utensil_action_time > 0 else 0
        time_since_chewing = current_time - self.last_chewing_time
        
        status_parts = []
        
        # 식기구 상태
        if self.last_utensil_action_time > 0:
            status_parts.append(f"🍴 마지막 식사: {time_since_utensil:.1f}초 전")
            if time_since_utensil > self.utensil_timeout:
                status_parts.append("⚠️ 식사 재개 필요")
        else:
            status_parts.append("🍴 식기구 사용 감지 안됨")
        
        # 씹기 상태
        status_parts.append(f"😋 마지막 씹기: {time_since_chewing:.1f}초 전")
        if self.is_currently_eating:
            status_parts.append("✅ 현재 씹는 중")
        elif time_since_chewing > self.chewing_timeout:
            status_parts.append("⚠️ 씹기 필요")
        
        # 알람 상태
        if self.utensil_alarm_active or self.chewing_alarm_active:
            status_parts.append("🚨 알람 활성")
        
        return " | ".join(status_parts)
    
    def set_timeouts(self, utensil_timeout: float, chewing_timeout: float):
        """타임아웃 설정 변경"""
        self.utensil_timeout = utensil_timeout
        self.chewing_timeout = chewing_timeout
        print(f"⚙️ 타임아웃 설정 변경: 식기구={utensil_timeout}초, 씹기={chewing_timeout}초")
    
    def reset_alarms(self):
        """모든 알람 상태 리셋"""
        self.utensil_alarm_active = False
        self.chewing_alarm_active = False
        self.last_alarm_time = 0
        print("🔄 알람 상태 리셋")
    
    def cleanup(self):
        """리소스 정리"""
        if self.sound_available:
            pygame.mixer.quit()
