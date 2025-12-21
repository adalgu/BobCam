import cv2
import mediapipe as mp
import numpy as np
import time
import threading
import pyttsx3
from collections import deque
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from PIL import Image, ImageTk
import queue
import traceback
import os
import gc


class ThreadSafeVideoPlayer:
    def __init__(self):
        try:
            print("🚀 밥잘먹어YO 초기화 시작...")

            # 스레드 안전을 위한 락
            self.face_mesh_lock = threading.Lock()
            self.video_lock = threading.Lock()

            # 기본 설정
            self.setup_variables()
            self.setup_tts()
            self.setup_gui()

            # MediaPipe는 메인 스레드에서만 초기화
            self.setup_mediapipe()

            # 큐 설정
            self.camera_queue = queue.Queue(maxsize=2)
            self.video_queue = queue.Queue(maxsize=5)
            self.face_result_queue = queue.Queue(maxsize=2)

            # 스레드 관리
            self.camera_thread = None
            self.video_thread = None
            self.face_processing_thread = None

            self.camera_running = False
            self.video_running = False
            self.face_processing_running = False

            print("✅ 초기화 완료!")

        except Exception as e:
            print(f"❌ 초기화 실패: {e}")
            traceback.print_exc()

    def setup_mediapipe(self):
        """MediaPipe 설정 - 메인 스레드에서만"""
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

        # 비디오 제어
        self.video_cap = None
        self.video_playing = False
        self.video_paused = True
        self.video_file_path = None

        # 임계값
        self.EATING_THRESHOLD = 0.02
        self.NO_EATING_TIMEOUT = 3

        # 자동 일시정지 타이머
        self.auto_pause_timer = None

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
            self.root.title("🍽️ 밥잘먹어YO - 안전한 로컬 비디오 버전")
            self.root.geometry("1280x720")
            self.root.configure(bg="#f0f0f0")

            # 종료 이벤트 핸들러
            self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

            # 메인 프레임 (좌측 80% - 비디오 영역)
            self.main_frame = tk.Frame(self.root, bg="black", width=1024, height=720)
            self.main_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=False)
            self.main_frame.pack_propagate(False)

            # 비디오 라벨
            self.video_label = tk.Label(
                self.main_frame,
                text="🎬 비디오 영역\n\n'📁 파일 선택' 버튼으로\nclip.mp4를 선택하세요",
                bg="black",
                fg="white",
                font=("Arial", 20),
                justify=tk.CENTER,
            )
            self.video_label.pack(expand=True)

            # 우측 프레임 (20%)
            self.side_frame = tk.Frame(self.root, bg="#e0e0e0", width=256, height=720)
            self.side_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=False)
            self.side_frame.pack_propagate(False)

            # 우측 상단: 카메라 영역
            self.camera_frame = tk.Frame(self.side_frame, bg="black", height=300)
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
            self.status_frame = tk.Frame(self.side_frame, bg="white", height=415)
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
                height=10,
            )
            self.status_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

            # 파일 선택 프레임
            self.file_frame = tk.Frame(self.status_frame, bg="white")
            self.file_frame.pack(fill=tk.X, padx=5, pady=2)

            self.file_btn = tk.Button(
                self.file_frame,
                text="📁 파일 선택",
                command=self.select_video_file,
                bg="#9C27B0",
                fg="white",
                font=("Arial", 9, "bold"),
            )
            self.file_btn.pack(fill=tk.X, pady=2)

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
            self.camera_combo.set("1")

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
                width=10,
            )
            self.start_btn.pack(fill=tk.X, pady=1)

            self.stop_btn = tk.Button(
                self.button_frame,
                text="⏹️ 정지",
                command=self.stop_monitoring,
                bg="#f44336",
                fg="white",
                font=("Arial", 9, "bold"),
                width=10,
            )
            self.stop_btn.pack(fill=tk.X, pady=1)

            # 수동 제어 버튼들
            self.manual_frame = tk.Frame(self.status_frame, bg="white")
            self.manual_frame.pack(fill=tk.X, padx=5, pady=2)

            tk.Label(
                self.manual_frame,
                text="수동 제어:",
                bg="white",
                font=("Arial", 9, "bold"),
            ).pack()

            control_btn_frame = tk.Frame(self.manual_frame, bg="white")
            control_btn_frame.pack(fill=tk.X)

            self.play_btn = tk.Button(
                control_btn_frame,
                text="▶️ 재생",
                command=self.manual_play,
                bg="#2196F3",
                fg="white",
                font=("Arial", 8),
            )
            self.play_btn.pack(side=tk.LEFT, padx=1, fill=tk.X, expand=True)

            self.pause_btn = tk.Button(
                control_btn_frame,
                text="⏸️ 일시정지",
                command=self.manual_pause,
                bg="#FF9800",
                fg="white",
                font=("Arial", 8),
            )
            self.pause_btn.pack(side=tk.LEFT, padx=1, fill=tk.X, expand=True)

            print("✅ GUI 설정 완료")

        except Exception as e:
            print(f"❌ GUI 설정 실패: {e}")
            traceback.print_exc()
            raise

    def select_video_file(self):
        """비디오 파일 선택"""
        try:
            # 먼저 루트 폴더의 clip.mp4 확인
            default_file = "clip.mp4"
            if os.path.exists(default_file):
                self.video_file_path = default_file
                self.update_status(f"✅ 기본 파일 선택: {default_file}")
                self.load_video()
                return

            # 없으면 파일 다이얼로그 열기
            file_path = filedialog.askopenfilename(
                title="비디오 파일 선택",
                filetypes=[
                    ("비디오 파일", "*.mp4 *.avi *.mov *.mkv"),
                    ("모든 파일", "*.*"),
                ],
            )

            if file_path:
                self.video_file_path = file_path
                self.update_status(f"✅ 파일 선택: {os.path.basename(file_path)}")
                self.load_video()
            else:
                self.update_status("파일 선택이 취소되었습니다.")

        except Exception as e:
            self.update_status(f"❌ 파일 선택 오류: {e}")

    def load_video(self):
        """비디오 로드"""
        try:
            with self.video_lock:
                if self.video_cap:
                    self.video_cap.release()

                self.video_cap = cv2.VideoCapture(self.video_file_path)

                if not self.video_cap.isOpened():
                    self.update_status("❌ 비디오 파일을 열 수 없습니다!")
                    return

                # 비디오 정보
                fps = self.video_cap.get(cv2.CAP_PROP_FPS)
                frame_count = int(self.video_cap.get(cv2.CAP_PROP_FRAME_COUNT))
                duration = frame_count / fps if fps > 0 else 0

                self.update_status(f"📹 비디오 로드 완료!")
                self.update_status(f"   FPS: {fps:.1f}, 길이: {duration:.1f}초")

                # 비디오 스레드 시작
                if not self.video_running:
                    self.video_running = True
                    self.video_thread = threading.Thread(target=self.video_loop)
                    self.video_thread.daemon = True
                    self.video_thread.start()

                    # 비디오 디스플레이 업데이트 시작
                    self.update_video_display()

        except Exception as e:
            self.update_status(f"❌ 비디오 로드 오류: {e}")

    def video_loop(self):
        """비디오 재생 루프"""
        frame_delay = 1.0 / 30.0  # 30fps

        try:
            while self.video_running:
                if not self.video_paused and self.video_cap:
                    with self.video_lock:
                        if self.video_cap and self.video_cap.isOpened():
                            ret, frame = self.video_cap.read()

                            if not ret:
                                # 비디오 끝에 도달하면 처음으로 돌아가기
                                self.video_cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                                continue

                            # 프레임 크기 조정
                            frame = cv2.resize(frame, (1000, 680))

                            # 큐에 프레임 전송
                            try:
                                self.video_queue.put_nowait(frame)
                            except queue.Full:
                                try:
                                    self.video_queue.get_nowait()
                                    self.video_queue.put_nowait(frame)
                                except queue.Empty:
                                    pass

                    time.sleep(frame_delay)
                else:
                    time.sleep(0.1)  # 일시정지 중에는 잠시 대기

        except Exception as e:
            self.update_status(f"❌ 비디오 루프 오류: {e}")

    def face_processing_loop(self):
        """얼굴 처리 전용 루프 - 별도 스레드"""
        try:
            while self.face_processing_running:
                try:
                    # 카메라 프레임을 기다림
                    frame_data = self.face_result_queue.get(timeout=0.1)
                    frame, original_frame = frame_data

                    # MediaPipe 처리는 락 사용
                    with self.face_mesh_lock:
                        if self.face_mesh:
                            results = self.face_mesh.process(frame)

                            mouth_openness = 0
                            face_detected = False

                            if results.multi_face_landmarks:
                                face_landmarks = results.multi_face_landmarks[0]
                                mouth_openness = self.calculate_mouth_openness(
                                    face_landmarks.landmark
                                )
                                face_detected = True

                                # 시각적 피드백 추가
                                status_text = (
                                    "😋 먹는 중!" if self.is_eating else "🤔 식사하세요"
                                )
                                color = (0, 255, 0) if self.is_eating else (0, 0, 255)

                                cv2.putText(
                                    original_frame,
                                    status_text,
                                    (5, 20),
                                    cv2.FONT_HERSHEY_SIMPLEX,
                                    0.5,
                                    color,
                                    1,
                                )
                                cv2.putText(
                                    original_frame,
                                    f"연속: {self.consecutive_eating_count}",
                                    (5, 40),
                                    cv2.FONT_HERSHEY_SIMPLEX,
                                    0.4,
                                    (255, 255, 255),
                                    1,
                                )
                                cv2.putText(
                                    original_frame,
                                    f"입: {mouth_openness:.3f}",
                                    (5, 60),
                                    cv2.FONT_HERSHEY_SIMPLEX,
                                    0.4,
                                    (255, 255, 255),
                                    1,
                                )
                            else:
                                cv2.putText(
                                    original_frame,
                                    "얼굴 없음",
                                    (5, 20),
                                    cv2.FONT_HERSHEY_SIMPLEX,
                                    0.5,
                                    (0, 0, 255),
                                    1,
                                )

                            # 식사 행동 감지 및 상태 업데이트 (메인 스레드에서 실행)
                            if face_detected:
                                self.root.after(
                                    0,
                                    lambda: self.process_eating_detection(
                                        mouth_openness
                                    ),
                                )

                            # 처리된 프레임을 카메라 큐에 전송
                            try:
                                self.camera_queue.put_nowait(original_frame)
                            except queue.Full:
                                try:
                                    self.camera_queue.get_nowait()
                                    self.camera_queue.put_nowait(original_frame)
                                except queue.Empty:
                                    pass

                except queue.Empty:
                    continue
                except Exception as e:
                    print(f"얼굴 처리 오류: {e}")
                    time.sleep(0.1)

        except Exception as e:
            print(f"얼굴 처리 루프 오류: {e}")

    def process_eating_detection(self, mouth_openness):
        """식사 감지 처리 - 메인 스레드에서 실행"""
        try:
            is_currently_eating = self.detect_eating_behavior(mouth_openness)
            self.update_eating_state(is_currently_eating)
        except Exception as e:
            print(f"식사 감지 처리 오류: {e}")

    def camera_loop(self):
        """카메라 루프 - MediaPipe 처리 제외"""
        cap = None
        try:
            camera_index = int(self.camera_var.get())

            self.update_status(f"카메라 {camera_index} 초기화 중...")
            cap = cv2.VideoCapture(camera_index)

            if not cap.isOpened():
                self.update_status(f"❌ 카메라 {camera_index} 열기 실패!")
                return

            # 카메라 설정
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            cap.set(cv2.CAP_PROP_FPS, 30)

            error_count = 0
            self.update_status(f"✅ 카메라 시작!")

            while self.camera_running:
                ret, frame = cap.read()

                if not ret or frame is None:
                    error_count += 1
                    if error_count > 10:
                        self.update_status("❌ 카메라 오류로 중지")
                        break
                    time.sleep(0.1)
                    continue

                error_count = 0

                # 좌우 반전 및 크기 조정
                frame = cv2.flip(frame, 1)
                frame = cv2.resize(frame, (240, 180))
                original_frame = frame.copy()

                # RGB 변환 (MediaPipe용)
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

                # 얼굴 처리 스레드로 전송
                try:
                    self.face_result_queue.put_nowait((rgb_frame, original_frame))
                except queue.Full:
                    try:
                        self.face_result_queue.get_nowait()
                        self.face_result_queue.put_nowait((rgb_frame, original_frame))
                    except queue.Empty:
                        pass

                time.sleep(0.03)  # 약 30fps

        except Exception as e:
            self.update_status(f"❌ 카메라 루프 오류: {e}")

        finally:
            if cap:
                cap.release()
                self.update_status("카메라 리소스 해제")

    def update_video_display(self):
        """비디오 디스플레이 업데이트"""
        try:
            frame = self.video_queue.get_nowait()

            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            image = Image.fromarray(frame_rgb)
            photo = ImageTk.PhotoImage(image)

            self.video_label.configure(image=photo, text="")
            self.video_label.image = photo

        except queue.Empty:
            pass
        except Exception as e:
            print(f"비디오 디스플레이 오류: {e}")

        if self.video_running:
            self.root.after(33, self.update_video_display)

    def update_camera_display(self):
        """카메라 디스플레이 업데이트"""
        try:
            frame = self.camera_queue.get_nowait()

            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            image = Image.fromarray(frame_rgb)
            photo = ImageTk.PhotoImage(image)

            self.camera_label.configure(image=photo, text="")
            self.camera_label.image = photo

        except queue.Empty:
            pass
        except Exception as e:
            print(f"카메라 디스플레이 오류: {e}")

        if self.camera_running:
            self.root.after(100, self.update_camera_display)

    def manual_play(self):
        """수동 재생"""
        self.video_paused = False
        self.update_status("▶️ 수동 재생")

    def manual_pause(self):
        """수동 일시정지"""
        self.video_paused = True
        if self.auto_pause_timer:
            self.auto_pause_timer = None
        self.update_status("⏸️ 수동 일시정지")

    def play_video(self):
        """자동 재생 (식사 감지 시)"""
        self.video_paused = False
        self.update_status("▶️ 자동 재생! (식사 감지)")

    def pause_video(self):
        """자동 일시정지"""
        self.video_paused = True
        self.update_status("⏸️ 자동 일시정지")

    def update_status(self, message):
        """상태 텍스트 업데이트"""
        try:
            timestamp = time.strftime("%H:%M:%S")
            formatted_message = f"[{timestamp}] {message}\n"

            self.status_text.config(state=tk.NORMAL)
            self.status_text.insert(tk.END, formatted_message)
            self.status_text.see(tk.END)
            self.status_text.config(state=tk.DISABLED)

            print(formatted_message.strip())

        except Exception as e:
            print(f"상태 업데이트 오류: {e}")

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
            return False

    def update_eating_state(self, is_currently_eating):
        """식사 상태 업데이트 및 비디오 제어"""
        try:
            current_time = time.time()

            if is_currently_eating:
                if not self.is_eating:
                    self.is_eating = True
                    self.consecutive_eating_count += 1
                    self.last_eating_time = current_time

                    # 기존 타이머 취소
                    if self.auto_pause_timer:
                        self.auto_pause_timer = None

                    if self.consecutive_eating_count >= 3:
                        self.reward_duration = min(15, self.reward_duration + 2)
                        self.speak("와! 정말 잘 먹네요!")
                        self.update_status(
                            f"🎉 연속 {self.consecutive_eating_count}회! 보상 {self.reward_duration}초"
                        )
                    else:
                        self.speak("좋아요! 잘 먹고 있어요!")
                        self.update_status("😋 식사 감지! 비디오 재생!")

                    self.play_video()

                    # 자동 일시정지 스케줄링 (메인 스레드에서)
                    def schedule_auto_pause():
                        if (
                            self.auto_pause_timer == current_time
                        ):  # 타이머가 유효한 경우에만
                            if not self.video_paused:
                                self.pause_video()
                                self.speak("더 먹으면 계속 보여줄게요!")

                    self.auto_pause_timer = current_time
                    self.root.after(self.reward_duration * 1000, schedule_auto_pause)

            else:
                if (
                    self.is_eating
                    and (current_time - self.last_eating_time) > self.NO_EATING_TIMEOUT
                ):
                    self.is_eating = False
                    self.consecutive_eating_count = 0
                    self.auto_pause_timer = None  # 타이머 취소
                    self.pause_video()
                    self.update_status("😴 식사 중단! 다시 먹으면 재생해요!")
                    self.speak("어? 멈췄네요! 다시 먹으면 보여줄게요!")

        except Exception as e:
            print(f"상태 업데이트 오류: {e}")

    def start_monitoring(self):
        """모니터링 시작"""
        try:
            if not self.camera_running:
                # 얼굴 처리 스레드 시작
                self.face_processing_running = True
                self.face_processing_thread = threading.Thread(
                    target=self.face_processing_loop
                )
                self.face_processing_thread.daemon = True
                self.face_processing_thread.start()

                # 카메라 스레드 시작
                self.camera_running = True
                self.camera_thread = threading.Thread(target=self.camera_loop)
                self.camera_thread.daemon = True
                self.camera_thread.start()

                self.update_camera_display()
                self.update_status("🚀 카메라 모니터링 시작!")

        except Exception as e:
            self.update_status(f"❌ 모니터링 시작 실패: {e}")

    def stop_monitoring(self):
        """모니터링 정지"""
        try:
            self.camera_running = False
            self.face_processing_running = False

            if self.camera_thread:
                self.camera_thread.join(timeout=1)
            if self.face_processing_thread:
                self.face_processing_thread.join(timeout=1)

            self.update_status("⏹️ 모니터링 정지!")

        except Exception as e:
            self.update_status(f"❌ 모니터링 정지 실패: {e}")

    def on_closing(self):
        """앱 종료 시 정리"""
        try:
            print("앱 종료 중...")

            # 모든 스레드 정지
            self.camera_running = False
            self.video_running = False
            self.face_processing_running = False

            # 스레드 종료 대기
            if self.camera_thread:
                self.camera_thread.join(timeout=2)
            if self.video_thread:
                self.video_thread.join(timeout=2)
            if self.face_processing_thread:
                self.face_processing_thread.join(timeout=2)

            # MediaPipe 리소스 정리
            with self.face_mesh_lock:
                if hasattr(self, "face_mesh") and self.face_mesh:
                    self.face_mesh.close()
                    self.face_mesh = None

            # 비디오 리소스 정리
            with self.video_lock:
                if self.video_cap:
                    self.video_cap.release()
                    self.video_cap = None

            # 가비지 컬렉션
            gc.collect()

            self.root.destroy()
            print("앱 종료 완료")

        except Exception as e:
            print(f"종료 중 오류: {e}")
            try:
                self.root.destroy()
            except:
                pass

    def run(self):
        """메인 실행"""
        try:
            print("GUI 시작...")
            self.update_status("📱 밥잘먹어YO - 안전한 로컬 비디오 버전")
            self.update_status("1. '📁 파일 선택'으로 clip.mp4 선택")
            self.update_status("2. '▶️ 시작'으로 카메라 모니터링 시작")
            self.update_status("3. 입을 움직이면 자동으로 비디오 재생!")

            self.root.mainloop()

        except Exception as e:
            print(f"실행 중 오류: {e}")
            traceback.print_exc()


def main():
    """메인 함수"""
    try:
        print("=" * 50)
        print("🍽️ 밥잘먹어YO - 스레드 안전 버전")
        print("=" * 50)

        app = ThreadSafeVideoPlayer()
        app.run()

    except Exception as e:
        print(f"앱 실행 실패: {e}")
        traceback.print_exc()
        input("엔터키를 눌러 종료...")


if __name__ == "__main__":
    main()
