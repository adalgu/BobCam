# System Patterns: 밥잘먹어YO (Bob-Cam)

## 1. System Architecture

The application follows a GUI-centric, single-threaded processing model to ensure stability and prevent race conditions.

```mermaid
graph TD
    subgraph MainThread
        A[Tkinter Main Loop] --> B{Get Frame from Queue};
        B --> C[Face Detection (MediaPipe)];
        C --> D[Update EatingStatus];
        D --> E[Update GUI];
        E --> A;
    end

    subgraph CameraThread
        G[Camera Capture] --> H{Put Frame to Queue};
    end

    H --> B;

    classDef main fill:#cde4ff,stroke:#5a96d8;
    classDef camera fill:#d5e8d4,stroke:#82b366;
    class A,B,C,D,E main;
    class G,H camera;
```

*   **Camera Thread**: A single, dedicated background thread is responsible for capturing frames from the webcam. Its only job is to read frames and put them into a thread-safe queue (`queue.Queue`). This isolates the I/O-bound task from the main application logic.
*   **Main Thread**: The main thread runs the Tkinter event loop. All other processing occurs here, executed in a sequential manner within the `process_frames` function, which is called repeatedly by `root.after()`:
    1.  **Frame Retrieval**: Get a frame from the queue.
    2.  **Face & Mouth Detection**: Use the MediaPipe library to process the frame and detect facial landmarks.
    3.  **State Update**: Pass the mouth openness data to the `EatingStatus` class to update the current eating state.
    4.  **GUI Update**: Refresh the camera feed and status logs on the screen.

This pattern avoids the complexity and instability of the original multi-threaded approach, where GUI updates and data processing were happening in separate threads, leading to crashes.

## 2. Key Technical Decisions

*   **Separation of Concerns**: The `EatingStatus` class was created to encapsulate all the logic related to determining if a user is eating. This decouples the detection algorithm from the GUI code (`EatingMonitorApp`), making the system easier to test, maintain, and modify.
*   **Stateful Detection Algorithm**: The eating detection is not based on a single frame but on a history of mouth movements. It uses the standard deviation of both **mouth height** and **mouth aspect ratio** over a 2-second window (`deque`). A state change is triggered if either of these metrics shows significant variation. This provides a form of hysteresis and makes the detection more robust, helping to distinguish chewing (which alters aspect ratio) from talking.
*   **Visual Feedback Loop**: The GUI now draws the detected lip landmarks and displays the calculated height, width, and ratio values in real-time. This creates a tight feedback loop, allowing developers and users to instantly see what the algorithm is processing, which is critical for tuning and validation.
*   **Decoupled Controls**: The video playback logic has been intentionally separated from the detection logic to allow for focused refinement of the detection algorithm. Manual play/pause buttons have been added for testing and control.

## 3. Critical Implementation Paths

*   `EatingMonitorApp.process_frames()`: This is the heart of the application, orchestrating all the processing steps within the main thread.
*   `EatingStatus.detect_eating_behavior()`: This method contains the core algorithm for determining the eating state. It has been upgraded to use multiple features (height, aspect ratio) for higher accuracy.
*   `EatingMonitorApp.calculate_mouth_features()`: A new helper function to calculate all relevant mouth features (height, width, aspect ratio) from the raw landmark data.
