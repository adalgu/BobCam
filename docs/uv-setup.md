# 🚀 밥잘먹어YO - uv 가상환경 설정

## 1. uv 설치 (아직 없다면)

```bash
# Mac의 경우
curl -LsSf https://astral.sh/uv/install.sh | sh

# 또는 brew로
brew install uv
```

## 2. 프로젝트 초기화 (현재 폴더에서)

```bash
# 현재 디렉토리를 프로젝트로 초기화
uv init --name bobcam

# Python 버전 지정 (3.11 추천)
uv python pin 3.11
```

## 3. 필요한 라이브러리 추가

```bash
# 핵심 라이브러리들 한 번에 설치
uv add opencv-python mediapipe selenium pyttsx3 numpy

# 개발용 도구들 (선택사항)
uv add --dev pytest black flake8
```

## 4. 프로젝트 구조 생성

```bash
# 소스 코드 폴더 생성
mkdir src
mv main.py src/  # 기존 main.py가 있다면

# 새로운 MVP 코드 생성
touch src/eating_youtube_mvp.py
```

## 5. pyproject.toml 확인

실행 후 자동 생성되는 `pyproject.toml`:

```toml
[project]
name = "bobcam"
version = "0.1.0"
description = "스마트 식사 모니터링 앱"
dependencies = [
    "opencv-python>=4.8.0",
    "mediapipe>=0.10.0",
    "selenium>=4.15.0",
    "pyttsx3>=2.90",
    "numpy>=1.24.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

## 6. 가상환경 활성화 및 실행

```bash
# 가상환경에서 실행
uv run python src/eating_youtube_mvp.py

# 또는 쉘 활성화
uv shell
python src/eating_youtube_mvp.py
```

## 7. ChromeDriver 설정

```bash
# ChromeDriver 자동 다운로드 (최신 방법)
uv add webdriver-manager
```

그리고 코드에서:

```python
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.service import Service

# ChromeDriver 자동 설정
service = Service(ChromeDriverManager().install())
self.driver = webdriver.Chrome(service=service, options=chrome_options)
```

## 8. 개발 워크플로우

```bash
# 새 라이브러리 추가
uv add 라이브러리명

# 스크립트 실행
uv run python src/스크립트.py

# 의존성 동기화
uv sync

# 다른 환경에서 설치
uv sync  # pyproject.toml 기반으로 자동 설치
```

## 9. 유용한 uv 명령어들

```bash
# 설치된 패키지 확인
uv pip list

# 가상환경 위치 확인
uv venv --help

# 프로젝트 정보 확인
uv info

# 의존성 트리 확인
uv tree
```

## 🎯 바로 시작하기

현재 폴더에서 다음 3개 명령어만 실행하면 끝:

```bash
uv init --name bobcam
uv add opencv-python mediapipe selenium pyttsx3 numpy webdriver-manager
uv run python eating_youtube_mvp.py
```

## 💡 Tip: 빠른 개발을 위한 alias

`.zshrc` 또는 `.bashrc`에 추가:

```bash
alias uvrun="uv run python"
alias uvadd="uv add"
alias uvshell="uv shell"
```

사용 예:

```bash
uvrun src/eating_youtube_mvp.py
uvadd requests
```
