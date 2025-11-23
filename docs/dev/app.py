from flask import Flask, render_template, Response, jsonify, request
import cv2
import numpy as np
import dlib
from scipy.spatial import distance
import requests
import base64

app = Flask(__name__)

# 전역 변수 설정
detector = dlib.get_frontal_face_detector()
predictor = dlib.shape_predictor("shape_predictor_68_face_landmarks.dat")
eating_frames = 0
not_eating_frames = 0
EATING_THRESHOLD = 10


def get_mouth_aspect_ratio(landmarks):
    A = distance.euclidean(landmarks[61], landmarks[67])
    B = distance.euclidean(landmarks[62], landmarks[66])
    C = distance.euclidean(landmarks[63], landmarks[65])
    D = distance.euclidean(landmarks[60], landmarks[64])
    mar = (A + B + C) / (3.0 * D)
    return mar


def is_hand_near_mouth(frame, face):
    x, y, w, h = face
    mouth_region = frame[y+int(h*0.6):y+h, x:x+w]
    converted = cv2.cvtColor(mouth_region, cv2.COLOR_RGB2HSV)
    lower = np.array([0, 20, 70], dtype="uint8")
    upper = np.array([20, 255, 255], dtype="uint8")
    skinMask = cv2.inRange(converted, lower, upper)
    skin_ratio = np.sum(skinMask == 255) / skinMask.size
    return skin_ratio > 0.3


def capture_and_detect():
    global eating_frames, not_eating_frames

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("카메라를 열 수 없습니다.")
        return False, None, None

    ret, frame = cap.read()
    if not ret:
        print("프레임을 캡처할 수 없습니다.")
        cap.release()
        return False, None, None

    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    gray = cv2.cvtColor(rgb_frame, cv2.COLOR_RGB2GRAY)
    gray = np.array(gray, dtype='uint8')

    faces = detector(gray)
    is_eating = False
    is_ambiguous = False

    for face in faces:
        shape = predictor(gray, face)
        landmarks = np.array([(p.x, p.y) for p in shape.parts()])

        mar = get_mouth_aspect_ratio(landmarks)
        hand_near_mouth = is_hand_near_mouth(
            rgb_frame, (face.left(), face.top(), face.width(), face.height()))

        if mar > 0.5 and hand_near_mouth:
            eating_frames += 1
            not_eating_frames = 0
        else:
            eating_frames = 0
            not_eating_frames += 1

        if eating_frames > EATING_THRESHOLD:
            is_eating = True
        elif not_eating_frames > EATING_THRESHOLD:
            is_eating = False
        else:
            is_ambiguous = True

        cv2.putText(frame, f"MAR: {mar:.2f}", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        cv2.putText(frame, f"Hand near mouth: {hand_near_mouth}", (
            10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        cv2.putText(frame, f"Is eating: {is_eating}", (10, 90),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

    cap.release()
    return is_eating, is_ambiguous, frame


def cloud_ai_request(frame):
    # 이 함수는 실제 클라우드 AI 서비스를 사용할 때 구현해야 합니다.
    # 여기서는 가상의 응답을 반환합니다.
    _, buffer = cv2.imencode('.jpg', frame)
    img_str = base64.b64encode(buffer).decode('utf-8')

    # 실제 API 호출 대신 가상의 응답을 반환
    return {'is_eating': np.random.choice([True, False])}


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/video_feed')
def video_feed():
    def gen():
        while True:
            is_eating, is_ambiguous, frame = capture_and_detect()
            if frame is None:
                continue

            if is_ambiguous:
                cloud_response = cloud_ai_request(frame)
                is_eating = cloud_response['is_eating']

            if is_eating:
                cv2.putText(frame, "밥을 잘 먹고 있어요", (10, 120),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            else:
                cv2.putText(frame, "밥을 잘 안 먹고 있어요", (10, 120),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

            ret, buffer = cv2.imencode('.jpg', frame)
            frame = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

    return Response(gen(), mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/check_eating')
def check_eating():
    is_eating, is_ambiguous, _ = capture_and_detect()
    if is_ambiguous:
        cloud_response = cloud_ai_request(_)
        is_eating = cloud_response['is_eating']
    return jsonify({"is_eating": is_eating})


if __name__ == '__main__':
    app.run(debug=True)
