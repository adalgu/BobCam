# 새로운 대화 세션용 프롬프트

## 읽어야 할 파일들

다음 파일들을 먼저 읽어주세요:

1. **현재 안정 버전 코드**
   ```
   /Users/gunn.kim/study/Bob-Cam-New/main_stable.py
   ```

2. **연구 보고서 (핵심 기술 정보)**
   ```
   /Users/gunn.kim/study/Bob-Cam-New/docs/research/eating-detection-research-2025.md
   ```

3. **개발 로드맵 (구현 가이드)**
   ```
   /Users/gunn.kim/study/Bob-Cam-New/docs/development-roadmap.md
   ```

4. **프로젝트 README (현재 상황)**
   ```
   /Users/gunn.kim/study/Bob-Cam-New/README.md
   ```

---

## 사용할 프롬프트

```
안녕하세요! BobCam 프로젝트 개발을 이어서 진행하겠습니다.

현재 상황:
- MediaPipe FaceMesh로 입술 움직임만 감지하는 식사 모니터링 앱 개발 중
- 입을 다물고 턱으로만 씹는 케이스를 놓치는 문제 발견
- 최신 연구 조사 완료 및 개선 방향 수립 완료

이제 Phase 1으로 턱 움직임 감지 기능을 추가하고 싶습니다.

다음 파일들을 읽어서 현재 상황을 파악해 주세요:
1. /Users/gunn.kim/study/Bob-Cam-New/main_stable.py (현재 안정 버전)
2. /Users/gunn.kim/study/Bob-Cam-New/docs/research/eating-detection-research-2025.md (연구 결과)
3. /Users/gunn.kim/study/Bob-Cam-New/docs/development-roadmap.md (구현 계획)
4. /Users/gunn.kim/study/Bob-Cam-New/README.md (프로젝트 개요)

목표:
1. 기존 EatingStatus 클래스를 확장하여 턱 움직임 감지 추가
2. MediaPipe FaceMesh의 턱 랜드마크 포인트들 활용
3. 입술 + 턱 움직임 복합 판단으로 정확도 향상
4. 기존 안정성은 유지하면서 점진적 개선

구체적으로 도와주세요:
- 턱 랜드마크 포인트 추가 (연구에서 찾은 인덱스들)
- AdvancedEatingStatus 클래스 구현
- 기존 코드와 안전하게 통합하는 방법
- 턱 움직임 감지 알고리즘 구현

개발 환경: 맥북, Python, 로컬 폴더 /Users/gunn.kim/study/Bob-Cam-New/
```

---

## 추가 컨텍스트 (필요시 제공)

만약 AI가 더 자세한 정보가 필요하다고 하면:

```
추가 정보:
- 현재 입술 랜드마크만 사용: 상순(13), 하순(14), 입꼬리(61, 291)
- 연구에서 찾은 턱 랜드마크: [172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397, 288, 361, 323]
- 목표 정확도: 현재 75% → 85% (턱 감지 추가로)
- 실시간 성능 유지 필수 (30+ FPS)
- 안정성 우선 (크래시 방지)

dev/ 폴더에 YOLO 모델들도 있지만, 일단 턱 감지부터 먼저 구현하고 싶습니다.
```
