[2025-07-17T05:59:40] OpenAI Codex v0.7.0 (research preview)
--------
workdir: /Users/gunn.kim/study/BobCam
model: o4-mini
provider: openai
approval: Never
sandbox: workspace-write
reasoning effort: medium
reasoning summaries: auto
--------
[2025-07-17T05:59:40] User instructions:
데이터 처리용 Python 스크립트(비디오에서 입술 영역 추출), 개선된 휴리스틱 알고리즘의 Swift 코드 스니펫, 정확도 계산용 Swift 함수 초안을 작성해주세요.
[2025-07-17T06:00:15] thinking
**Drafting code snippets**

I’m starting on a Python script to read video files and extract lip regions from frames. I’m thinking about using Mediapipe Face Mesh for identifying lip landmarks and OpenCV for processing the video. The idea is to crop the mouth region based on defined landmarks and save the images. 

Next, I’ll create a Swift snippet for a heuristic algorithm, focusing on an improved approach with weighted sums and maybe some smoothing. Then, I'll include a function to calculate accuracy based on predictions and ground truth, ensuring proper array length matching.
[2025-07-17T06:00:15] thinking
**Implementing scripts and heuristics**

I'm working on a Swift snippet for an improved threshold heuristic. It will have a function that evaluates values against a set threshold. 

For the Python script, I'll use argparse to handle the input video and output directory, and then integrate OpenCV and Mediapipe for extracting lip regions. This involves detecting landmarks for both outer and inner lips, cropping the frames, and saving them sequentially. 

I’ll also ensure to comment and provide instructions in the scripts and organize the files properly. Let’s get started with this implementation!
[2025-07-17T06:00:15] apply_patch auto_approved=true:
A /Users/gunn.kim/study/BobCam/extract_lip_regions.py
#!/usr/bin/env python3
"""
extract_lip_regions.py

Script to extract lip regions from input videos and save them as cropped images.
Usage:
    python extract_lip_regions.py --input /path/to/video.mp4 --output /path/to/output_dir
"""
import cv2
import os
import argparse
import mediapipe as mp

def extract_lips_from_video(input_path, output_dir, max_frames=None):
    os.makedirs(output_dir, exist_ok=True)
    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        raise IOError(f"Cannot open video file: {input_path}")

    mp_face = mp.solutions.face_mesh
    face_mesh = mp_face.FaceMesh(static_image_mode=False, max_num_faces=1, refine_landmarks=True)

    frame_idx = 0
    saved_count = 0
    # define lip landmarks indices (Mediapipe FaceMesh)
    lip_landmarks = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291,
                     78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308]

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        if max_frames and saved_count >= max_frames:
            break

        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(rgb_frame)
        if results.multi_face_landmarks:
            mesh = results.multi_face_landmarks[0]
            h, w, _ = frame.shape
            points = []
            for idx in lip_landmarks:
                lm = mesh.landmark[idx]
                x, y = int(lm.x * w), int(lm.y * h)
                points.append((x, y))

            xs, ys = zip(*points)
            x_min, x_max = max(min(xs) - 5, 0), min(max(xs) + 5, w)
            y_min, y_max = max(min(ys) - 5, 0), min(max(ys) + 5, h)
            lip_crop = frame[y_min:y_max, x_min:x_max]
            out_path = os.path.join(output_dir, f"frame_{frame_idx:06d}.png")
            cv2.imwrite(out_path, lip_crop)
            saved_count += 1

        frame_idx += 1

    cap.release()
    face_mesh.close()
    print(f"Extracted {saved_count} lip frames to {output_dir}")

def main():
    parser = argparse.ArgumentParser(description="Extract lip regions from video.")
    parser.add_argument("--input", "-i", required=True, help="Path to input video file.")
    parser.add_argument("--output", "-o", required=True, help="Directory to save lip crops.")
    parser.add_argument("--max-frames", "-m", type=int, default=None,
                        help="Maximum number of frames to process.")
    args = parser.parse_args()
    extract_lips_from_video(args.input, args.output, args.max_frames)

if __name__ == "__main__":
    main()
[2025-07-17T06:00:15] apply_patch(auto_approved=true) exited 0 in 0ms:
Success. Updated the following files:
A /Users/gunn.kim/study/BobCam/extract_lip_regions.py
[2025-07-17T06:00:15] tokens used: 6088
[2025-07-17T06:00:22] apply_patch auto_approved=true:
A /Users/gunn.kim/study/BobCam/ImprovedHeuristic.swift
//
//  ImprovedHeuristic.swift
//  A snippet demonstrating an improved heuristic algorithm.
//
//  This heuristic applies a weighted moving average and adaptive threshold.
//

import Foundation

struct ImprovedHeuristic {
    /// Window size for moving average
    let windowSize: Int
    /// Base threshold for detection
    let baseThreshold: Double

    init(windowSize: Int = 5, baseThreshold: Double = 0.5) {
        self.windowSize = windowSize
        self.baseThreshold = baseThreshold
    }

    /// Compute weighted moving average over the data
    private func weightedMovingAverage(_ data: [Double]) -> [Double] {
        let weights = (1...windowSize).map { Double($0) }
        let weightSum = weights.reduce(0, +)
        var result: [Double] = []
        for i in 0..<data.count {
            let start = max(0, i - windowSize + 1)
            let segment = data[start...i]
            let segmentWeights = weights.suffix(segment.count)
            let weightedSum = zip(segment, segmentWeights).map(*).reduce(0, +)
            result.append(weightedSum / weightSum)
        }
        return result
    }

    /// Evaluate data using adaptive threshold on moving average
    func evaluate(_ data: [Double]) -> [Bool] {
        let smoothed = weightedMovingAverage(data)
        let dynamicThreshold = baseThreshold * (1.0 + variance(of: smoothed))
        return smoothed.map { $0 > dynamicThreshold }
    }

    /// Simple variance calculation
    private func variance(of data: [Double]) -> Double {
        guard data.count > 1 else { return 0 }
        let mean = data.reduce(0, +) / Double(data.count)
        let sumSquared = data.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
        return sumSquared / Double(data.count - 1)
    }
}
[2025-07-17T06:00:22] apply_patch(auto_approved=true) exited 0 in 0ms:
Success. Updated the following files:
A /Users/gunn.kim/study/BobCam/ImprovedHeuristic.swift
[2025-07-17T06:00:22] tokens used: 6685
[2025-07-17T06:00:25] apply_patch auto_approved=true:
A /Users/gunn.kim/study/BobCam/AccuracyCalculator.swift
//
//  AccuracyCalculator.swift
//  Utility for computing accuracy metrics.
//

import Foundation

/// Calculates the accuracy of predictions against ground truth
/// - Parameters:
///   - predictions: Array of predicted labels or values.
///   - groundTruth: Array of true labels or values.
/// - Returns: Accuracy as a value between 0.0 and 1.0.
func calculateAccuracy<T: Equatable>(predictions: [T], groundTruth: [T]) -> Double {
    guard predictions.count == groundTruth.count, !predictions.isEmpty else {
        return 0.0
    }
    let correct = zip(predictions, groundTruth).filter { $0 == $1 }.count
    return Double(correct) / Double(predictions.count)
}
[2025-07-17T06:00:25] apply_patch(auto_approved=true) exited 0 in 0ms:
Success. Updated the following files:
A /Users/gunn.kim/study/BobCam/AccuracyCalculator.swift
[2025-07-17T06:00:25] tokens used: 6949
[2025-07-17T06:00:28] codex
다음과 같이 세 가지 파일을 추가했습니다:

1. **extract_lip_regions.py**  
   - Mediapipe FaceMesh를 이용해 비디오 프레임에서 입술 랜드마크를 검출하고, 해당 영역을 크롭하여 PNG로 저장하는 스크립트입니다.  
   - `--input`, `--output`, `--max-frames` 인자를 받아 실행할 수 있습니다.

2. **ImprovedHeuristic.swift**  
   - 윈도우 기반 가중 이동 평균을 적용하고, 데이터 분산을 이용해 동적으로 문턱값을 조정하는 개선된 휴리스틱 알고리즘 코드 스니펫입니다.  
   - `evaluate(_:)` 메서드로 Bool 배열 형태의 판정을 반환합니다.

3. **AccuracyCalculator.swift**  
   - 예측값과 정답값을 받아 정확도를 0.0–1.0 사이의 Double로 계산하는 제너릭 함수 초안입니다.  

필요 시 추가 조정이나 통합 테스트 후 사용하시기 바랍니다.
[2025-07-17T06:00:28] tokens used: 7213
