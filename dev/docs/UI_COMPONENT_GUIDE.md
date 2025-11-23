# BobCam iOS UI Component Guide

This document provides a detailed breakdown of the BobCam iOS application's user interface. Use the component names defined here when reporting bugs or suggesting improvements to ensure clear communication.

## 📱 Main Screen Layout Overview

The main screen (`ContentView`) is divided vertically into two primary sections:

1.  **Camera Area (Top 40%)**: Shows the user's camera feed and detection feedback.
2.  **Video Area (Bottom 60%)**: Displays the content video that plays/pauses based on detection.

Overlaid on top are the **Status Bar** (bottom) and **Settings Button** (top-right).

---

## 🧩 Component Details

### 1. Camera Area (Top 40%)

| Component Name | File | Visual Location | Function |
| :--- | :--- | :--- | :--- |
| **CameraView** | `CameraView.swift` | Background of top section | Displays the real-time front camera feed. Mirrors the image for a natural mirror-like experience. |
| **LandmarksOverlayView** | `LandmarksOverlayView.swift` | Overlaid on CameraView | Visualizes the detected face landmarks and lip tracking lines (if enabled in settings). |
| **FeedbackBannerView** | `FeedbackBannerView.swift` | Bottom-center of Camera Area | Displays current status messages with color coding:<br>• 🟢 **Green**: "Good job!" (Eating)<br>• 🟠 **Orange**: "Eat more!" (Not Eating)<br>• ⚪️ **Gray**: "Analyzing..." (Neutral) |
| **SettingsButton** | `ContentView.swift` | Top-right corner | A gear icon ⚙️ that opens the `SettingsView` modal. |

### 2. Video Area (Bottom 60%)

| Component Name | File | Visual Location | Function |
| :--- | :--- | :--- | :--- |
| **VideoPlayerView** | `CameraView.swift` | Entire bottom section | • **Playback**: Plays the selected video when eating is detected.<br>• **Placeholder**: Shows "Select Video" prompt if no video is loaded.<br>• **Error State**: Displays error messages if playback fails. |
| **VideoSelectionButton** | `VideoPickerView.swift` | Inside VideoPlayerView | A button to open the photo picker for selecting a video from the device library. |

### 3. Overlays & Controls

| Component Name | File | Visual Location | Function |
| :--- | :--- | :--- | :--- |
| **StatusBar** | `StatusBar.swift` | Floating at the bottom of the screen | The main control center containing:<br>• **EatingStatusIndicator**: LED-style light (Green/Red) indicating detection state.<br>• **SensitivitySlider**: Slider to adjust detection sensitivity (10% - 100%).<br>• **OverrideButton**: "Manual" button to force video playback regardless of detection. |
| **SettingsView** | `SettingsView.swift` | Full-screen Modal | Configuration screen for:<br>• **Video Selection**: Manage selected video.<br>• **User Experience**: Toggle feedback banner, lip tracking line.<br>• **Debug**: Advanced metrics and overlays. |
| **OnboardingView** | `OnboardingView.swift` | Full screen (First launch only) | Guides the user through initial setup and camera permission request. |

### 4. Debug Tools (Hidden by default)

| Component Name | File | Visual Location | Function |
| :--- | :--- | :--- | :--- |
| **DebugOverlayView** | `DebugOverlayView.swift` | Top-left (if enabled) | Displays real-time technical metrics:<br>• FPS (Frames Per Second)<br>• CPU/Memory Usage<br>• Detection Confidence<br>• Mouth Openness Values |

---

## 🔍 Key Interactions

-   **Lip Detection**: `VisionService` analyzes the camera feed. If "eating" is detected:
    -   `FeedbackBannerView` turns Green.
    -   `VideoPlayerView` plays the video.
    -   `StatusBar` indicator turns Green.
-   **Manual Override**: Tapping "Manual" in `StatusBar`:
    -   Forces `VideoPlayerView` to play.
    -   Ignores lip detection results temporarily.
-   **Sensitivity Adjustment**: Moving the slider in `StatusBar`:
    -   Updates `VisionService` threshold immediately.
    -   Higher sensitivity = easier to trigger "eating" state.
