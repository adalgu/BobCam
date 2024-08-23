# 사용할 라이브러리 선언
import cv2
import dlib
import sys
import numpy as np

# 영상 크기 10분의 3만큼 줄이기
scaler = 0.3

# detector 초기화
detector = dlib.get_frontal_face_detector()
# 학습된 모델 넣기
predictor = dlib.shape_predictor('shape_predictor_68_face_landmarks.dat')

# 영상 로드
# cv2.VideoCapture(0) 이면 웹캠
# cap = cv2.VideoCapture('samples/A.mp4')
cap = cv2.VideoCapture(0)
# 얼굴 위에 붙일 png 이미지 로드
overlay = cv2.imread('samples/ryan_transparent.png', cv2.IMREAD_UNCHANGED)

face_roi = []
face_sizes = []

# 무한 반복
while True:
    # 프레임 단위로 읽기
    ret, img = cap.read()
    # 영상 끝나면 종료
    if not ret:
        break

    # 프레임 10분의 3만큼 축소
    img = cv2.resize(
        img, (int(img.shape[1] * scaler), int(img.shape[0] * scaler)))
    # 원본 이미지 저장
    ori = img.copy()

    # 얼굴 찾기
    if len(face_roi) == 0:
        faces = detector(img, 1)
    else:
        roi_img = img[face_roi[0]:face_roi[1], face_roi[2]:face_roi[3]]
        # cv2.imshow('roi', roi_img)
        faces = detector(roi_img)

    # 얼굴 없을 경우
    if len(faces) == 0:
        print('no faces!')

    # 얼굴 특징점(랜드마크) 추출
    for face in faces:
        if len(face_roi) == 0:
            dlib_shape = predictor(img, face)
            shape_2d = np.array([[p.x, p.y] for p in dlib_shape.parts()])
        else:
            dlib_shape = predictor(roi_img, face)
            shape_2d = np.array([[p.x + face_roi[2], p.y + face_roi[0]]
                                for p in dlib_shape.parts()])

            # 얼굴에 68개의 점 그리기
        for s in shape_2d:
            cv2.circle(img, center=tuple(s), radius=1, color=(
                255, 255, 255), thickness=2, lineType=cv2.LINE_AA)

        # 얼굴 중심 구하기
        center_x, center_y = np.mean(shape_2d, axis=0).astype(np.int)

        # compute face boundaries
        min_coords = np.min(shape_2d, axis=0)
        max_coords = np.max(shape_2d, axis=0)

        # draw min, max coords
        cv2.circle(img, center=tuple(min_coords), radius=1, color=(
            255, 0, 0), thickness=2, lineType=cv2.LINE_AA)
        cv2.circle(img, center=tuple(max_coords), radius=1, color=(
            255, 0, 0), thickness=2, lineType=cv2.LINE_AA)

        # 얼굴 크기 계산(자연스럽게 스티커 붙이기 위함)
        face_size = max(max_coords - min_coords)
        face_sizes.append(face_size)
        if len(face_sizes) > 10:
            del face_sizes[0]
        mean_face_size = int(np.mean(face_sizes) * 1.8)

        # compute face roi
        face_roi = np.array([int(min_coords[1] - face_size / 2), int(max_coords[1] + face_size / 2),
                            int(min_coords[0] - face_size / 2), int(max_coords[0] + face_size / 2)])
        face_roi = np.clip(face_roi, 0, 10000)

        # 얼굴에 스티커 붙이기(자연스러운 위치 넣으려고 +8,  -25로 이동)
        result = overlay_transparent(
            ori, overlay, center_x + 8, center_y - 25, overlay_size=(mean_face_size, mean_face_size))

    # 원본, 랜드마크, 스티커 붙인 화면 출력
    cv2.imshow('original', ori)
    cv2.imshow('facial landmarks', img)
    cv2.imshow('result', result)
    if cv2.waitKey(1) == ord('q'):
        sys.exit(1)

# ----------

# 얼굴 가릴 스티커를 영상에 띄우는 함수
# background_img를 center x, center y, 중심으로 overlay_size사이즈만큼 리사이즈해서 영상에 붙여줌


def overlay_transparent(background_img, img_to_overlay_t, x, y, overlay_size=None):
    bg_img = background_img.copy()
    # convert 3 channels to 4 channels
    if bg_img.shape[2] == 3:
        bg_img = cv2.cvtColor(bg_img, cv2.COLOR_BGR2BGRA)

    if overlay_size is not None:
        img_to_overlay_t = cv2.resize(img_to_overlay_t.copy(), overlay_size)

    b, g, r, a = cv2.split(img_to_overlay_t)

    mask = cv2.medianBlur(a, 5)

    h, w, _ = img_to_overlay_t.shape
    roi = bg_img[int(y-h/2):int(y+h/2), int(x-w/2):int(x+w/2)]

    img1_bg = cv2.bitwise_and(roi.copy(), roi.copy(),
                              mask=cv2.bitwise_not(mask))
    img2_fg = cv2.bitwise_and(img_to_overlay_t, img_to_overlay_t, mask=mask)

    bg_img[int(y-h/2):int(y+h/2), int(x-w/2)           :int(x+w/2)] = cv2.add(img1_bg, img2_fg)

    # convert 4 channels to 4 channels
    bg_img = cv2.cvtColor(bg_img, cv2.COLOR_BGRA2BGR)

    return bg_img
