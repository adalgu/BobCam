import cv2
import time
import threading
import tkinter as tk
from tkinter import ttk, messagebox
from PIL import Image, ImageTk
import queue


class CameraDebugger:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("🔍 카메라 디버깅 도구")
        self.root.geometry("800x600")

        self.setup_gui()
        self.camera_devices = []
        self.current_camera = None
        self.running = False

    def setup_gui(self):
        """GUI 설정"""
        # 상단: 카메라 선택
        control_frame = tk.Frame(self.root)
        control_frame.pack(fill=tk.X, padx=10, pady=5)

        tk.Label(
            control_frame, text="카메라 장치 선택:", font=("Arial", 12, "bold")
        ).pack(side=tk.LEFT)

        self.camera_var = tk.StringVar()
        self.camera_combo = ttk.Combobox(
            control_frame, textvariable=self.camera_var, state="readonly", width=30
        )
        self.camera_combo.pack(side=tk.LEFT, padx=5)

        self.scan_btn = tk.Button(
            control_frame,
            text="🔍 장치 스캔",
            command=self.scan_cameras,
            bg="#2196F3",
            fg="white",
        )
        self.scan_btn.pack(side=tk.LEFT, padx=5)

        self.test_btn = tk.Button(
            control_frame,
            text="▶️ 테스트",
            command=self.start_camera_test,
            bg="#4CAF50",
            fg="white",
        )
        self.test_btn.pack(side=tk.LEFT, padx=5)

        self.stop_btn = tk.Button(
            control_frame,
            text="⏹️ 정지",
            command=self.stop_camera_test,
            bg="#f44336",
            fg="white",
        )
        self.stop_btn.pack(side=tk.LEFT, padx=5)

        # 중간: 카메라 미리보기
        self.preview_frame = tk.Frame(self.root, bg="black", height=400)
        self.preview_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        self.preview_frame.pack_propagate(False)

        self.preview_label = tk.Label(
            self.preview_frame,
            text="카메라를 선택하고 테스트를 시작하세요",
            bg="black",
            fg="white",
            font=("Arial", 16),
        )
        self.preview_label.pack(expand=True)

        # 하단: 로그 영역
        log_frame = tk.Frame(self.root)
        log_frame.pack(fill=tk.X, padx=10, pady=5)

        tk.Label(log_frame, text="디버그 로그:", font=("Arial", 10, "bold")).pack(
            anchor=tk.W
        )

        self.log_text = tk.Text(log_frame, height=8, font=("Consolas", 9))
        log_scroll = tk.Scrollbar(
            log_frame, orient=tk.VERTICAL, command=self.log_text.yview
        )
        self.log_text.configure(yscrollcommand=log_scroll.set)

        self.log_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        log_scroll.pack(side=tk.RIGHT, fill=tk.Y)

        # 프레임 큐
        self.frame_queue = queue.Queue(maxsize=2)

    def log(self, message):
        """로그 출력"""
        timestamp = time.strftime("%H:%M:%S")
        formatted_message = f"[{timestamp}] {message}\n"

        self.log_text.insert(tk.END, formatted_message)
        self.log_text.see(tk.END)
        print(formatted_message.strip())  # 콘솔에도 출력

    def scan_cameras(self):
        """사용 가능한 카메라 장치 스캔"""
        self.log("카메라 장치 스캔 시작...")
        self.camera_devices = []

        # 다양한 인덱스 시도 (0~10)
        for i in range(11):
            try:
                self.log(f"인덱스 {i} 테스트 중...")
                cap = cv2.VideoCapture(i)

                if cap.isOpened():
                    # 기본 정보 확인
                    width = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
                    height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
                    fps = cap.get(cv2.CAP_PROP_FPS)

                    # 실제 프레임 읽기 테스트
                    ret, frame = cap.read()
                    if ret and frame is not None:
                        device_info = (
                            f"카메라 {i} - {int(width)}x{int(height)} @{fps:.1f}fps"
                        )
                        self.camera_devices.append((i, device_info))
                        self.log(f"✅ {device_info}")
                    else:
                        self.log(f"❌ 인덱스 {i}: 프레임 읽기 실패")

                cap.release()
                time.sleep(0.1)  # 잠시 대기

            except Exception as e:
                self.log(f"❌ 인덱스 {i}: {str(e)}")

        # 콤보박스 업데이트
        if self.camera_devices:
            self.camera_combo["values"] = [info for _, info in self.camera_devices]
            self.camera_combo.current(0)
            self.log(f"총 {len(self.camera_devices)}개의 카메라 발견!")
        else:
            self.camera_combo["values"] = []
            self.log("❌ 사용 가능한 카메라를 찾을 수 없습니다!")
            messagebox.showerror(
                "오류",
                "사용 가능한 카메라가 없습니다.\n\n해결 방법:\n1. 카메라 연결 확인\n2. 권한 설정 확인\n3. 다른 앱에서 카메라 사용 중인지 확인",
            )

    def start_camera_test(self):
        """카메라 테스트 시작"""
        if not self.camera_devices:
            messagebox.showwarning("경고", "먼저 카메라를 스캔해주세요!")
            return

        if self.running:
            self.log("이미 카메라가 실행 중입니다.")
            return

        # 선택된 카메라 인덱스 찾기
        selected_info = self.camera_var.get()
        camera_index = None

        for idx, info in self.camera_devices:
            if info == selected_info:
                camera_index = idx
                break

        if camera_index is None:
            messagebox.showerror("오류", "카메라를 선택해주세요!")
            return

        self.log(f"카메라 {camera_index} 테스트 시작...")
        self.running = True

        # 카메라 스레드 시작
        self.camera_thread = threading.Thread(
            target=self.camera_loop, args=(camera_index,)
        )
        self.camera_thread.daemon = True
        self.camera_thread.start()

        # 디스플레이 업데이트 시작
        self.update_display()

    def camera_loop(self, camera_index):
        """카메라 루프"""
        cap = None
        frame_count = 0
        error_count = 0
        last_fps_time = time.time()

        try:
            self.log(f"카메라 {camera_index} 초기화 중...")
            cap = cv2.VideoCapture(camera_index)

            if not cap.isOpened():
                self.log(f"❌ 카메라 {camera_index} 열기 실패!")
                return

            # 카메라 설정 최적화
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # 버퍼 크기 줄이기
            cap.set(cv2.CAP_PROP_FPS, 30)  # FPS 설정

            width = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
            height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
            self.log(f"✅ 카메라 설정: {int(width)}x{int(height)}")

            while self.running:
                ret, frame = cap.read()

                if not ret or frame is None:
                    error_count += 1
                    self.log(f"⚠️ 프레임 읽기 실패 ({error_count}회)")

                    if error_count > 10:
                        self.log("❌ 연속 오류로 인해 카메라 중지")
                        break

                    time.sleep(0.1)
                    continue

                error_count = 0  # 성공 시 오류 카운트 리셋
                frame_count += 1

                # FPS 계산
                current_time = time.time()
                if current_time - last_fps_time >= 1.0:
                    fps = frame_count / (current_time - last_fps_time)
                    self.log(f"📊 실시간 FPS: {fps:.1f}")
                    frame_count = 0
                    last_fps_time = current_time

                # 프레임 크기 조정
                frame = cv2.resize(frame, (640, 480))
                frame = cv2.flip(frame, 1)  # 좌우 반전

                # 상태 정보 오버레이
                cv2.putText(
                    frame,
                    f"Camera {camera_index}",
                    (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1,
                    (0, 255, 0),
                    2,
                )
                cv2.putText(
                    frame,
                    f"Frame: {frame_count}",
                    (10, 70),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.7,
                    (255, 255, 255),
                    2,
                )

                # 프레임을 큐에 전송
                try:
                    self.frame_queue.put_nowait(frame)
                except queue.Full:
                    # 큐가 가득 차면 오래된 프레임 제거
                    try:
                        self.frame_queue.get_nowait()
                        self.frame_queue.put_nowait(frame)
                    except queue.Empty:
                        pass

                time.sleep(0.03)  # 약 30fps

        except Exception as e:
            self.log(f"❌ 카메라 루프 오류: {str(e)}")

        finally:
            if cap:
                cap.release()
                self.log("카메라 리소스 해제 완료")

    def update_display(self):
        """디스플레이 업데이트"""
        try:
            frame = self.frame_queue.get_nowait()

            # OpenCV -> PIL -> Tkinter 변환
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            image = Image.fromarray(frame_rgb)
            photo = ImageTk.PhotoImage(image)

            self.preview_label.configure(image=photo, text="")
            self.preview_label.image = photo  # 참조 유지

        except queue.Empty:
            pass
        except Exception as e:
            self.log(f"디스플레이 오류: {str(e)}")

        # 실행 중이면 계속 업데이트
        if self.running:
            self.root.after(33, self.update_display)  # 약 30fps

    def stop_camera_test(self):
        """카메라 테스트 정지"""
        if self.running:
            self.log("카메라 테스트 정지 중...")
            self.running = False

            # 스레드 종료 대기
            if hasattr(self, "camera_thread"):
                self.camera_thread.join(timeout=2)

            self.preview_label.configure(image="", text="카메라가 정지되었습니다")
            self.preview_label.image = None

    def on_closing(self):
        """앱 종료"""
        self.stop_camera_test()
        self.root.destroy()

    def run(self):
        """실행"""
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        self.log("🔍 카메라 디버깅 도구 시작")
        self.log("1. '🔍 장치 스캔' 버튼을 클릭하세요")
        self.log("2. 카메라를 선택하고 '▶️ 테스트'를 클릭하세요")

        # 자동으로 카메라 스캔
        self.root.after(500, self.scan_cameras)

        self.root.mainloop()


if __name__ == "__main__":
    debugger = CameraDebugger()
    debugger.run()
