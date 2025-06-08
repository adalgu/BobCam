# Technical Context: 밥잘먹어YO (Bob-Cam)

## 1. Core Technologies

*   **Python 3**: The primary programming language.
*   **Tkinter**: The standard Python interface to the Tk GUI toolkit, used for building the application's user interface. The `ttk` themed widgets are used for a more modern look.
*   **OpenCV (cv2)**: Used for all camera and video processing tasks, including capturing frames from the webcam, reading video files, and basic image manipulations (resizing, color conversion).
*   **MediaPipe**: A cross-platform library from Google used for building perception pipelines. Specifically, the `FaceMesh` solution is used to detect facial landmarks in real-time, which is crucial for tracking mouth movements.
*   **Pillow (PIL)**: Used to convert OpenCV image arrays into a format that Tkinter can display.
*   **pyttsx3**: A text-to-speech library used to provide audio feedback to the user.

## 2. Development Setup

*   The application is developed and run as a standard Python script.
*   Dependencies are managed through standard Python package management (e.g., pip, uv).
*   The `sample.py` file serves as a reference for the initial dlib-based detection logic, but the main application (`main_stable.py`) has fully transitioned to using MediaPipe for better performance and easier setup.

## 3. Key Dependencies & Libraries

*   `opencv-python`: For video and camera operations.
*   `mediapipe`: For face landmark detection.
*   `numpy`: For numerical operations, specifically `np.std()` to calculate the standard deviation of mouth movements.
*   `Pillow`: For GUI image display.
*   `pyttsx3`: For text-to-speech functionality.

## 4. Tool Usage Patterns

*   **Threading**: The `threading` module is used sparingly and intentionally. A single daemon thread is used for camera capture to prevent the GUI from freezing, while all other operations are kept in the main thread to ensure stability.
*   **Queue**: A `queue.Queue` is used as the primary mechanism for passing frames safely from the background camera thread to the main processing thread.
