# Active Context: BobCam-iOS

## 1. Current Work Focus
Apply a minor UI change to the main screen layout per user request:
- Change split from left/right (HStack) to top/bottom (VStack).
- Keep behavior and overlays intact.

## 2. Recent Changes (Minor Version)
- Main layout updated to vertical split (top/bottom):
  - Files:
    - BobCam-iOS/BobCamAgent/BobCamAgent/ContentView.swift
    - BobCam-iOS/BobCamAgent/BobCamAgent/DebugOverlay/ContentView+Debug.swift
  - Change:
    - Replaced HStack with VStack.
    - Camera on top (40% height), Video player on bottom (60% height).
    - Preserved StatusBar overlay (bottom) and Settings button (topTrailing).
    - Debug overlay remains layered via `.overlay { ... }` in debug build.
  - Build:
    - Verified build success on iOS Simulator iPhone 16 Pro (iOS 18.6).
    - No code-signing or dependency issues observed.

### Code Sketch (effective layout)
```swift
GeometryReader { geometry in
    VStack(spacing: 0) {
        // Top (40%) - Camera
        CameraView(...)
            .frame(height: geometry.size.height * 0.4)
            .frame(maxWidth: .infinity)
            .clipped()
            .onAppear { cameraService.startSession(); cameraService.delegate = visionService }

        // Bottom (60%) - Video
        VideoPlayerView(...)
            .frame(maxWidth: .infinity)
            .frame(height: geometry.size.height * 0.6)
    }
    .overlay(alignment: .bottom) { StatusBar(...) }
    .overlay(alignment: .topTrailing) { /* Settings button */ }
}
.ignoresSafeArea()
```

## 3. Rationale and Impact
- Rationale: Match requested UI: “세로로 2개로 나누어지는데, 상하로 나누어지도록 하자.”
- Impact: Visual composition changes only; no functional changes to Vision, Video, or Debug systems.
- Risk: Minimal; overlays are preserved and tested; layout uses deterministic fractions.

## 4. Validation Summary
- Simulator: iPhone 16 Pro, iOS 18.6
- Build: Succeeded via xcodebuild.
- UI: Top/bottom split renders; StatusBar and Settings visible; no clipping observed in default simulator window.

## 5. Next Steps
1. User validation on devices (portrait/landscape).
2. Optional: Adaptive layout based on orientation or size class (e.g., return to HStack in landscape).
3. Optional: Make the 40/60 split adjustable in Settings/Debug for experimentation.
4. Update `progress.md` accordingly (this change is minor per versioning guidelines).

## 6. Notes
- This is a Minor Version update as per versioning guidelines (UI arrangement only).
- Vision performance/metrics and debug overlay improvements from Phase 3 remain active and unaffected.
