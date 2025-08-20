# Subagent CLI 활용 가이드

## 개요

4개의 subagent CLI를 활용하여 병렬 작업을 수행하고 다양한 관점에서 문제를 해결할 수 있습니다.

## 사용 가능한 Subagent들

Subagent CLI는 Shell에서 실행할 수 있는 다양한 AI 모델을 기반으로 합니다. 각 subagent는 특정 역할과 강점을 가지고 있으며, 이를 통해 효율적인 작업 분담이 가능합니다.

### 1. 🤖 Gemini CLI

- **정체성**: Gemini CLI Agent
- **특징**: Google의 Gemini 모델 기반
- **강점**: 창의적 사고, 멀티모달 처리, 빠른 응답
- **기본 명령어**: `gemini -p "prompt" -m "gemini-2.5-pro"`

### 2. 🎭 Claude CLI

- **정체성**: Claude Code (Anthropic's official CLI assistant)
- **특징**: 소프트웨어 엔지니어링 특화
- **강점**: 코드 분석, 디버깅, 개발 워크플로우
- **기본 명령어**: `claude -p "prompt"`

### 3. 🧠 Zen Agent (MCP)

- **정체성**: Keystone (senior engineering thought-partner)
- **특징**: 고급 추론, 기술적 의사결정 지원
- **강점**: 협업적 사고, 검증, 실용적 솔루션
- **기본 명령어**: `zen:chat`

### 4. ⚡ Codex CLI

- **정체성**: ChatGPT (coding assistant)
- **특징**: OpenAI 기반 코딩 어시스턴트
- **강점**: 코드 생성, 자동화, 빠른 개발
- **기본 명령어**: `codex exec "prompt" --model "o4-mini" --full-auto`

## 병렬 작업 전략

### Pattern 1: 관점별 분산 처리

```bash
# 각각 다른 관점으로 동일한 문제 분석
gemini -p "창의적 관점에서 [문제] 분석" &
claude -p "엔지니어링 관점에서 [문제] 분석" &
codex exec "효율성 관점에서 [문제] 분석" --model "o4-mini" &
# zen은 MCP 호출로 별도 처리
```

### Pattern 2: 단계별 파이프라인

```bash
# 1단계: 아이디어 생성 (Gemini)
# 2단계: 기술적 검증 (Claude)
# 3단계: 구현 (Codex)
# 4단계: 검토 (Zen)
```

### Pattern 3: 전문 영역별 분담

- **Gemini**: 콘텐츠 생성, 창의적 아이디어
- **Claude**: 코드 리뷰, 아키텍처 설계
- **Codex**: 빠른 프로토타이핑, 자동화
- **Zen**: 최종 검증, 의사결정 지원

## 활용 시나리오

### 📝 콘텐츠 제작 프로젝트

1. **Gemini**: 창의적 아이디어, 구조 제안
2. **Claude**: 기술적 정확성 검토
3. **Zen**: 품질 평가 및 개선 제안
4. **Codex**: 자동화 스크립트 생성

### 🔧 소프트웨어 개발

1. **Claude**: 요구사항 분석, 아키텍처 설계
2. **Codex**: 코드 생성, 테스트 작성
3. **Gemini**: 사용자 경험 개선 아이디어
4. **Zen**: 코드 리뷰, 최적화 제안

### 📊 데이터 분석 프로젝트

1. **Claude**: 데이터 구조 분석
2. **Codex**: 분석 스크립트 자동 생성
3. **Gemini**: 인사이트 발굴, 시각화 아이디어
4. **Zen**: 결과 검증, 비즈니스 적용 방안

## 베스트 프랙티스

### 1. 명확한 역할 분담

각 subagent의 강점에 맞는 작업 할당

### 2. 결과 통합 전략

- 각 subagent 결과를 체계적으로 수집
- 상호 보완적 관점 활용
- 최종 품질 검증 단계 필수

### 3. 효율적 명령어 사용

```bash
# 병렬 실행 템플릿
(gemini -p "prompt1" > result1.txt) &
(claude -p "prompt2" > result2.txt) &
(codex exec "prompt3" --model "o4-mini" > result3.txt) &
wait
# zen은 MCP로 별도 처리 후 통합
```

### 4. 품질 관리

- 각 단계별 검증점 설정
- 상호 교차 검토 실시
- 최종 통합 검증 필수

## 주의사항

1. **리소스 관리**: 병렬 실행 시 API 한도 고려
2. **결과 일관성**: 서로 다른 모델의 결과 차이 인식
3. **에러 처리**: 각 subagent별 실패 시 대응 방안
4. **보안**: 민감한 정보 처리 시 각 CLI의 보안 정책 확인

## 다음 단계

각 subagent별 상세한 프롬프트 예시와 활용 방법은 다음 문서들을 참조하세요:

- `gemini-cli-examples.md`
- `claude-cli-examples.md`
- `zen-agent-examples.md`
- `codex-cli-examples.md`
- `parallel-workflow-strategies.md`
