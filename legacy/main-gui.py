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
from webdriver_manager.chrome import ChromeDriverManager
import pyttsx3
from collections import deque
import tkinter as tk
from tkinter import ttk, messagebox
from PIL import Image, ImageTk
import queue
import traceback
import sys
import os


class EatingYouTubeGUI:
    def __init__(self):
        try:
            print("🚀 밥잘먹어YO 초기화 시작...")

            # 기본 설정
            self.setup_mediapipe()
            self.setup_variables()
            self.setup_tts()

            # GUI 설정
            self.setup_gui()

            # 큐를 통한 스레드 간 통신
            self.frame_queue = queue.Queue(maxsize=2)
            self.status_queue = queue.Queue(maxsize=10)

            # 카메라 스레드
            self.camera_thread = None
            self.running = False

            print("✅ 초기화 완료!")

        except Exception as e:
            print(f"❌ 초기화 실패: {e}")
            traceback.print_exc()

    def setup_mediapipe(self):
        """MediaPipe 설정"""
        try:
            print("MediaPipe 설정 중...")
            self.mp_face_mesh = mp.solutions.face_mesh
            self.face_mesh = self.mp_face_mesh.FaceMesh(
                static_image_mode=False,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.5,
                min_tracking_confidence=0.5,
            )
            self.mp_draw = mp.solutions.drawing_utils
            print("✅ MediaPipe 설정 완료")
        except Exception as e:
            print(f"❌ MediaPipe 설정 실패: {e}")
            raise

    def setup_variables(self):
        """상태 변수 설정"""
        print("상태 변수 설정 중...")
        self.eating_history = deque(maxlen=30)
        self.is_eating = False
        self.last_eating_time = time.time()
        self.consecutive_eating_count = 0
        self.reward_duration = 5

        # YouTube 제어
        self.driver = None
        self.video_playing = False

        # 임계값
        self.EATING_THRESHOLD = 0.02
        self.NO_EATING_TIMEOUT = 3
        print("✅ 상태 변수 설정 완료")

    def setup_tts(self):
        """TTS 설정"""
        try:
            print("TTS 설정 중...")
            self.tts = pyttsx3.init()
            self.tts.setProperty("rate", 150)
            print("✅ TTS 설정 완료")
        except Exception as e:
            print(f"⚠️ TTS 설정 실패 (계속 진행): {e}")
            self.tts = None

    def setup_gui(self):
        """GUI 설정"""
        try:
            print("GUI 설정 중...")
            self.root = tk.Tk()
            self.root.title("🍽️ 밥잘먹어YO - 스마트 식사 모니터")
            self.root.geometry("1280x720")
            self.root.configure(bg="#f0f0f0")

            # 종료 이벤트 핸들러
            self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

            # 예외 처리 핸들러
            self.root.report_callback_exception = self.handle_tk_error

            # 메인 프레임 (좌측 80%)
            self.main_frame = tk.Frame(self.root, bg="black", width=1024, height=720)
            self.main_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=False)
            self.main_frame.pack_propagate(False)

            # YouTube 영역 레이블
            self.youtube_label = tk.Label(
                self.main_frame,
                text="🎬 YouTube 영상 영역\n\n1. '🎬 YouTube' 버튼 클릭\n2. '▶️ 시작' 버튼 클릭",
                bg="black",
                fg="white",
                font=("Arial", 20),
                justify=tk.CENTER,
            )
            self.youtube_label.pack(expand=True)

            # 우측 프레임 (20%)
            self.side_frame = tk.Frame(self.root, bg="#e0e0e0", width=256, height=720)
            self.side_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=False)
            self.side_frame.pack_propagate(False)

            # 우측 상단: 카메라 영역
            self.camera_frame = tk.Frame(self.side_frame, bg="black", height=360)
            self.camera_frame.pack(fill=tk.X, padx=5, pady=5)
            self.camera_frame.pack_propagate(False)

            self.camera_label = tk.Label(
                self.camera_frame,
                text="카메라 준비 중...",
                bg="black",
                fg="white",
                font=("Arial", 12),
            )
            self.camera_label.pack(expand=True)

            # 우측 하단: 상태 정보 영역
            self.status_frame = tk.Frame(self.side_frame, bg="white", height=355)
            self.status_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
            self.status_frame.pack_propagate(False)

            # 상태 정보 텍스트
            self.status_text = tk.Text(
                self.status_frame,
                bg="white",
                fg="black",
                font=("Arial", 9),
                wrap=tk.WORD,
                state=tk.DISABLED,
                height=12,
            )
            self.status_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

            # 카메라 선택 프레임
            self.camera_select_frame = tk.Frame(self.status_frame, bg="white")
            self.camera_select_frame.pack(fill=tk.X, padx=5, pady=2)

            tk.Label(
                self.camera_select_frame, text="카메라:", bg="white", font=("Arial", 9)
            ).pack(side=tk.LEFT)

            self.camera_var = tk.StringVar(value="1")
            self.camera_combo = ttk.Combobox(
                self.camera_select_frame,
                textvariable=self.camera_var,
                values=["0", "1", "2", "3"],
                state="readonly",
                width=8,
            )
            self.camera_combo.pack(side=tk.LEFT, padx=2)
            self.camera_combo.set("1")  # 기본값: 내장캠

            # 제어 버튼들
            self.button_frame = tk.Frame(self.status_frame, bg="white")
            self.button_frame.pack(fill=tk.X, padx=5, pady=5)

            self.start_btn = tk.Button(
                self.button_frame,
                text="▶️ 시작",
                command=self.start_monitoring,
                bg="#4CAF50",
                fg="white",
                font=("Arial", 9, "bold"),
                width=8,
            )
            self.start_btn.pack(side=tk.LEFT, padx=1)

            self.stop_btn = tk.Button(
                self.button_frame,
                text="⏹️ 정지",
                command=self.stop_monitoring,
                bg="#f44336",
                fg="white",
                font=("Arial", 9, "bold"),
                width=8,
            )
            self.stop_btn.pack(side=tk.LEFT, padx=1)

            self.youtube_btn = tk.Button(
                self.button_frame,
                text="🎬 YouTube",
                command=self.setup_youtube,
                bg="#FF9800",
                fg="white",
                font=("Arial", 9, "bold"),
                width=8,
            )
            self.youtube_btn.pack(side=tk.LEFT, padx=1)

            print("✅ GUI 설정 완료")

        except Exception as e:
            print(f"❌ GUI 설정 실패: {e}")
            traceback.print_exc()
            raise

    def handle_tk_error(self, exc_type, exc_value, exc_traceback):
        """Tkinter 오류 처리"""
        print(f"Tkinter 오류: {exc_type.__name__}: {exc_value}")
        traceback.print_exception(exc_type, exc_value, exc_traceback)

    def update_status(self, message):
        """상태 텍스트 업데이트"""
        try:
            timestamp = time.strftime("%H:%M:%S")
            formatted_message = f"[{timestamp}] {message}\n"

            self.status_text.config(state=tk.NORMAL)
            self.status_text.insert(tk.END, formatted_message)
            self.status_text.see(tk.END)
            self.status_text.config(state=tk.DISABLED)

            # 콘솔에도 출력
            print(formatted_message.strip())

        except Exception as e:
            print(f"상태 업데이트 오류: {e}")

    def setup_youtube(self):
        """YouTube 브라우저 설정"""

        def setup_thread():
            try:
                self.update_status("YouTube 브라우저 설정 중...")

                chrome_options = Options()
                chrome_options.add_argument("--no-sandbox")
                chrome_options.add_argument("--disable-dev-shm-usage")
                chrome_options.add_argument("--window-size=1024,720")
                chrome_options.add_argument("--window-position=0,0")

                service = Service(ChromeDriverManager().install())
                self.driver = webdriver.Chrome(service=service, options=chrome_options)

                # YouTube Kids 영상 (Cocomelon)
                video_url = "https://www.youtube.com/watch?v=gUcisIlT7sM"
                self.driver.get(video_url)
                time.sleep(3)

                # 처음엔 일시정지
                self.pause_video()
                self.update_status("✅ YouTube 설정 완료!")

            except Exception as e:
                self.update_status(f"❌ YouTube 설정 실패: {e}")

        thread = threading.Thread(target=setup_thread)
        thread.daemon = True
        thread.start()

    def play_video(self):
        """동영상 재생"""
        if self.driver and not self.video_playing:
            try:
                self.driver.execute_script("document.querySelector('video').play();")
                self.video_playing = True
                self.update_status("▶️ 동영상 재생!")
            except Exception as e:
                self.update_status(f"재생 실패: {e}")

    def pause_video(self):
        """동영상 일시정지"""
        if self.driver:
            try:
                self.driver.execute_script("document.querySelector('video').pause();")
                self.video_playing = False
                self.update_status("⏸️ 동영상 일시정지!")
            except Exception as e:
                self.update_status(f"일시정지 실패: {e}")

    def speak(self, text):
        """TTS 음성 출력"""
        if self.tts is None:
            return

        def speak_thread():
            try:
                self.tts.say(text)
                self.tts.runAndWait()
            except Exception as e:
                print(f"TTS 오류: {e}")

        thread = threading.Thread(target=speak_thread)
        thread.daemon = True
        thread.start()

    def calculate_mouth_openness(self, landmarks):
        """입 벌어진 정도 계산"""
        if not landmarks:
            return 0

        try:
            upper_lip = landmarks[13]
            lower_lip = landmarks[14]
            left_mouth = landmarks[61]
            right_mouth = landmarks[291]

            mouth_height = abs(upper_lip.y - lower_lip.y)
            mouth_width = abs(left_mouth.x - right_mouth.x)

            if mouth_width > 0:
                return mouth_height / mouth_width
            return 0
        except Exception as e:
            print(f"입 계산 오류: {e}")
            return 0

    def detect_eating_behavior(self, mouth_openness):
        """식사 행동 감지"""
        try:
            self.eating_history.append(mouth_openness)

            if len(self.eating_history) < 10:
                return False

            recent_values = list(self.eating_history)[-10:]
            mouth_variation = np.std(recent_values)

            return mouth_variation > self.EATING_THRESHOLD
        except Exception as e:
            print(f"식사 감지 오류: {e}")
            return False

    def update_eating_state(self, is_currently_eating):
        """식사 상태 업데이트 및 YouTube 제어"""
        try:
            current_time = time.time()

            if is_currently_eating:
                if not self.is_eating:
                    self.is_eating = True
                    self.consecutive_eating_count += 1
                    self.last_eating_time = current_time

                    if self.consecutive_eating_count >= 3:
                        self.reward_duration = min(15, self.reward_duration + 2)
                        self.speak("와! 정말 잘 먹네요!")
                        self.update_status(
                            f"🎉 연속 {self.consecutive_eating_count}회! 보상 시간 {self.reward_duration}초"
                        )
                    else:
                        self.speak("좋아요! 잘 먹고 있어요!")
                        self.update_status("😋 식사 감지! 영상 재생 중...")

                    self.play_video()

                    def auto_pause():
                        time.sleep(self.reward_duration)
                        if self.video_playing:
                            self.pause_video()
                            self.update_status(
                                "⏰ 시간 종료! 더 먹으면 계속 보여줄게요!"
                            )
                            self.speak("더 먹으면 계속 보여줄게요!")

                    thread = threading.Thread(target=auto_pause)
                    thread.daemon = True
                    thread.start()

            else:
                if (
                    self.is_eating
                    and (current_time - self.last_eating_time) > self.NO_EATING_TIMEOUT
                ):
                    self.is_eating = False
                    self.consecutive_eating_count = 0
                    self.pause_video()
                    self.update_status("😴 식사 중단! 다시 먹으면 재생해요!")
                    self.speak("어? 멈췄네요! 다시 먹으면 보여줄게요!")

        except Exception as e:
            print(f"상태 업데이트 오류: {e}")

    def camera_loop(self):
        """카메라 루프"""
        cap = None
        try:
            # 선택된 카메라 인덱스 가져오기
            camera_index = int(self.camera_var.get())

            self.update_status(f"카메라 {camera_index} 초기화 중...")
            cap = cv2.VideoCapture(camera_index)

            if not cap.isOpened():
                self.update_status(f"❌ 카메라 {camera_index} 열기 실패!")
                return

            # 카메라 설정 최적화
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            cap.set(cv2.CAP_PROP_FPS, 30)

            frame_count = 0
            error_count = 0

            self.update_status(f"✅ 카메라 {camera_index} 시작 완료!")

            while self.running:
                ret, frame = cap.read()

                if not ret or frame is None:
                    error_count += 1
                    if error_count > 10:
                        self.update_status("❌ 연속 오류로 카메라 중지")
                        break
                    time.sleep(0.1)
                    continue

                error_count = 0
                frame_count += 1

                # 좌우 반전 및 크기 조정
                frame = cv2.flip(frame, 1)
                frame = cv2.resize(frame, (240, 180))

                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

                # 얼굴 감지
                results = self.face_mesh.process(rgb_frame)

                if results.multi_face_landmarks:
                    face_landmarks = results.multi_face_landmarks[0]

                    # 입 벌어진 정도 계산
                    mouth_openness = self.calculate_mouth_openness(
                        face_landmarks.landmark
                    )

                    # 식사 행동 감지
                    is_currently_eating = self.detect_eating_behavior(mouth_openness)

                    # 상태 업데이트
                    self.update_eating_state(is_currently_eating)

                    # 시각적 피드백
                    status_text = "😋 먹는 중!" if self.is_eating else "🤔 식사하세요"
                    color = (0, 255, 0) if self.is_eating else (0, 0, 255)

                    cv2.putText(
                        frame,
                        status_text,
                        (5, 20),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.5,
                        color,
                        1,
                    )
                    cv2.putText(
                        frame,
                        f"연속: {self.consecutive_eating_count}",
                        (5, 40),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.4,
                        (255, 255, 255),
                        1,
                    )
                    cv2.putText(
                        frame,
                        f"입: {mouth_openness:.3f}",
                        (5, 60),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.4,
                        (255, 255, 255),
                        1,
                    )

                else:
                    cv2.putText(
                        frame,
                        "얼굴 없음",
                        (5, 20),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.5,
                        (0, 0, 255),
                        1,
                    )

                # 프레임을 GUI로 전송
                try:
                    self.frame_queue.put_nowait(frame)
                except queue.Full:
                    try:
                        self.frame_queue.get_nowait()
                        self.frame_queue.put_nowait(frame)
                    except queue.Empty:
                        pass

                time.sleep(0.03)  # 약 30fps

        except Exception as e:
            self.update_status(f"❌ 카메라 루프 오류: {e}")
            traceback.print_exc()

        finally:
            if cap:
                cap.release()
                self.update_status("카메라 리소스 해제 완료")

    def update_camera_display(self):
        """카메라 디스플레이 업데이트"""
        try:
            frame = self.frame_queue.get_nowait()

            # OpenCV 이미지를 Tkinter용으로 변환
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            image = Image.fromarray(frame_rgb)
            photo = ImageTk.PhotoImage(image)

            self.camera_label.configure(image=photo, text="")
            self.camera_label.image = photo  # 참조 유지

        except queue.Empty:
            pass
        except Exception as e:
            print(f"디스플레이 업데이트 오류: {e}")

        # 실행 중이면 계속 업데이트
        if self.running:
            self.root.after(100, self.update_camera_display)

    def start_monitoring(self):
        """모니터링 시작"""
        try:
            if not self.running:
                self.running = True
                self.camera_thread = threading.Thread(target=self.camera_loop)
                self.camera_thread.daemon = True
                self.camera_thread.start()

                self.update_camera_display()
                self.update_status("🚀 모니터링 시작!")
        except Exception as e:
            self.update_status(f"❌ 모니터링 시작 실패: {e}")

    def stop_monitoring(self):
        """모니터링 정지"""
        try:
            self.running = False
            if self.camera_thread:
                self.camera_thread.join(timeout=1)
            self.update_status("⏹️ 모니터링 정지!")
        except Exception as e:
            self.update_status(f"❌ 모니터링 정지 실패: {e}")

    def on_closing(self):
        """앱 종료 시 정리"""
        try:
            print("앱 종료 중...")
            self.stop_monitoring()
            if self.driver:
                self.driver.quit()
            self.root.destroy()
            print("앱 종료 완료")
        except Exception as e:
            print(f"종료 중 오류: {e}")

    def run(self):
        """메인 실행"""
        try:
            print("GUI 시작...")
            self.update_status("📱 밥잘먹어YO 시작!")
            self.update_status("1. '🎬 YouTube' 버튼으로 브라우저 설정")
            self.update_status("2. '▶️ 시작' 버튼으로 모니터링 시작")

            print("메인루프 진입...")
            self.root.mainloop()
            print("메인루프 종료")

        except Exception as e:
            print(f"실행 중 오류: {e}")
            traceback.print_exc()


def main():
    """메인 함수"""
    try:
        print("=" * 50)
        print("🍽️ 밥잘먹어YO 스마트 식사 모니터")
        print("=" * 50)

        app = EatingYouTubeGUI()
        app.run()

    except Exception as e:
        print(f"앱 실행 실패: {e}")
        traceback.print_exc()
        input("엔터키를 눌러 종료...")


if __name__ == "__main__":
    main()
