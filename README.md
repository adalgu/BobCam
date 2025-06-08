# BobCam: 스마트 식사 모니터 (Smart Eating Monitor)

BobCam은 '밥(Bob)'을 먹는지를 모니터링하는 카메라(Cam)의 약자로, 컴퓨터 비전과 머신러닝을 활용하여 아이의 식사 행동을 모니터링하는 애플리케이션입니다. 부모의 수고를 덜어주면서 아이의 건강한 식습관 형성을 돕는 것이 목표입니다.

---

## 🌟 Core Features

*   **Real-time Eating Detection**: Uses MediaPipe FaceMesh to accurately track lip movements and distinguish between eating and other activities like talking.
*   **Automatic Video Control**: Seamlessly plays and pauses a selected video file based on the detected eating status.
*   **Stable &amp; Robust Architecture**: Built with a single-threaded processing model in Tkinter to ensure a smooth, crash-free user experience.
*   **Live Visual Feedback**: The application displays the live webcam feed with detected lip landmarks overlaid, providing a clear visual of what the algorithm is "seeing."
*   **Intuitive UI**: A clean interface shows the camera feed, video playback, and a status bar with icons indicating the current state (e.g., "Mouth Moving," "Eating").
*   **Screen Fade Effect**: The video screen subtly fades wheneating stops and brightens when it resumes, providing a gentle, non-intrusive cue.

---

## ⚙️ 기술 스택 (Tech Stack)

*   **Python 3**: Core programming language.
*   **Tkinter**: For the graphical user interface.
*   **OpenCV**: For all camera and video processing.
*   **MediaPipe**: For real-time facial landmark detection.
*   **Pillow (PIL)**: For integrating OpenCV images with Tkinter.

---

## 🚀 How to Run

1.  **Prerequisites**:
    *   Python 3 installed.
    *   A webcam connected to your computer.

2.  **Install Dependencies**:
    It is recommended to use a virtual environment.
    ```bash
    pip install opencv-python mediapipe numpy pillow
    ```

3.  **Run the Application**:
    Execute the main script from your terminal:
    ```bash
    python main_stable.py
    ```

4.  **How to Use**:
    *   The application will start, and you should see your webcam feed.
    *   Click the "Select Video" button to choose a video file you want to play.
    *   The application will begin monitoring your mouth movements.
    *   When you start eating, the video will play. When you stop, it will pause.
    *   You can use the manual "Play" and "Pause" buttons to override the automatic controls at any time.
    *   To quit, simply close the application window.

---

## 🏗️ System Architecture

The application uses a dedicated background thread for camera capture to prevent the GUI from freezing, while all processing and UI updates happen on the main thread. This ensures stability.

```mermaid
graph TD
    subgraph MainThread
        A[Tkinter Main Loop] --&gt; B{Get Frame from Queue};
        B --&gt; C[Face Detection (MediaPipe)];
        C --&gt; D[Update EatingStatus];
        D --&gt; E[Update GUI];
        E --&gt; A;
    end

    subgraph CameraThread
        G[Camera Capture] --&gt; H{Put Frame to Queue};
    end

    H --&gt; B;
