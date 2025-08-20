# BobCam: 스마트 식사 모니터 (Smart Eating Monitor)

BobCam은 '밥(Bob)'을 먹는지를 모니터링하는 카메라(Cam)의 약자로, 컴퓨터 비전과 머신러닝을 활용하여 아이의 식사 행동을 모니터링하는 스마트 애플리케이션입니다. 부모의 수고를 덜어주면서 아이의 건강한 식습관 형성을 돕는 것이 목표입니다.

## 📱 **Phase 2 Complete: iOS Native App Ready for App Store**

**Latest Update (2025-08-20)**: BobCam iOS native app이 완성되어 App Store 출시 준비가 완료되었습니다. 70% 이상의 립 감지 정확도 달성과 완전한 사용자 기능을 제공합니다.

---

## 🚀 **Project Implementations**

### **1. iOS Native App (Phase 2 Complete - Production Ready)**
- **Status**: ✅ **READY FOR APP STORE SUBMISSION**
- **Platform**: iOS 15.0+, SwiftUI + Vision Framework
- **Accuracy**: 70%+ lip detection with systematic parameter optimization
- **Location**: `BobCam-iOS/` directory

#### **Key Features**:
- **Advanced Lip Detection**: Vision Framework with EMA smoothing and CircularBuffer optimization
- **Video Selection**: User can select videos from photo library (PHPickerViewController)
- **Complete Settings**: Privacy controls, algorithm parameters, debug mode
- **Real-time Monitoring**: Performance and accuracy metrics with visual overlays
- **Parameter Tuning**: Systematic optimization framework for accuracy improvement
- **Child Safety**: Local processing, privacy-first design, parental controls

### **2. Python Prototype (Legacy - Development Reference)**
- **Status**: ✅ Complete prototype implementation
- **Platform**: Python 3 + OpenCV + MediaPipe + Tkinter
- **Purpose**: Algorithm development and proof of concept
- **Location**: `main_stable.py`, `src/` directory

---

## 🎯 **Core Features (iOS Production Version)**

### **Real-time Lip Tracking**
- Vision Framework integration with 15fps optimized processing
- EMA smoothing for noise reduction and stability
- Configurable sensitivity controls for different environments
- Real-time accuracy monitoring with IoU, Jitter, and tracking metrics

### **Smart Video Control**
- Automatic play/pause based on eating detection
- User video selection from photo library
- Smooth fade animations and visual feedback
- Manual override controls with sensitivity adjustment

### **Comprehensive Settings**
- Video management with preview capabilities
- Algorithm parameter controls (sensitivity, thresholds, smoothing)
- Privacy policy and child safety information
- Debug mode with real-time visualization tools

### **Performance Optimization**
- Memory-optimized with CVPixelBufferPool
- Battery-efficient adaptive processing
- Thread-safe concurrent processing
- Maintain 15fps target with <200ms latency

### **Privacy & Security**
- 100% local processing (no external data transmission)
- Child privacy protection compliant
- Photo library permissions with clear usage descriptions
- App Store privacy guidelines compliance

---

## ⚙️ **Technology Stack**

### **iOS Native Implementation**
- **Swift 5** + **SwiftUI**: Modern iOS development
- **Vision Framework**: Apple's computer vision for face/lip detection
- **AVFoundation**: Camera capture and video playback
- **Core Graphics**: Landmark visualization and UI overlays
- **PhotosUI**: Video selection from photo library
- **UserDefaults**: Settings persistence and configuration

### **Python Prototype**
- **Python 3**: Core programming language
- **OpenCV**: Camera and video processing
- **MediaPipe**: Facial landmark detection
- **Tkinter**: Desktop GUI framework
- **Pillow (PIL)**: Image processing integration

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
