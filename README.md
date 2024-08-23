# 스마트 식사 모니터 (Smart Eating Monitor)

이 프로젝트는 컴퓨터 비전과 머신러닝을 활용하여 아이의 식사 행동을 모니터링하는 애플리케이션입니다. 부모의 수고를 덜어주면서 아이의 건강한 식습관 형성을 돕는 것이 목표입니다.

## 주요 기능

1. 실시간 얼굴 감지 및 입 움직임 추적
2. 식사 행동 분석 (먹고 있는지 아닌지 판단)
3. 시각적 피드백 제공 (한글 메시지 표시)

## 스크린샷

### 식사 중 감지

![screenshot_eating](https://github.com/user-attachments/assets/951998a7-99c0-472e-bc82-38ea59019b74)
아이가 식사를 하고 있을 때 앱이 이를 감지하고 긍정적인 메시지를 표시합니다.

### 얼굴 미감지

![screenshot_not-detecting](https://github.com/user-attachments/assets/a916676b-0191-428a-9680-997ccc80f2f8)
카메라에 얼굴이 감지되지 않을 때 앱이 알림을 표시합니다.

### 식사하지 않음 (예시 1)

![screenshot_not-eating1](https://github.com/user-attachments/assets/0b69c5f6-e552-495d-8f96-7a77ba7ccce8)
아이가 식사를 하지 않고 있을 때 앱이 이를 감지하고 독려 메시지를 표시합니다.

### 식사하지 않음 (예시 2)

![screenshot_not-eatting2](https://github.com/user-attachments/assets/09a5e60e-732b-424e-8a5d-d7610775f6ff)
다른 각도에서 아이가 식사를 하지 않고 있는 상황을 감지한 모습입니다.

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

1. 프로그램 실행:

   ```
   python main.py
   ```

2. 웹캠을 통해 아이의 얼굴이 화면에 나오도록 조정합니다.
3. 프로그램이 아이의 식사 행동을 자동으로 분석하고 피드백을 제공합니다.
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

이 프로젝트에 기여하고 싶으시다면, 풀 리퀘스트를 보내주세요. 모든 기여를 환영합니다!

1. 프로젝트를 포크합니다.
2. 새로운 기능 브랜치를 생성합니다 (`git checkout -b feature/AmazingFeature`).
3. 변경 사항을 커밋합니다 (`git commit -m 'Add some AmazingFeature'`).
4. 브랜치에 푸시합니다 (`git push origin feature/AmazingFeature`).
5. 풀 리퀘스트를 오픈합니다.

## 라이선스

이 프로젝트는 MIT 라이선스 하에 있습니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.
