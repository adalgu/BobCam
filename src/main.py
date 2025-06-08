import cv2
import mediapipe as mp
import numpy as np
import time
import threading
import webbrowser
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
import pyttsx3
from collections import deque

class EatingYouTubeController:
    def __init__(self):
        # MediaPipe 설정
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        self.mp_draw = mp.solutions.drawing_utils
        
        # 입 관련 랜드마크 인덱스
        self.MOUTH_LANDMARKS = [
            13, 14, 17, 18, 200, 269, 270, 267, 271, 272
        ]
        
        # 상태 변수
        self.eating_history = deque(maxlen=30)  # 1초간 기록 (30fps)
        self.is_eating = False
        self.last_eating_time = time.time()
        self.consecutive_eating_count = 0
        self.reward_duration = 5  # 기본 보상 시간
        
        # YouTube 제어 변수
        self.driver = None
        self.video_playing = False
        
        # TTS 설정
        self.tts = pyttsx3.init()
        self.tts.setProperty('rate', 150)
        
        # 임계값
        self.EATING_THRESHOLD = 0.02  # 입 움직임 임계값
        self.NO_EATING_TIMEOUT = 3  # 3초간 안 먹으면 중지
        
    def setup_youtube(self, video_url="https://www.youtube.com/watch?v=dQw4w9WgXcQ"):
        """YouTube 브라우저 설정"""
        chrome_options = Options()
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            self.driver.get(video_url)
            time.sleep(3)
            
            # 전체화면 버튼 클릭 (선택사항)
            try:
                fullscreen_btn = self.driver.find_element(By.CLASS_NAME, "ytp-fullscreen-button")
                fullscreen_btn.click()
            except:
                pass
                
            # 처음엔 일시정지
            self.pause_video()
            print("YouTube 설정 완료!")
            
        except Exception as e:
            print(f"YouTube 설정 실패: {e}")
            
    def play_video(self):
        """동영상 재생"""
        if self.driver and not self.video_playing:
            try:
                play_btn = self.driver.find_element(By.CLASS_NAME, "ytp-play-button")
                if "ytp-play-button-paused" in play_btn.get_attribute("class"):
                    play_btn.click()
                    self.video_playing = True
                    print("▶️ 동영상 재생!")
            except Exception as e:
                print(f"재생 실패: {e}")
                
    def pause_video(self):
        """동영상 일시정지"""
        if self.driver and self.video_playing:
            try:
                play_btn = self.driver.find_element(By.CLASS_NAME, "ytp-play-button")
                if "ytp-play-button-paused" not in play_btn.get_attribute("class"):
                    play_btn.click()
                    self.video_playing = False
                    print("⏸️ 동영상 일시정지!")
            except Exception as e:
                print(f"일시정지 실패: {e}")
                
    def speak(self, text):
        """TTS 음성 출력"""
        def speak_thread():
            self.tts.say(text)
            self.tts.runAndWait()
        
        thread = threading.Thread(target=speak_thread)
        thread.daemon = True
        thread.start()
        
    def calculate_mouth_openness(self, landmarks):
        """입 벌어진 정도 계산"""
        if not landmarks:
            return 0
        
        # 입술 상하 거리
        upper_lip = landmarks[13]  # 윗입술 중앙
        lower_lip = landmarks[14]  # 아랫입술 중앙
        
        # 입 너비
        left_mouth = landmarks[61]
        right_mouth = landmarks[291]
        
        mouth_height = abs(upper_lip.y - lower_lip.y)
        mouth_width = abs(left_mouth.x - right_mouth.x)
        
        # 비율로 계산 (너비 대비 높이)
        if mouth_width > 0:
            return mouth_height / mouth_width
        return 0
        
    def detect_eating_behavior(self, mouth_openness):
        """식사 행동 감지"""
        self.eating_history.append(mouth_openness)
        
        if len(self.eating_history) < 10:
            return False
            
        # 최근 입 움직임의 변화량 계산
        recent_values = list(self.eating_history)[-10:]
        mouth_variation = np.std(recent_values)
        
        # 임계값보다 큰 변화가 있으면 식사 중으로 판단
        return mouth_variation > self.EATING_THRESHOLD
        
    def update_eating_state(self, is_currently_eating):
        """식사 상태 업데이트 및 YouTube 제어"""
        current_time = time.time()
        
        if is_currently_eating:
            if not self.is_eating:
                # 식사 시작!
                self.is_eating = True
                self.consecutive_eating_count += 1
                self.last_eating_time = current_time
                
                # 보상 시간 조정
                if self.consecutive_eating_count >= 3:
                    self.reward_duration = min(15, self.reward_duration + 2)
                    self.speak("와! 정말 잘 먹네요!")
                else:
                    self.speak("좋아요! 잘 먹고 있어요!")
                
                # 동영상 재생
                self.play_video()
                
                # 일정 시간 후 자동 정지 설정
                def auto_pause():
                    time.sleep(self.reward_duration)
                    if self.video_playing:
                        self.pause_video()
                        self.speak("더 먹으면 계속 보여줄게요!")
                
                thread = threading.Thread(target=auto_pause)
                thread.daemon = True
                thread.start()
                
        else:
            # 식사하지 않는 상태
            if self.is_eating and (current_time - self.last_eating_time) > self.NO_EATING_TIMEOUT:
                # 너무 오래 안 먹음
                self.is_eating = False
                self.consecutive_eating_count = 0
                self.pause_video()
                self.speak("어? 멈췄네요! 다시 먹으면 보여줄게요!")
                
    def run(self):
        """메인 실행 함수"""
        cap = cv2.VideoCapture(0)
        
        print("🍽️ 밥잘먹어YO 시작!")
        print("YouTube 영상을 설정하세요...")
        
        # YouTube 설정
        video_url = input("YouTube 영상 URL을 입력하세요 (엔터키로 기본값): ").strip()
        if not video_url:
            video_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        
        self.setup_youtube(video_url)
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
                
            # 좌우 반전
            frame = cv2.flip(frame, 1)
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # 얼굴 감지
            results = self.face_mesh.process(rgb_frame)
            
            if results.multi_face_landmarks:
                face_landmarks = results.multi_face_landmarks[0]
                
                # 입 벌어진 정도 계산
                mouth_openness = self.calculate_mouth_openness(face_landmarks.landmark)
                
                # 식사 행동 감지
                is_currently_eating = self.detect_eating_behavior(mouth_openness)
                
                # 상태 업데이트
                self.update_eating_state(is_currently_eating)
                
                # 시각적 피드백
                status_text = "😋 먹는 중!" if self.is_eating else "🤔 식사하세요"
                color = (0, 255, 0) if self.is_eating else (0, 0, 255)
                
                cv2.putText(frame, status_text, (10, 30), 
                           cv2.FONT_HERSHEY_SIMPLEX, 1, color, 2)
                cv2.putText(frame, f"연속 식사: {self.consecutive_eating_count}회", 
                           (10, 70), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                cv2.putText(frame, f"보상 시간: {self.reward_duration}초", 
                           (10, 100), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                cv2.putText(frame, f"입 움직임: {mouth_openness:.3f}", 
                           (10, 130), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                
                # 얼굴 랜드마크 그리기
                self.mp_draw.draw_landmarks(
                    frame, face_landmarks, self.mp_face_mesh.FACEMESH_CONTOURS,
                    landmark_drawing_spec=None,
                    connection_drawing_spec=self.mp_draw.DrawingSpec(
                        color=(0, 255, 0), thickness=1, circle_radius=1)
                )
                
            else:
                cv2.putText(frame, "얼굴을 찾을 수 없습니다", (10, 30), 
                           cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                
            cv2.imshow("밥잘먹어YO - 식사 모니터", frame)
            
            # ESC 키로 종료
            if cv2.waitKey(1) & 0xFF == 27:
                break
                
        # 정리
        cap.release()
        cv2.destroyAllWindows()
        if self.driver:
            self.driver.quit()
            
if __name__ == "__main__":
    app = EatingYouTubeController()
    app.run()