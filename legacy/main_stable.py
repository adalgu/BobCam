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


class EatingStatus:
    """
    식사 상태를 감지하고 관리하는 클래스.
    감지 로직을 GUI와 분리하여 안정성을 높입니다.
    """

    def __init__(self):
        # 감지 관련 설정
        self.MOUTH_OPEN_THRESHOLD = 0.02  # 입이 열렸다고 판단하는 높이 임계값
        self.HEIGHT_STD_THRESHOLD = 0.03  # 입 높이 변화(움직임) 임계값
        self.RATIO_STD_THRESHOLD = 0.02  # 입 비율 변화(움직임) 임계값
        self.NO_EATING_TIMEOUT = 60  # 2초 (30fps * 3)
        self.EATING_CONFIRM_COUNT = 15  # 0.5초 (30fps * 0.5)

        # 상태 변수
        self.height_history = deque(maxlen=60)  # 2초간의 입 높이 데이터
        self.ratio_history = deque(maxlen=60)  # 2초간의 입 비율 데이터
        self.is_eating = False
        self.last_eating_time = time.time()

        self.eating_counter = 0
        self.not_eating_counter = 0
        self.consecutive_eating_sessions = 0

    def detect_eating_behavior(self, mouth_height, mouth_aspect_ratio):
        """
        입의 세부 상태(열림/닫힘, 움직임/멈춤)를 판단하고,
        이를 기반으로 최종 식사 상태를 결정합니다.
        """
        self.height_history.append(mouth_height)
        self.ratio_history.append(mouth_aspect_ratio)

        states = {
            "is_eating": self.is_eating,
            "mouth_state": "닫힘",
            "movement_state": "멈춤",
        }

        if len(self.height_history) < self.height_history.maxlen:
            return states  # 데이터가 충분히 쌓일 때까지 대기

        # 1. 입 열림/닫힘 상태 결정
        if mouth_height > self.MOUTH_OPEN_THRESHOLD:
            states["mouth_state"] = "열림"
        else:
            states["mouth_state"] = "닫힘"

        # 2. 입 움직임/멈춤 상태 결정
        height_std = np.std(self.height_history)
        ratio_std = np.std(self.ratio_history)

        if (
            height_std > self.HEIGHT_STD_THRESHOLD
            or ratio_std > self.RATIO_STD_THRESHOLD
        ):
            states["movement_state"] = "움직임"
            self.eating_counter += 1
            self.not_eating_counter = 0
        else:
            states["movement_state"] = "멈춤"
            self.not_eating_counter += 1
            self.eating_counter = 0

        # 3. 최종 식사 상태 결정 (Hysteresis 적용)
        if self.eating_counter > self.EATING_CONFIRM_COUNT:
            if not self.is_eating:
                self.is_eating = True
                self.consecutive_eating_sessions += 1
            self.last_eating_time = time.time()
        elif self.not_eating_counter > self.NO_EATING_TIMEOUT:
            if self.is_eating:
                self.is_eating = False
                self.consecutive_eating_sessions = 0

        states["is_eating"] = self.is_eating
        return states


class EatingMonitorApp:
    def __init__(self, root):
        self.root = root
        self.stop_event = threading.Event()

        print("🚀 밥잘먹어YO v2 초기화 시작...")

        # 큐 설정
        self.camera_queue = queue.Queue(maxsize=2)

        # 모듈 설정
        self.eating_status = EatingStatus()
        self.setup_variables()
        self.setup_mediapipe()
        self.setup_tts()
        self.setup_gui()

        # 스레드 관리
        self.camera_thread = None

        print("✅ 초기화 완료!")

    def setup_variables(self):
        print("상태 변수 설정 중...")
        self.last_logged_mouth_state = ""
        self.video_cap = None
        self.video_playing = False
        self.video_paused = True
        self.video_file_path = None
        self.status_labels = {}  # 아이콘 라벨을 저장할 딕셔너리

        # 화면 페이드 효과를 위한 변수
        self.overlay_alpha = 0.0  # 오버레이 투명도 (0.0: 투명, 1.0: 불투명)
        self.fade_direction = 0  # 1: 어두워짐, -1: 밝아짐, 0: 유지
        self.fade_speed = 0.02  # 페이드 속도
        self.max_alpha = 0.8  # 최대 어두워지는 정도

        print("✅ 상태 변수 설정 완료")

    def setup_mediapipe(self):
        print("MediaPipe 설정 중...")
        self.mp_face_mesh = mp.solutions.face_mesh
        self.mp_drawing = mp.solutions.drawing_utils
        self.drawing_spec = self.mp_drawing.DrawingSpec(
            thickness=2, circle_radius=1, color=(0, 255, 0)
        )
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        print("✅ MediaPipe 설정 완료")

    def setup_tts(self):
        try:
            print("TTS 설정 중...")
            self.tts = pyttsx3.init()
            self.tts.setProperty("rate", 150)
            print("✅ TTS 설정 완료")
        except Exception as e:
            print(f"⚠️ TTS 설정 실패 (계속 진행): {e}")
            self.tts = None

    def setup_gui(self):
        print("GUI 설정 중...")
        self.root.title("🍽️ 밥잘먹어YO - 안정 버전")
        self.root.geometry("1280x720")
        self.root.configure(bg="#f0f0f0")
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

        # 레이아웃 설정 (수정: side_frame을 먼저 pack하여 너비 고정)
        self.side_frame = tk.Frame(self.root, bg="#e0e0e0", width=280)
        self.side_frame.pack(side=tk.RIGHT, fill=tk.Y, expand=False)
        self.side_frame.pack_propagate(False)

        self.main_frame = tk.Frame(self.root, bg="black")
        self.main_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.video_label = tk.Label(self.main_frame, bg="black")
        self.video_label.pack(expand=True)

        self.camera_frame = tk.Frame(self.side_frame, bg="black", height=210)
        self.camera_frame.pack(fill=tk.X, padx=10, pady=10)
        self.camera_frame.pack_propagate(False)
        self.camera_label = tk.Label(self.camera_frame, bg="black")
        self.camera_label.pack(expand=True)

        # 상태 아이콘 바 추가
        self.icon_bar_frame = tk.Frame(self.side_frame, bg="#f0f0f0", height=40)
        self.icon_bar_frame.pack(fill=tk.X, padx=10, pady=5)
        self.icon_bar_frame.pack_propagate(False)

        self.create_status_icons(self.icon_bar_frame)

        self.status_frame = tk.Frame(self.side_frame, bg="white")
        self.status_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))

        self.status_text = tk.Text(
            self.status_frame,
            bg="white",
            fg="black",
            font=("Arial", 10),
            wrap=tk.WORD,
            state=tk.DISABLED,
            height=10,
        )
        self.status_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        # 컨트롤 UI
        ttk.Button(
            self.status_frame, text="📁 파일 선택", command=self.select_video_file
        ).pack(fill=tk.X, padx=5, pady=2)

        cam_frame = ttk.Frame(self.status_frame)
        cam_frame.pack(fill=tk.X, padx=5, pady=2)
        ttk.Label(cam_frame, text="카메라:").pack(side=tk.LEFT)
        self.camera_var = tk.StringVar(value="1")
        self.camera_combo = ttk.Combobox(
            cam_frame,
            textvariable=self.camera_var,
            values=["0", "1", "2", "3"],
            state="readonly",
            width=5,
        )
        self.camera_combo.pack(side=tk.LEFT, padx=5)
        self.camera_combo.set("1")

        self.start_btn = ttk.Button(
            self.status_frame, text="▶️ 모니터링 시작", command=self.start_monitoring
        )
        self.start_btn.pack(fill=tk.X, padx=5, pady=2)
        self.stop_btn = ttk.Button(
            self.status_frame,
            text="⏹️ 모니터링 정지",
            command=self.stop_monitoring,
            state=tk.DISABLED,
        )
        self.stop_btn.pack(fill=tk.X, padx=5, pady=2)

        manual_frame = ttk.LabelFrame(self.status_frame, text="수동 제어")
        manual_frame.pack(fill=tk.X, padx=5, pady=5, ipady=2)

        self.play_btn = ttk.Button(
            manual_frame, text="▶️ 재생", command=self.manual_play
        )
        self.play_btn.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=2)

        self.pause_btn = ttk.Button(
            manual_frame, text="⏸️ 일시정지", command=self.manual_pause
        )
        self.pause_btn.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=2)

        print("✅ GUI 설정 완료")

    def create_status_icons(self, parent_frame):
        """상태 아이콘을 생성하고 배치합니다."""
        icon_font = ("Arial", 14)
        text_font = ("Arial", 9)

        icons = {"face": "얼굴", "mouth": "입 상태", "move": "움직임", "eat": "식사"}

        for name, text in icons.items():
            frame = tk.Frame(parent_frame, bg=parent_frame.cget("bg"))
            frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH)

            icon_label = tk.Label(
                frame, text="?", font=icon_font, bg=parent_frame.cget("bg"), fg="gray"
            )
            icon_label.pack(pady=(2, 0))

            text_label = tk.Label(
                frame, text=text, font=text_font, bg=parent_frame.cget("bg"), fg="black"
            )
            text_label.pack()

            self.status_labels[name] = icon_label

    def select_video_file(self):
        default_file = "clip.mp4"
        if os.path.exists(default_file):
            file_path = default_file
        else:
            file_path = filedialog.askopenfilename(
                filetypes=[("Video files", "*.mp4 *.avi *.mov")]
            )

        if file_path:
            self.video_file_path = file_path
            self.load_video()

    def load_video(self):
        if self.video_cap:
            self.video_cap.release()

        self.video_cap = cv2.VideoCapture(self.video_file_path)
        if not self.video_cap.isOpened():
            messagebox.showerror("오류", "비디오 파일을 열 수 없습니다.")
            return

        fps = self.video_cap.get(cv2.CAP_PROP_FPS)
        self.frame_delay = int(1000 / fps) if fps > 0 else 33
        self.update_status(f"📹 '{os.path.basename(self.video_file_path)}' 로드 완료")

    def start_monitoring(self):
        if self.camera_thread and self.camera_thread.is_alive():
            self.update_status("⚠️ 이미 모니터링이 실행 중입니다.")
            return

        if not self.video_file_path:
            messagebox.showwarning("알림", "먼저 비디오 파일을 선택해주세요.")
            return

        self.stop_event.clear()
        self.camera_thread = threading.Thread(target=self.camera_loop)
        self.camera_thread.daemon = True
        self.camera_thread.start()

        self.start_btn.config(state=tk.DISABLED)
        self.stop_btn.config(state=tk.NORMAL)

        self.update_status("🚀 카메라 모니터링 시작!")
        self.process_frames()  # 메인 스레드에서 프레임 처리 시작

    def stop_monitoring(self):
        self.stop_event.set()
        if self.camera_thread:
            self.camera_thread.join(timeout=1)

        self.start_btn.config(state=tk.NORMAL)
        self.stop_btn.config(state=tk.DISABLED)
        self.update_status("⏹️ 모니터링 정지!")

    def camera_loop(self):
        try:
            cam_idx = int(self.camera_var.get())
            cap = cv2.VideoCapture(cam_idx)
            if not cap.isOpened():
                self.update_status(f"❌ 카메라 {cam_idx} 열기 실패!")
                return

            while not self.stop_event.is_set():
                ret, frame = cap.read()
                if not ret:
                    time.sleep(0.1)
                    continue

                try:
                    self.camera_queue.put_nowait(frame)
                except queue.Full:
                    pass  # 큐가 꽉 차면 프레임 드롭

            cap.release()
            self.update_status("카메라 리소스 해제")
        except Exception as e:
            self.update_status(f"❌ 카메라 루프 오류: {e}")

    def process_frames(self):
        """메인 스레드에서 실행되는 프레임 처리 및 GUI 업데이트"""
        if self.stop_event.is_set():
            return

        try:
            # 카메라 프레임 처리
            cam_frame = self.camera_queue.get_nowait()
            self.update_camera_feed(cam_frame)

            # 비디오 프레임 처리
            if not self.video_paused and self.video_cap:
                ret, video_frame = self.video_cap.read()
                if not ret:
                    self.video_cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    ret, video_frame = self.video_cap.read()

                if ret:
                    self.update_video_display(video_frame)

        except queue.Empty:
            pass  # 처리할 프레임 없음
        except Exception as e:
            self.update_status(f"프레임 처리 오류: {e}")

        self.root.after(15, self.process_frames)  # 약 60fps로 반복

    def update_camera_feed(self, frame):
        frame = cv2.flip(frame, 1)

        # 얼굴 감지 및 상태 업데이트
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.face_mesh.process(rgb_frame)

        face_detected = False
        if results.multi_face_landmarks:
            face_detected = True
            face_landmarks = results.multi_face_landmarks[0]

            # 입술 랜드마크 그리기
            self.mp_drawing.draw_landmarks(
                image=frame,
                landmark_list=face_landmarks,
                connections=self.mp_face_mesh.FACEMESH_LIPS,
                landmark_drawing_spec=None,
                connection_drawing_spec=self.drawing_spec,
            )

            mouth_height, mouth_width, mouth_aspect_ratio = (
                self.calculate_mouth_features(face_landmarks.landmark)
            )

            was_eating = self.eating_status.is_eating
            states = self.eating_status.detect_eating_behavior(
                mouth_height, mouth_aspect_ratio
            )
            is_eating = states["is_eating"]
            mouth_state_str = (
                f"입: {states['mouth_state']}, 움직임: {states['movement_state']}"
            )

            # 상태 변경 시 로그 추가
            current_log_state = (
                f"{mouth_state_str}, 최종: {'식사 중' if is_eating else '식사 멈춤'}"
            )
            if current_log_state != self.last_logged_mouth_state:
                self.update_status(f"상태 감지: {current_log_state}")
                self.last_logged_mouth_state = current_log_state

            # 비디오 제어 로직
            if is_eating != was_eating:
                if is_eating:
                    self.video_paused = False
                    self.update_status("▶️ 식사 시작! 비디오를 재생합니다.")
                    self.speak("잘 먹네요! 영상 보세요!")
                else:
                    self.video_paused = True
                    self.update_status("⏸️ 식사 멈춤! 비디오를 일시정지합니다.")
                    self.speak("밥 먹어야 보여줄 거예요.")

            # 화면 페이드 방향 결정
            if states["movement_state"] == "움직임":
                self.fade_direction = -1  # 밝아짐
            else:
                self.fade_direction = 1  # 어두워짐

            # 시각적 피드백
            status_text = "😋 먹는 중!" if is_eating else "🤔 식사하세요"
            color = (0, 255, 0) if is_eating else (0, 0, 255)
            cv2.putText(
                frame, status_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2
            )
            cv2.putText(
                frame,
                mouth_state_str,
                (10, 60),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (255, 255, 255),
                1,
            )

        if not face_detected:
            states = self.eating_status.detect_eating_behavior(
                0, 0
            )  # 얼굴 없으면 0, 0으로 처리
            if self.eating_status.is_eating:
                self.video_paused = True
                self.update_status("⏸️ 얼굴 감지 실패! 비디오를 일시정지합니다.")

        self.update_status_icons(face_detected, states)

        # 카메라 GUI 업데이트
        cam_img = cv2.resize(frame, (260, 195))
        self.display_image(cam_img, self.camera_label)

    def update_status_icons(self, face_detected, states):
        """GUI의 상태 아이콘을 업데이트합니다."""
        # 얼굴 감지
        if face_detected:
            self.status_labels["face"].config(text="●", fg="green")
        else:
            self.status_labels["face"].config(text="○", fg="red")

        # 입 상태
        if states["mouth_state"] == "열림":
            self.status_labels["mouth"].config(text="👄", fg="blue")
        else:
            self.status_labels["mouth"].config(text="👄", fg="gray")

        # 움직임 상태
        if states["movement_state"] == "움직임":
            self.status_labels["move"].config(text="🏃", fg="blue")
        else:
            self.status_labels["move"].config(text="🏃", fg="gray")

        # 식사 상태
        if states["is_eating"]:
            self.status_labels["eat"].config(text="🍽️", fg="green")
        else:
            self.status_labels["eat"].config(text="🍽️", fg="red")

    def update_video_display(self, frame):
        # 페이드 효과 적용
        if self.fade_direction != 0:
            self.overlay_alpha += self.fade_direction * self.fade_speed
            self.overlay_alpha = np.clip(self.overlay_alpha, 0, self.max_alpha)

        if self.overlay_alpha > 0:
            overlay = np.zeros_like(frame, dtype=np.uint8)
            frame = cv2.addWeighted(
                frame, 1 - self.overlay_alpha, overlay, self.overlay_alpha, 0
            )

        w, h = self.main_frame.winfo_width(), self.main_frame.winfo_height()
        if h > 1 and w > 1:
            frame = cv2.resize(frame, (w, h))
            self.display_image(frame, self.video_label)

    def display_image(self, frame, label):
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        image = Image.fromarray(frame_rgb)
        photo = ImageTk.PhotoImage(image)
        label.configure(image=photo)
        label.image = photo

    def calculate_mouth_features(self, landmarks):
        try:
            # Key landmarks for mouth
            upper_lip = landmarks[13]
            lower_lip = landmarks[14]
            left_corner = landmarks[61]
            right_corner = landmarks[291]

            # Calculate height, width, and aspect ratio
            height = abs(upper_lip.y - lower_lip.y)
            width = abs(right_corner.x - left_corner.x)

            # Avoid division by zero
            aspect_ratio = height / width if width > 0.01 else 0.0

            return height, width, aspect_ratio
        except Exception:
            return 0, 0, 0

    def update_status(self, message):
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
        if not self.tts:
            return
        threading.Thread(
            target=lambda: self.tts.say(text) and self.tts.runAndWait(), daemon=True
        ).start()

    def manual_play(self):
        """수동 재생"""
        self.video_paused = False
        self.update_status("▶️ 수동 재생")

    def manual_pause(self):
        """수동 일시정지"""
        self.video_paused = True
        self.update_status("⏸️ 수동 일시정지")

    def on_closing(self):
        print("앱 종료 중...")
        self.stop_event.set()
        if self.camera_thread and self.camera_thread.is_alive():
            self.camera_thread.join(timeout=1)

        if self.face_mesh:
            self.face_mesh.close()
        if self.video_cap:
            self.video_cap.release()

        gc.collect()
        self.root.destroy()
        print("앱 종료 완료")


def main():
    try:
        print("=" * 50)
        print("🍽️ 밥잘먹어YO - 안정 버전")
        print("=" * 50)

        root = tk.Tk()
        app = EatingMonitorApp(root)
        root.mainloop()

    except Exception as e:
        print(f"앱 실행 실패: {e}")
        traceback.print_exc()
        input("엔터키를 눌러 종료...")


if __name__ == "__main__":
    main()
