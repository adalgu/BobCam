# Project Brief: 밥잘먹어YO (Bob-Cam)

## 1. Core Objective

The primary goal of this project is to create a desktop application that monitors a user's eating habits via a webcam. The application should reliably detect when the user is eating and provide some form of feedback or control, such as playing a video. The ultimate aim is to encourage and monitor healthy eating patterns.

## 2. Key Requirements

*   **Stable Meal Detection**: The application must accurately and reliably detect when a user is eating. It should be robust against false positives from minor movements (e.g., talking, yawning).
*   **Modular Design**: The system should be designed with a clear separation between the "detection" logic (is the user eating?) and the "control" logic (what happens when they eat?). This allows for future flexibility in changing the feedback mechanism (e.g., from video playback to audio cues or pop-up messages).
*   **Application Stability**: The application must run without crashing or freezing. This includes proper resource management (camera, video files) and a stable threading model.
*   **User Interface**: The application needs a simple GUI that provides:
    *   A view of the camera feed.
    *   A display area for a video.
    *   Status updates and logs.
    *   Basic controls to start/stop monitoring and select files.

## 3. Initial Scope

The initial version of the project focuses on:
1.  Refactoring the initial prototype (`main-local.py`) into a stable, robust application (`main_stable.py`).
2.  Developing and refining a reliable eating detection algorithm based on mouth movements captured by the webcam.
3.  Ensuring the application architecture is clean, stable, and extensible for future features.
