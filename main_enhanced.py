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


class EatingMonitorApp:
    def __init__(self, root):
        self.root = root
        self.stop_event = threading.Event()

        print("🚀 밥잘먹어YO v2.1 초기화 시작...")

        # 큐 설정
        self.camera_queue = queue.Queue(maxsize=2)

        # 감지 모드 설정
        self.use_advanced_detection = False
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
        self.status_labels = {}

        # 화면 페이드 효과
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
        self.root.title("🍽️ 밥잘먹어YO v2.1 - 고급 감지 지원")
        self.root.geometry("1280x720")
        self.root.configure(bg="#f0f0f0")
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

        # 레이아웃 설정
        self.side_frame = tk.Frame(self.root, bg="#e0e0e0", width=300)
        self.side_frame.pack(side=tk.RIGHT, fill=tk.Y, expand=False)
        self.side_frame.pack_propagate(False)

        self.main_frame = tk.Frame(self.root, bg="black")
        self.main_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.video_label = tk.Label(self.main_frame, bg="black")
        self.video_label.pack(expand=True)

        self.camera_frame = tk.Frame(self.side_frame, bg="black", height=200)
        self.camera_frame.pack(fill=tk.X, padx=10, pady=10)
        self.camera_frame.pack_propagate(False)
        self.camera_label = tk.Label(self.camera_frame, bg="black")
        self.camera_label.pack(expand=True)

        # 감지 모드 선택 프레임
        self.setup_detection_mode_frame()

        # 상태 아이콘 바
        self.icon_bar_frame = tk.Frame(self.side_frame, bg="#f0f0f0", height=50)
        self.icon_bar_frame.pack(fill=tk.X, padx=10, pady=5)
        self.icon_bar_frame.pack_propagate(False)
        self.create_status_icons(self.icon_bar_frame)

        # 상태 텍스트 및 컨트롤
        self.status_frame = tk.Frame(self.side_frame, bg="white")
        self.status_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))

        self.status_text = tk.Text(
            self.status_frame,
            bg="white", fg="black", font=("Arial", 9),
            wrap=tk.WORD, state=tk.DISABLED, height=8,
        )
        self.status_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        # 컨트롤 버튼들
        self.setup_control_buttons()

        print("✅ GUI 설정 완료")

    def setup_detection_mode_frame(self):
        """감지 모드 선택 UI 설정"""
        mode_frame = tk.Frame(self.side_frame, bg="#f0f0f0")
        mode_frame.pack(fill=tk.X, padx=10, pady=5)
        
        tk.Label(mode_frame, text="감지 모드:", bg="#f0f0f0", 
                font=("Arial", 10, "bold")).pack(side=tk.LEFT, padx=(0, 10))
        
        self.detection_mode_var = tk.StringVar(value="basic")
        
        tk.Radiobutton(
            mode_frame, text="기본 (입술만)", variable=self.detection_mode_var,
            value="basic", bg="#f0f0f0", command=self.on_detection_mode_change
        ).pack(side=tk.LEFT, padx=5)
        
        if ADVANCED_DETECTION_AVAILABLE:
            tk.Radiobutton(
                mode_frame, text="고급 (입술+턱)", variable=self.detection_mode_var,
                value="advanced", bg="#f0f0f0", command=self.on_detection_mode_change
            ).pack(side=tk.LEFT, padx=5)
        else:
            tk.Label(mode_frame, text="고급 (비활성)", bg="#f0f0f0", 
                    fg="gray").pack(side=tk.LEFT, padx=5)

    def on_detection_mode_change(self):
        """감지 모드 변경 처리"""
        mode = self.detection_mode_var.get()
        
        if mode == "advanced" and ADVANCED_DETECTION_AVAILABLE:
            self.use_advanced_detection = True
            self.eating_status = AdvancedEatingStatus()
            self.update_status("🔄 고급 감지 모드 (입술+턱) 활성화")
        else:
            self.use_advanced_detection = False
            self.eating_status = EatingStatus()
            self.update_status("🔄 기본 감지 모드 (입술만) 활성화")

    def create_status_icons(self, parent_frame):
        """상태 아이콘 생성"""
        icon_font = ("Arial", 12)
        text_font = ("Arial", 8)
        icons = {"face": "얼굴", "mouth": "입 상태", "move": "움직임", "eat": "식사"}

        for name, text in icons.items():
            frame = tk.Frame(parent_frame, bg=parent_frame.cget("bg"))
            frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH)

            icon_label = tk.Label(frame, text="?", font=icon_font, 
                                bg=parent_frame.cget("bg"), fg="gray")
            icon_label.pack(pady=(2, 0))

            text_label = tk.Label(frame, text=text, font=text_font, 
                                bg=parent_frame.cget("bg"), fg="black")
            text_label.pack()

            self.status_labels[name] = icon_label

    def setup_control_buttons(self):
        """컨트롤 버튼들 설정"""
        ttk.Button(self.status_frame, text="📁 파일 선택", 
                  command=self.select_video_file).pack(fill=tk.X, padx=5, pady=2)

        cam_frame = ttk.Frame(self.status_frame)
        cam_frame.pack(fill=tk.X, padx=5, pady=2)
        ttk.Label(cam_frame, text="카메라:").pack(side=tk.LEFT)
        self.camera_var = tk.StringVar(value="1")
        self.camera_combo = ttk.Combobox(
            cam_frame, textvariable=self.camera_var,
            values=["0", "1", "2", "3"], state="readonly", width=5,
        )
        self.camera_combo.pack(side=tk.LEFT, padx=5)
        self.camera_combo.set("1")

        self.start_btn = ttk.Button(self.status_frame, text="▶️ 모니터링 시작", 
                                   command=self.start_monitoring)
        self.start_btn.pack(fill=tk.X, padx=5, pady=2)
        
        self.stop_btn = ttk.Button(self.status_frame, text="⏹️ 모니터링 정지", 
                                  command=self.stop_monitoring, state=tk.DISABLED)
        self.stop_btn.pack(fill=tk.X, padx=5, pady=2)

        manual_frame = ttk.LabelFrame(self.status_frame, text="수동 제어")
        manual_frame.pack(fill=tk.X, padx=5, pady=5, ipady=2)

        self.play_btn = ttk.Button(manual_frame, text="▶️ 재생", command=self.manual_play)
        self.play_btn.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=2)

        self.pause_btn = ttk.Button(manual_frame, text="⏸️ 일시정지", command=self.manual_pause)
        self.pause_btn.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=2)

    # 나머지 메서드들은 기존과 동일하므로 main_stable.py의 내용을 가져옵니다
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
        mode_text = "고급 (입술+턱)" if self.use_advanced_detection else "기본 (입술만)"
        self.update_status(f"🚀 카메라 모니터링 시작! [{mode_text} 모드]")
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
            self.update_status("카메라 리소스 해제")
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

        face_detected = False
        states = {"is_eating": False, "mouth_state": "닫힘", "movement_state": "멈춤"}

        if results.multi_face_landmarks:
            face_detected = True
            face_landmarks = results.multi_face_landmarks[0]

            # 입술 랜드마크 그리기
            self.mp_drawing.draw_landmarks(
                image=frame, landmark_list=face_landmarks,
                connections=self.mp_face_mesh.FACEMESH_LIPS,
                landmark_drawing_spec=None, connection_drawing_spec=self.drawing_spec,
            )

            # 고급 모드에서 턱 랜드마크도 그리기
            if self.use_advanced_detection:
                self.draw_jaw_landmarks(frame, face_landmarks.landmark)

            mouth_height, mouth_width, mouth_aspect_ratio = (
                self.calculate_mouth_features(face_landmarks.landmark)
            )

            was_eating = self.eating_status.is_eating
            
            # 감지 모드에 따른 분기
            if self.use_advanced_detection:
                states = self.eating_status.detect_eating_behavior(
                    mouth_height, mouth_aspect_ratio, face_landmarks.landmark
                )
            else:
                states = self.eating_status.detect_eating_behavior(
                    mouth_height, mouth_aspect_ratio
                )
            
            is_eating = states["is_eating"]
            
            # 상태 메시지 생성
            if self.use_advanced_detection:
                mouth_state_str = (
                    f"입: {states.get('mouth_state', '?')}, "
                    f"움직임: {states.get('movement_state', '?')}, "
                    f"턱: {states.get('jaw_state', '?')}"
                )
                confidence = states.get('confidence', 0.0)
                detection_method = states.get('detection_method', 'none')
                confidence_str = f" [신뢰도: {confidence:.2f}, 방법: {detection_method}]"
            else:
                mouth_state_str = (
                    f"입: {states.get('mouth_state', '?')}, "
                    f"움직임: {states.get('movement_state', '?')}"
                )
                confidence_str = ""

            # 상태 변경 로깅
            current_log_state = (
                f"{mouth_state_str}, 최종: {'식사 중' if is_eating else '식사 멈춤'}{confidence_str}"
            )
            if current_log_state != self.last_logged_mouth_state:
                self.update_status(f"상태 감지: {current_log_state}")
                self.last_logged_mouth_state = current_log_state

            # 비디오 제어
            if is_eating != was_eating:
                if is_eating:
                    self.video_paused = False
                    method_info = f" ({states.get('detection_method', 'unknown')} 방식)" if self.use_advanced_detection else ""
                    self.update_status(f"▶️ 식사 시작!{method_info} 비디오를 재생합니다.")
                    self.speak("잘 먹네요! 영상 보세요!")
                else:
                    self.video_paused = True
                    self.update_status("⏸️ 식사 멈춤! 비디오를 일시정지합니다.")
                    self.speak("밥 먹어야 보여줄 거예요.")

            # 페이드 효과
            if states.get("movement_state") == "움직임" or states.get("jaw_state") == "움직임":
                self.fade_direction = -1
            else:
                self.fade_direction = 1

            # 시각적 피드백
            status_text = "😋 먹는 중!" if is_eating else "🤔 식사하세요"
            color = (0, 255, 0) if is_eating else (0, 0, 255)
            cv2.putText(frame, status_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
            cv2.putText(frame, mouth_state_str, (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1)
            
            # 고급 모드 추가 정보
            if self.use_advanced_detection and 'confidence' in states:
                confidence_text = f"신뢰도: {states['confidence']:.2f} ({states.get('detection_method', '?')})"
                cv2.putText(frame, confidence_text, (10, 85), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 0), 1)

        if not face_detected:
            if self.use_advanced_detection:
                states = self.eating_status.detect_eating_behavior(0, 0, None)
            else:
                states = self.eating_status.detect_eating_behavior(0, 0)
            if self.eating_status.is_eating:
                self.video_paused = True
                self.update_status("⏸️ 얼굴 감지 실패! 비디오를 일시정지합니다.")

        self.update_status_icons(face_detected, states)
        cam_img = cv2.resize(frame, (280, 190))
        self.display_image(cam_img, self.camera_label)

    def draw_jaw_landmarks(self, frame, landmarks):
        """턱 랜드마크 그리기 (고급 모드 전용)"""
        try:
            h, w = frame.shape[:2]
            jaw_points = [172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397, 288, 361, 323]
            for point_idx in jaw_points:
                if point_idx < len(landmarks):
                    landmark = landmarks[point_idx]
                    x = int(landmark.x * w)
                    y = int(landmark.y * h)
                    cv2.circle(frame, (x, y), 2, (255, 0, 255), -1)  # 보라색
            # 턱끝 특별 표시
            chin_points = [175, 199, 428]
            for point_idx in chin_points:
                if point_idx < len(landmarks):
                    landmark = landmarks[point_idx]
                    x = int(landmark.x * w)
                    y = int(landmark.y * h)
                    cv2.circle(frame, (x, y), 3, (0, 255, 255), -1)  # 노란색
        except Exception:
            pass

    def update_status_icons(self, face_detected, states):
        if face_detected:
            self.status_labels["face"].config(text="●", fg="green")
        else:
            self.status_labels["face"].config(text="○", fg="red")

        if states.get("mouth_state") == "열림":
            self.status_labels["mouth"].config(text="👄", fg="blue")
        else:
            self.status_labels["mouth"].config(text="👄", fg="gray")

        if states.get("movement_state") == "움직임":
            self.status_labels["move"].config(text="🏃", fg="blue")
        else:
            self.status_labels["move"].config(text="🏃", fg="gray")

        if states.get("is_eating"):
            self.status_labels["eat"].config(text="🍽️", fg="green")
        else:
            self.status_labels["eat"].config(text="🍽️", fg="red")

    def update_video_display(self, frame):
        if self.fade_direction != 0:
            self.overlay_alpha += self.fade_direction * self.fade_speed
            self.overlay_alpha = np.clip(self.overlay_alpha, 0, self.max_alpha)
        if self.overlay_alpha > 0:
            overlay = np.zeros_like(frame, dtype=np.uint8)
            frame = cv2.addWeighted(frame, 1 - self.overlay_alpha, overlay, self.overlay_alpha, 0)
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
            upper_lip = landmarks[13]
            lower_lip = landmarks[14]
            left_corner = landmarks[61]
            right_corner = landmarks[291]
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
        threading.Thread(target=lambda: self.tts.say(text) and self.tts.runAndWait(), daemon=True).start()

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
        print("=" * 60)
        print("🍽️ 밥잘먹어YO v2.1 - 고급 턱 감지 지원")
        print("=" * 60)
        if ADVANCED_DETECTION_AVAILABLE:
            print("✅ 고급 감지 모듈 사용 가능 (입술 + 턱 움직임)")
        else:
            print("⚠️ 기본 감지 모듈만 사용 가능 (입술 움직임만)")
        print("=" * 60)
        root = tk.Tk()
        app = EatingMonitorApp(root)
        root.mainloop()
    except Exception as e:
        print(f"앱 실행 실패: {e}")
        traceback.print_exc()
        input("엔터키를 눌러 종료...")


if __name__ == "__main__":
    main()
