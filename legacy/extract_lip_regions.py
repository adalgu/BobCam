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
