Title: [feature] ios: add toggleable lip tracking visualization line
Labels: workflow:/solve-github-issue, type:feature, area:ios, priority:p2

# Goal
Add a user-facing toggle to visualize the tracked lip shape with a simple line. This will allow users to verify that lip tracking is working correctly without enabling the full debug overlay.

# Background
Currently, users cannot easily verify if the app is correctly tracking their lips unless they enable "Debug Mode", which shows a cluttered overlay with bounding boxes, points, and labels. A simple, clean visualization of just the lip line is needed for user confidence and basic troubleshooting.

# Scope
- **iOS App Only** (`BobCam-iOS`)
- **Components**:
  - `DebugSettings.swift`: Add state for the new visualization.
  - `LandmarksOverlayView.swift`: Implement clean lip line drawing.
  - `SettingsView.swift`: Add the toggle switch.

# Acceptance Criteria
1.  **Settings UI**: A new toggle "Show Lip Tracking Line" (or similar) appears in the Settings screen (likely under "Algorithm Settings" or "User Experience").
2.  **Visualization**:
    -   When enabled: A clear, single-color line is drawn connecting the outer lip landmarks.
    -   When disabled: No line is drawn.
    -   The line should smoothly follow the user's mouth movements.
3.  **Independence**: This feature should work independently of the main "Debug Mode". It should not show bounding boxes, point labels, or other debug artifacts.
4.  **Performance**: Drawing this line should have negligible impact on performance.

# Technical Notes
-   **`DebugSettings.swift`**: Add `@Published var showLipTrackingLine: Bool = false`.
-   **`LandmarksOverlayView.swift`**:
    -   Modify `draw(_ rect: CGRect)` to check `showLipTrackingLine`.
    -   Create a simplified `drawCleanLipLine()` function that only draws the path of `landmarks.outerLips` without points or labels.
-   **`SettingsView.swift`**:
    -   Add `Toggle("Show Lip Tracking", isOn: $visionService.debugSettings.showLipTrackingLine)` (you may need to expose this binding).

# Task Breakdown
- [ ] Update `DebugSettings.swift` to include `showLipTrackingLine`.
- [ ] Update `LandmarksOverlayView.swift` to implement the simplified drawing logic.
- [ ] Update `SettingsView.swift` to add the toggle.
- [ ] Verify the visualization works on the simulator/device (via code review/logic check).

# Validation Strategy
-   **Manual Verification**:
    -   Run the app.
    -   Go to Settings.
    -   Toggle "Show Lip Tracking" ON.
    -   Verify a line appears on the mouth.
    -   Toggle "Show Lip Tracking" OFF.
    -   Verify the line disappears.
    -   Enable "Debug Mode" and ensure it doesn't conflict (debug mode might overlay more info, which is fine).
