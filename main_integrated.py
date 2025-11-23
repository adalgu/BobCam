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

# Phase 2 모듈
from alarm_system import SmartAlarmSystem

# from utensil_detector import UtensilDetector # TODO: 추후 통합


class EatingStatus:
    """
    (Phase 1) 식사 상태를 감지하고 관리하는 클래스.
    Phase 2에서는 SmartAlarmSystem으로 대체될 예정입니다.
    """

    def __init__(self):
        self.MOUTH_OPEN_THRESHOLD = 0.02
        self.HEIGHT_STD_THRESHOLD = 0.03
        self.RATIO_STD_THRESHOLD = 0.02
        self.NO_EATING_TIMEOUT = 60
        self.EATING_CONFIRM_COUNT = 15
        self.height_history = deque(maxlen=60)
        self.ratio_history = deque(maxlen=60)
        self.is_eating = False
        self.last_eating_time = time.time()
        self.eating_counter = 0
        self.not_eating_counter = 0
        self.consecutive_eating_sessions = 0

    def detect_eating_behavior(self, mouth_height, mouth_aspect_ratio):
        self.height_history.append(mouth_height)
        self.ratio_history.append(mouth_aspect_ratio)
        states = {
            "is_eating": self.is_eating,
            "mouth_state": "닫힘",
            "movement_state": "멈춤",
        }
        if len(self.height_history) < self.height_history.maxlen:
            return states
        if mouth_height > self.MOUTH_OPEN_THRESHOLD:
            states["mouth_state"] = "열림"
        else:
            states["mouth_state"] = "닫힘"
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


class IntegratedEatingMonitorApp:
    def __init__(self, root):
        self.root = root
        self.stop_event = threading.Event()
        print("🚀 밥잘먹어YO v3.0 - 통합 스마트 알람 시스템 초기화 시작...")
        self.camera_queue = queue.Queue(maxsize=2)

        # --- Phase 2 모듈 설정 ---
        self.alarm_system = SmartAlarmSystem()
        # self.utensil_detector = UtensilDetector() # TODO: 추후 활성화
        self.eating_status = EatingStatus()  # TODO: Phase2에서는 alarm_system으로 대체
        # -------------------------

        self.setup_variables()
        self.setup_mediapipe()
        self.setup_tts()
        self.setup_gui()
        self.camera_thread = None
        print("✅ 초기화 완료!")

    def setup_variables(self):
        print("상태 변수 설정 중...")
        self.last_logged_mouth_state = ""
        self.video_cap = None
        self.video_playing = False
        self.video_paused = True
        self.video_file_path = None
        self.status_labels = {}
        self.overlay_alpha = 0.0
        self.fade_direction = 0
        self.fade_speed = 0.02
        self.max_alpha = 0.8
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
        self.root.title("🍽️ 밥잘먹어YO - Phase 2 스마트 알람")
        self.root.geometry("1280x720")
        self.root.configure(bg="#f0f0f0")
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

        self.side_frame = tk.Frame(self.root, bg="#e0e0e0", width=300)
        self.side_frame.pack(side=tk.RIGHT, fill=tk.Y, expand=False)
        self.side_frame.pack_propagate(False)

        self.main_frame = tk.Frame(self.root, bg="black")
        self.main_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.video_label = tk.Label(self.main_frame, bg="black")
        self.video_label.pack(expand=True)

        self.camera_frame = tk.Frame(self.side_frame, bg="black", height=225)
        self.camera_frame.pack(fill=tk.X, padx=10, pady=10)
        self.camera_frame.pack_propagate(False)
        self.camera_label = tk.Label(self.camera_frame, bg="black")
        self.camera_label.pack(expand=True)

        self.setup_alarm_settings_frame()  # Phase 2 GUI

        self.icon_bar_frame = tk.Frame(self.side_frame, bg="#f0f0f0", height=50)
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

        self.setup_control_buttons()
        print("✅ GUI 설정 완료")

    def setup_alarm_settings_frame(self):
        """Phase 2: 알람 중심 설정 프레임"""
        alarm_frame = tk.LabelFrame(
            self.side_frame, text="🚨 스마트 알람 설정", bg="#f0f0f0", padx=5, pady=5
        )
        alarm_frame.pack(fill=tk.X, padx=10, pady=5)

        # 1. 타이밍 임계값 설정
        idle_frame = tk.Frame(alarm_frame, bg="#f0f0f0")
        idle_frame.pack(fill=tk.X, pady=2)
        tk.Label(idle_frame, text="식사 중단 감지 (초):", bg="#f0f0f0").pack(
            side=tk.LEFT, padx=(0, 5)
        )
        self.idle_threshold_var = tk.DoubleVar(value=15.0)
        idle_scale = tk.Scale(
            idle_frame,
            from_=5,
            to=60,
            variable=self.idle_threshold_var,
            orient=tk.HORIZONTAL,
            bg="#f0f0f0",
            length=120,
            command=self.apply_alarm_settings,
        )
        idle_scale.pack(side=tk.LEFT)

        # 2. 알람 모드 선택
        mode_frame = tk.Frame(alarm_frame, bg="#f0f0f0")
        mode_frame.pack(fill=tk.X, pady=2)
        tk.Label(mode_frame, text="알람 모드:", bg="#f0f0f0").pack(
            side=tk.LEFT, padx=(0, 15)
        )
        self.alarm_mode_var = tk.StringVar(value="voice_trigger")
        tk.Radiobutton(
            mode_frame,
            text="음성",
            variable=self.alarm_mode_var,
            value="voice_trigger",
            bg="#f0f0f0",
            command=self.apply_alarm_settings,
        ).pack(side=tk.LEFT)
        tk.Radiobutton(
            mode_frame,
            text="소리",
            variable=self.alarm_mode_var,
            value="sound_alert",
            bg="#f0f0f0",
            command=self.apply_alarm_settings,
        ).pack(side=tk.LEFT, padx=10)

        # 3. 음성 녹음 버튼
        ttk.Button(
            alarm_frame,
            text="🎤 내 목소리 녹음 (Hey Google)",
            command=self.record_voice_commands,
        ).pack(pady=5, fill=tk.X)

    def record_voice_commands(self):
        if not self.alarm_system or not hasattr(self.alarm_system, "voice_trigger"):
            messagebox.showerror("오류", "음성 녹음 기능이 활성화되지 않았습니다.")
            return
        device, command = "google", "pause"
        if messagebox.askokcancel(
            "음성 녹음",
            f"'{device} {command}' 라고 3초간 말씀해주세요.\n확인을 누르면 녹음이 시작됩니다.",
        ):
            filepath = self.alarm_system.voice_trigger.record_user_voice(
                device, command, duration=3
            )
            if filepath:
                messagebox.showinfo(
                    "성공", f"음성이 성공적으로 녹음되었습니다:\n{filepath}"
                )
            else:
                messagebox.showerror("실패", "음성 녹음에 실패했습니다.")

    def apply_alarm_settings(self, event=None):
        if self.alarm_system:
            idle_threshold = self.idle_threshold_var.get()
            self.alarm_system.timing_analyzer.idle_threshold = idle_threshold
            alarm_mode = self.alarm_mode_var.get()
            self.alarm_system.set_alarm_mode(alarm_mode)
            self.update_status(
                f"⚙️ 알람 설정 적용: 중단 감지={idle_threshold:.0f}초, 모드={alarm_mode}"
            )

    def create_status_icons(self, parent_frame):
        icon_font = ("Arial", 16)
        text_font = ("Arial", 9)
        icons = {"face": "얼굴", "mouth": "입", "utensil": "식기구", "alarm": "알람"}
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

    def setup_control_buttons(self):
        ttk.Button(
            self.status_frame, text="📁 영상 파일 선택", command=self.select_video_file
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
        self.stop_event.clear()
        self.camera_thread = threading.Thread(target=self.camera_loop)
        self.camera_thread.daemon = True
        self.camera_thread.start()
        self.start_btn.config(state=tk.DISABLED)
        self.stop_btn.config(state=tk.NORMAL)
        self.apply_alarm_settings()
        self.update_status("🚀 스마트 알람 시스템 시작!")
        self.process_frames()

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
                    pass
            cap.release()
        except Exception as e:
            self.update_status(f"❌ 카메라 루프 오류: {e}")

    def process_frames(self):
        if self.stop_event.is_set():
            return
        try:
            cam_frame = self.camera_queue.get_nowait()
            self.update_camera_feed(cam_frame)
            if not self.video_paused and self.video_cap:
                ret, video_frame = self.video_cap.read()
                if not ret:
                    self.video_cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    ret, video_frame = self.video_cap.read()
                if ret:
                    self.update_video_display(video_frame)
        except queue.Empty:
            pass
        except Exception as e:
            self.update_status(f"프레임 처리 오류: {e}")
        self.root.after(15, self.process_frames)

    def update_camera_feed(self, frame):
        frame = cv2.flip(frame, 1)
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.face_mesh.process(rgb_frame)
        face_detected = bool(results.multi_face_landmarks)

        utensil_result = {"detected": False, "action_detected": False}  # 임시
        mouth_data = {}  # 임시
        jaw_data = {}  # 임시

        # 얼굴이 감지되었을 때만 로직 수행
        if face_detected:
            face_landmarks = results.multi_face_landmarks[0]
            self.mp_drawing.draw_landmarks(
                image=frame,
                landmark_list=face_landmarks,
                connections=self.mp_face_mesh.FACEMESH_LIPS,
                landmark_drawing_spec=None,
                connection_drawing_spec=self.drawing_spec,
            )
            mouth_height, _, mouth_aspect_ratio = self.calculate_mouth_features(
                face_landmarks.landmark
            )

            # Phase 1 로직 (참고용 및 mouth_state 업데이트용)
            states = self.eating_status.detect_eating_behavior(
                mouth_height, mouth_aspect_ratio
            )

            # Phase 2 알람 시스템 로직 호출
            # TODO: utensil_detector 연동하여 utensil_result 업데이트
            # 예: if utensil_result['action_detected']: self.alarm_system.timing_analyzer.update_utensil_event()
            self.alarm_system.check_eating_status(utensil_result, mouth_data, jaw_data)

            # 화면 페이드 방향 결정 (Phase 1의 움직임 감지 로직 활용)
            if states["movement_state"] == "움직임":
                self.fade_direction = -1  # 밝아짐
            else:
                self.fade_direction = 1  # 어두워짐
        else:
            # 얼굴 감지 실패 시, 기본 상태값으로 아이콘 업데이트
            states = {"mouth_state": "닫힘"}
            self.alarm_system.check_eating_status(utensil_result, mouth_data, jaw_data)

        self.update_status_icons(face_detected, states, utensil_result)
        cam_img = cv2.resize(frame, (280, 210))
        self.display_image(cam_img, self.camera_label)

    def update_status_icons(self, face_detected, states, utensil_result):
        self.status_labels["face"].config(
            text="●" if face_detected else "○", fg="green" if face_detected else "red"
        )
        self.status_labels["mouth"].config(
            text="👄", fg="blue" if states.get("mouth_state") == "열림" else "gray"
        )

        # Phase 2 아이콘
        self.status_labels["utensil"].config(
            text="🍴",
            fg=(
                "green"
                if utensil_result.get("action_detected")
                else "orange" if utensil_result.get("detected") else "gray"
            ),
        )

        is_alarm_active = self.alarm_system and (
            getattr(self.alarm_system, "utensil_alarm_active", False)
            or getattr(self.alarm_system, "chewing_alarm_active", False)
        )
        self.status_labels["alarm"].config(
            text="🚨" if is_alarm_active else "🔕",
            fg="red" if is_alarm_active else "green",
        )

    def update_video_display(self, frame):
        if self.fade_direction != 0:
            self.overlay_alpha = np.clip(
                self.overlay_alpha + self.fade_direction * self.fade_speed,
                0,
                self.max_alpha,
            )
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
            upper_lip, lower_lip = landmarks[13], landmarks[14]
            left_corner, right_corner = landmarks[61], landmarks[291]
            height = abs(upper_lip.y - lower_lip.y)
            width = abs(right_corner.x - left_corner.x)
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
        self.video_paused = False
        self.update_status("▶️ 수동 재생")

    def manual_pause(self):
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
        print("🍽️ 밥잘먹어YO - Phase 2 스마트 알람")
        print("=" * 50)
        root = tk.Tk()
        app = IntegratedEatingMonitorApp(root)
        root.mainloop()
    except Exception as e:
        print(f"앱 실행 실패: {e}")
        traceback.print_exc()
        input("엔터키를 눌러 종료...")


if __name__ == "__main__":
    main()
