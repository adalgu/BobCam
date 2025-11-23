#!/bin/bash
# BobCam Phase 1 빠른 시작 스크립트

echo "🚀 BobCam Phase 1 설정 및 실행 가이드"
echo "============================================"

# 현재 디렉토리 확인
cd /Users/gunn.kim/study/Bob-Cam-New/

echo "📁 현재 위치: $(pwd)"
echo ""

# Python 환경 확인
echo "🐍 Python 환경 확인..."
if command -v python3 &> /dev/null; then
    echo "✅ Python3 설치됨: $(python3 --version)"
else
    echo "❌ Python3가 설치되지 않았습니다."
    exit 1
fi
echo ""

# 필수 패키지 설치
echo "📦 필수 패키지 설치 중..."
echo "pip3 install scipy numpy 를 실행합니다..."
pip3 install scipy numpy

echo ""
echo "🧪 기능 테스트 실행..."
echo "python3 test_phase1.py 를 실행합니다..."
python3 test_phase1.py

echo ""
echo "✨ 설정 완료! 이제 다음 명령어로 앱을 실행할 수 있습니다:"
echo ""
echo "🔥 고급 감지 앱 실행:"
echo "   python3 main_enhanced.py"
echo ""
echo "🛡️ 안정 버전 앱 실행:"
echo "   python3 main_stable.py"
echo ""
echo "📊 테스트만 실행:"
echo "   python3 test_phase1.py"
