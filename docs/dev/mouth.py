import cv2
import dlib
import numpy as np
from scipy.spatial import distance
from PIL import ImageFont, ImageDraw, Image
from collections import deque

# 얼굴 감지기와 랜드마크 예측기 초기화
detector = dlib.get_frontal_face_detector()
predictor = dlib.shape_predictor("shape_predictor_68_face_landmarks.dat")

# 한글 폰트 로드
font_path = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
font = ImageFont.truetype(font_path, 32)


def mouth_aspect_ratio(mouth_points):
    A = distance.euclidean(mouth_points[2], mouth_points[10])  # 51, 59
    B = distance.euclidean(mouth_points[4], mouth_points[8])   # 53, 57
    C = distance.euclidean(mouth_points[0], mouth_points[6])   # 49, 55
    mar = (A + B) / (2.0 * C)
    return mar


def put_korean_text(image, text, position, font, color=(0, 255, 0)):
    img_pil = Image.fromarray(image)
    draw = ImageDraw.Draw(img_pil)
    draw.text(position, text, font=font, fill=color)
    return np.array(img_pil)


cap = cv2.VideoCapture(0)

mar_threshold = 0.5
mar_history = deque(maxlen=60)  # 2초 동안의 MAR 값 저장 (30fps 가정)
eating_detected = False
eating_counter = 0
not_eating_counter = 0

while True:
    ret, frame = cap.read()
    if not ret:
        break

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    faces = detector(gray)

    if len(faces) > 0:
        face = faces[0]
        landmarks = predictor(gray, face)

        mouth_points = []
        for n in range(48, 68):
            x = landmarks.part(n).x
            y = landmarks.part(n).y
            mouth_points.append((x, y))
            cv2.circle(frame, (x, y), 2, (0, 255, 0), -1)

        mar = mouth_aspect_ratio(mouth_points)
        mar_history.append(mar)

        if len(mar_history) == 60:
            mar_std = np.std(mar_history)  # MAR 값의 표준편차
            mar_range = max(mar_history) - min(mar_history)  # MAR 값의 범위

            # 입을 벌렸다 닫는 행동 감지
            if mar_std > 0.05 and mar_range > 0.2:
                eating_counter += 1
                not_eating_counter = 0
            else:
                not_eating_counter += 1
                eating_counter = 0

            if eating_counter > 30:  # 1초 이상 먹는 행동이 감지되면
                eating_detected = True
            elif not_eating_counter > 90:  # 3초 이상 먹는 행동이 감지되지 않으면
                eating_detected = False

            if eating_detected:
                message = "밥을 잘 먹고 있어요"
                color = (0, 255, 0)
            else:
                message = "밥을 어서 먹어요"
                color = (0, 0, 255)

            frame = put_korean_text(
                frame, message, (10, frame.shape[0] - 50), font, color)

        # MAR 값과 기타 정보 표시 (디버깅용)
        frame = put_korean_text(
            frame, f"MAR: {mar:.2f}", (10, 30), font, (255, 0, 0))
        frame = put_korean_text(
            frame, f"Eating Counter: {eating_counter}", (10, 70), font, (255, 0, 0))
        frame = put_korean_text(
            frame, f"Not Eating Counter: {not_eating_counter}", (10, 110), font, (255, 0, 0))

    else:
        frame = put_korean_text(frame, "얼굴이 감지되지 않았습니다",
                                (10, frame.shape[0] - 50), font, (0, 0, 255))

    cv2.imshow("Eating Monitor", frame)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
