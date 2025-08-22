# Phase 3: Performance Optimization Notes

Last updated: 2025-08-22

## Overview
This document captures the Phase 3 performance optimizations added to the iOS app, focusing on safe frame processing, dynamic throttling, ROI-based detection, and structured runtime metrics for profiling. The goal is to maintain stable processing (no memory growth over 3–5 minutes), keep average processing time and FPS within acceptable bounds (~66 ms per frame, ~12–15 FPS on simulator), and ensure frame drops occur under load without UI hitching.

## Summary of Code Changes

Files updated:
- BobCam-iOS/BobCamAgent/BobCamAgent/VisionService.swift
- BobCam-iOS/BobCamAgent/BobCamAgent/DebugOverlay/DebugOverlayView.swift

Key changes in VisionService:
- Added published metrics:
  - processingTimeMs: Double
  - fps: Double
  - memoryMB: Double
  - peakMemoryMB: Double
  - jitter: Double (existing)
- Prevent overlapping Vision work:
  - isProcessing flag with immediate drop if another frame is in-flight.
- Internal throttling and dynamic tuning:
  - frameInterval starts at 1.0 / 15.0 (~15 FPS).
  - Dynamic tuning with bounds:
    - minInterval: 1.0 / 20.0 (max ~20 FPS)
    - maxInterval: 1.0 / 10.0 (min ~10 FPS)
  - Update rules:
    - If processingTimeMs > 100 ms → frameInterval += 10 ms (capped at maxInterval)
    - If processingTimeMs < 50 ms → frameInterval -= 5 ms (floored at minInterval)
- Region of Interest (ROI):
  - Reuses previous face bounding box with a margin (default 0.2) to reduce scan area.
- Structured metrics log per processed frame:
  - Format:  
    [PERF] ts=<unixSec> memMB=<double> procMs=<double> fps=<double> frameInterval=<sec> roi=<x,y,w,h>
- Memory profiling:
  - reportMemoryUsage() returns Double? in MB.
  - Publishes memoryMB and peakMemoryMB; included in [PERF] line.

Key changes in Debug Overlay:
- Performance panel now shows:
  - Jitter, Processing Time (ms), FPS, Memory (MB), Peak Memory (MB)
- Color thresholds:
  - Processing time: green ≤ 50 ms, orange ≤ 100 ms, red > 100 ms
  - FPS: green ≥ 15, orange ≥ 12, red < 12
  - Jitter: green ≤ 0.01, orange ≤ 0.05, red > 0.05

## Build Status
- Verified clean build on iOS Simulator (iPhone 16 Pro, OS 18.6).
- Build command used:
  - xcodebuild -workspace "BobCam-iOS/BobCamAgent.xcworkspace" -scheme "BobCamAgent" -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6" build

## Runtime Logging and Profiling

Structured log format emitted per successfully processed frame:
```
[PERF] ts=<> memMB=<> procMs=<> fps=<> frameInterval=<> roi=<x,y,w,h>
```

Example:
```
[PERF] ts=1724282692.123 memMB=142.37 procMs=58.4 fps=14.8 frameInterval=0.067 roi=0.32,0.22,0.40,0.55
```

Notes:
- ts: Unix timestamp in seconds.
- memMB: Resident memory usage of the process in MB.
- procMs: Time for the Vision pass (face detection/landmarks) in milliseconds.
- fps: Effective FPS between completed frames (computed from the last completion time).
- frameInterval: Current throttle interval in seconds (tuned dynamically).
- roi: Vision regionOfInterest in normalized coordinates (x, y, w, h) after margin expansion/clamping.

Capturing logs:
- Preferred: run in Xcode and view the app console for [PERF] lines (print output).
- CLI option on Simulator:
  - In some environments, print() is captured by the device log; you can try:
    - xcrun simctl spawn booted log stream --style compact --predicate 'eventMessage CONTAINS "[PERF]"'
  - If nothing appears, use the Xcode console (recommended) or add os_log for guaranteed system logging.

## Tunables and Defaults

VisionService tunables:
- frameInterval:
  - Initial: 1/15 ≈ 0.0667 sec
  - minInterval (upper FPS bound): 1/20 = 0.05 sec (max ~20 FPS)
  - maxInterval (lower FPS bound): 1/10 = 0.1 sec (min ~10 FPS)
  - Dynamic update thresholds:
    - If procMs > 100 → interval += 10 ms (cap at 100 ms)
    - If procMs < 50 → interval -= 5 ms (floor at 50 ms)
- ROI:
  - roiMargin = 0.2 around previous bounding box, clamped to [0,1].
- Frame drop:
  - guard !isProcessing else { return } // immediate drop when busy

DebugOverlay thresholds:
- Jitter: green ≤ 0.01, orange ≤ 0.05, red otherwise
- Processing time: green ≤ 50 ms, orange ≤ 100 ms, red otherwise
- FPS: green ≥ 15, orange ≥ 12, red otherwise

## Recommended Validation Procedure

1) Cold start baseline (idle)
- Launch app with camera permission denied or service stopped.
- Confirm memoryMB is stable and low, FPS ≈ 0, no Vision processing.

2) Normal tracking session (2–3 minutes)
- Start tracking and remain mostly stable facing camera.
- Expect:
  - procMs typically ≤ ~66 ms on simulator.
  - fps averaging ~12–15.
  - frameInterval settling around ~0.067 sec, adjusting slightly with load.
  - memoryMB stays stable; peakMemoryMB may briefly rise early and then plateau.
  - Occasional frame drops under load (no backlog growth).

3) Stress conditions
- Move quickly, occlude face, leave/enter frame.
- Expect:
  - procMs spikes transiently; frameInterval increases up to 0.1 sec if needed.
  - isProcessing-triggered drops prevent queue buildup.
  - previousFaceBoundingBox updates when face is detected; ROI reverts to full frame if no prior box.
  - No UI hitching; service remains .running.

4) Instruments corroboration (optional)
- Use Time Profiler and Allocations to validate in-app metrics and look for leaks/retains.

## Definition of Done (DoD) Checklist

- Stable processing with no memory growth over a 3–5 minute session.
- Average processing time and FPS within acceptable bounds on simulator:
  - procMs ≤ ~66 ms, fps ≈ 12–15.
- Frame drops occur under stress without UI hitching; [PERF] logs confirm drop behavior without backlog.
- Debug Overlay displays live:
  - jitter, processingTimeMs, fps, memoryMB, peakMemoryMB.
- Logs available in Xcode console for post-run analysis.

## Next Steps / Future Work

- Optional: Integrate Monitoring/PerformanceMonitor.swift for timeline persistence and on-device aggregation, or export to CSV.
- ROI toggle in DebugOverlay for A/B testing with/without regionOfInterest.
- Consider os_log for structured system logging instead of print for easier CLI capture:
  - Adopt static OSLog categories and levels; keep [PERF] tag.
- Consider skipping full landmarks every M frames and interpolating with EMA in between to reduce average procMs.
- Persist minor/major configuration changes in user defaults for reproducible experiments.

## Implementation Pointers

- Main-thread safety:
  - Published property updates are dispatched to the main queue.
- Sequence handler reuse:
  - VNSequenceRequestHandler is reused to minimize allocations.
- Error handling:
  - Consecutive error tracking with basic retry and serviceState updates.
