# 스마트 식사 모니터 (Smart Eating Monitor)

이 프로젝트는 컴퓨터 비전과 머신러닝을 활용하여 아이의 식사 행동을 모니터링하는 애플리케이션입니다. 부모의 수고를 덜어주면서 아이의 건강한 식습관 형성을 돕는 것이 목표입니다.

## 주요 기능

1. 실시간 얼굴 감지 및 입 움직임 추적
2. 식사 행동 분석 (먹고 있는지 아닌지 판단)
3. 시각적 피드백 제공 (한글 메시지 표시)

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

- Flask를 이용한 웹 애플리케이션 개발
- 사용자 인터페이스 개선
- 식사 데이터 저장 및 분석 기능 추가

## 기여 방법

이 프로젝트에 기여하고 싶으시다면, 풀 리퀘스트를 보내주세요. 모든 기여를 환영합니다!

## 라이선스

이 프로젝트는 MIT 라이선스 하에 있습니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.
