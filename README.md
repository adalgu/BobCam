<<<<<<< HEAD
# BobCam: 스마트 식사 모니터 (Smart Eating Monitor)

BobCam은 '밥(Bob)'을 먹는지를 모니터링하는 카메라(Cam)의 약자로, 컴퓨터 비전과 머신러닝을 활용하여 아이의 식사 행동을 모니터링하는 애플리케이션입니다. 부모의 수고를 덜어주면서 아이의 건강한 식습관 형성을 돕는 것이 목표입니다.

## 주요 기능

1. 실시간 얼굴 감지 및 입 움직임 추적
2. 식사 행동 분석 (먹고 있는지 아닌지 판단)
3. 시각적 피드백 제공 (한글 메시지 표시)

## 스크린샷

### 식사 중 감지

![screenshot_eating](https://github.com/user-attachments/assets/951998a7-99c0-472e-bc82-38ea59019b74)

- 아이가 식사를 하고 있을 때 bobcam이 이를 감지하고 긍정적인 메시지를 표시합니다.

### 얼굴 미감지

![screenshot_not-detecting](https://github.com/user-attachments/assets/a916676b-0191-428a-9680-997ccc80f2f8)

- 카메라에 얼굴이 감지되지 않을 때 bobcam이 알림을 표시합니다.

### 식사하지 않음 (예시 1)

![screenshot_not-eating1](https://github.com/user-attachments/assets/0b69c5f6-e552-495d-8f96-7a77ba7ccce8)

- 아이가 식사를 하지 않고 입을 다물고 있을 때 bobcam이 이를 감지하고 독려 메시지를 표시합니다.

### 식사하지 않음 (예시 2)

![screenshot_not-eatting2](https://github.com/user-attachments/assets/09a5e60e-732b-424e-8a5d-d7610775f6ff)

- 아이가 식사를 하지 않고 입을 벌리고 있는 상황을 감지한 모습입니다.

## 기술 스택

- Python
- OpenCV
- dlib
- NumPy
- SciPy
- Pillow

## 설치 방법

1. 필요한 라이브러리 설치:

   ```
   pip install opencv-python dlib numpy scipy pillow
   ```

2. dlib의 얼굴 랜드마크 모델 다운로드:

   - [shape_predictor_68_face_landmarks.dat](http://dlib.net/files/shape_predictor_68_face_landmarks.dat.bz2) 파일을 다운로드하고 프로젝트 디렉토리에 압축 해제

3. 한글 폰트 설정:
   - AppleSDGothicNeo.ttc 또는 원하는 한글 폰트 파일을 준비하고 경로를 코드에서 수정

## 사용 방법

1. bobcam 실행:

   ```
   python main.py
   ```

2. 웹캠을 통해 아이의 얼굴이 화면에 나오도록 조정합니다.
3. bobcam이 아이의 식사 행동을 자동으로 분석하고 피드백을 제공합니다.
4. 종료하려면 'q' 키를 누르세요.

## 향후 계획

- YOLO(You Only Look Once)를 이용한 객체 탐지 개선
  - 음식 객체 인식을 통한 더 정확한 식사 행동 감지
  - 다양한 식사 환경에서의 성능 향상
- Flask를 이용한 웹 애플리케이션 개발
- 사용자 인터페이스 개선
- 식사 데이터 저장 및 분석 기능 추가
- 다양한 연령대와 식사 환경에 대한 모델 확장

## 개발 현황

현재 개발 중인 기능과 개선 사항은 `dev` 폴더에서 확인할 수 있습니다. 이 폴더에는 다음과 같은 내용이 포함됩니다:

- YOLO 모델 통합 실험
- 웹 애플리케이션 프로토타입
- 성능 최적화 테스트

최신 개발 현황은 정기적으로 이 폴더에 업데이트됩니다. 개발에 참여하거나 진행 상황을 확인하고 싶은 분들은 `dev` 폴더를 참조해 주세요.

## 기여 방법

bobcam 프로젝트에 기여하고 싶으시다면, 풀 리퀘스트를 보내주세요. 모든 기여를 환영합니다!

1. 프로젝트를 포크합니다.
2. 새로운 기능 브랜치를 생성합니다 (`git checkout -b feature/AmazingFeature`).
3. 변경 사항을 커밋합니다 (`git commit -m 'Add some AmazingFeature'`).
4. 브랜치에 푸시합니다 (`git push origin feature/AmazingFeature`).
5. 풀 리퀘스트를 오픈합니다.

## 라이선스

이 프로젝트는 MIT 라이선스 하에 있습니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.
=======
# 🍽️ 아이 식사 유도 MVP – `밥잘먹어YO` (실제 수동 패턴 기반)

## 🎯 목적

부모가 직접 **YouTube 영상 On/Off로 식사를 유도**하던 수동 패턴을 자동화하여,
아이의 식사 행동에 따라 보상이 제공되도록 한다.

---

## 📌 현재 수동 프로세스 요약

| 동작         | 설명                                                    |
| ------------ | ------------------------------------------------------- |
| 👨‍👩‍👧 영상 제어 | 엄마/아빠가 직접 YouTube 앱에서 영상을 틀고 끔          |
| 🍚 먹이기    | 숟가락으로 떠서 아이 입에 넣음                          |
| 🎮 보상 방식 | "한 입 먹으면 다시 틀어줄게", "잘 먹으면 계속 보여줄게" |
| 🛑 중단 조건 | 딴청 피우거나 안 씹고 있으면 영상 정지                  |

---

## 🔄 자동화 MVP 시나리오

### 1. **입 움직임 감지**

- 입이 크게 열리고 닫힘 → 음식 섭취로 간주
- 3초 이상 씹는 듯한 입 움직임 → "먹고 있는 중" 판단

### 2. **YouTube 영상 제어**

- 식사 감지 시 영상 자동 재생 (5~10초)
- 입 움직임이 멈추거나, 일정 시간 아무 반응 없으면 자동 정지

### 3. **보상 강화 로직**

- 연속으로 식사 행동 3회 → 보상 시간 증가
- 딴청 감지되면 "잠깐 멈췄어! 다시 먹으면 보여줄게~" 음성 출력

---

## ⚙️ 시스템 구성 요약

| 모듈         | 설명                                                       |
| ------------ | ---------------------------------------------------------- |
| 입 감지      | MediaPipe FaceMesh → 입 개폐/움직임 파악                   |
| 타이머       | 입 움직임 감지 시간 측정 → 일정 시간 이상 먹지 않으면 중지 |
| YouTube 제어 | JS + Iframe API or Streamlit Webview로 재생 제어           |
| 피드백 음성  | 음성 보상/경고 멘트 (TTS 가능)                             |

---

## 🧪 예시 UX 흐름
>>>>>>> f9a400a (feat: Enhance landmark visibility and finalize features)
