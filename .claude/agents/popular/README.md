# 🌟 인기 에이전트

가장 많이 사용되고 효과적인 Claude Code subagent들을 모아놓았습니다.

## 🔥 Top 10 필수 에이전트

### 개발 전문가

1. **[python-pro](python-pro.md)** - Python 개발 전문가
   - 🎯 언제: Python 코드 작성, 리팩토링, 최적화
   - ⚡ 특징: 고급 Python 기능, 성능 최적화, 테스트

2. **[javascript-pro](javascript-pro.md)** - JavaScript/TypeScript 전문가  
   - 🎯 언제: 프론트엔드 개발, Node.js 백엔드
   - ⚡ 특징: 최신 ES6+, 비동기 프로그래밍, React/Vue

3. **[frontend-developer](frontend-developer.md)** - 프론트엔드 개발자
   - 🎯 언제: UI 컴포넌트, 반응형 레이아웃
   - ⚡ 특징: React, Vue, Angular, 성능 최적화

4. **[backend-architect](backend-architect.md)** - 백엔드 아키텍트
   - 🎯 언제: API 설계, 데이터베이스 스키마, 마이크로서비스
   - ⚡ 특징: RESTful API, 확장성, 아키텍처 패턴

### 품질 보증

5. **[code-reviewer](code-reviewer.md)** - 코드 리뷰 전문가
   - 🎯 언제: 코드 작성 후 항상 사용
   - ⚡ 특징: 보안, 성능, 유지보수성 검토

6. **[security-auditor](security-auditor.md)** - 보안 감사관
   - 🎯 언제: 보안 취약점 점검, 인증/인가 구현
   - ⚡ 특징: OWASP 규정, JWT, OAuth2, 암호화

7. **[performance-engineer](performance-engineer.md)** - 성능 엔지니어
   - 🎯 언제: 성능 문제 발견, 최적화 필요
   - ⚡ 특징: 프로파일링, 캐싱, 로드 테스트

### AI/ML & 데이터

8. **[ai-engineer](ai-engineer.md)** - AI 엔지니어
   - 🎯 언제: LLM 애플리케이션, RAG 시스템
   - ⚡ 특징: 벡터 검색, AI API 통합, 프롬프트 최적화

9. **[data-scientist](data-scientist.md)** - 데이터 과학자
   - 🎯 언제: 데이터 분석, 머신러닝 모델
   - ⚡ 특징: SQL 쿼리, 통계 분석, 시각화

### 운영 & 인프라

10. **[devops-troubleshooter](devops-troubleshooter.md)** - DevOps 장애 해결사
    - 🎯 언제: 프로덕션 장애, 배포 실패
    - ⚡ 특징: 로그 분석, 모니터링, 신속한 복구

## 🚀 빠른 설치

### 전체 인기 에이전트 설치
```bash
# 모든 인기 에이전트를 ~/.claude/agents/에 복사
cp agents/popular/*.md ~/.claude/agents/
```

### 선택적 설치
```bash
# 개발 필수 3종 세트
cp agents/popular/python-pro.md ~/.claude/agents/
cp agents/popular/code-reviewer.md ~/.claude/agents/
cp agents/popular/security-auditor.md ~/.claude/agents/

# 웹 개발 4종 세트  
cp agents/popular/frontend-developer.md ~/.claude/agents/
cp agents/popular/backend-architect.md ~/.claude/agents/
cp agents/popular/javascript-pro.md ~/.claude/agents/
cp agents/popular/performance-engineer.md ~/.claude/agents/
```

## 💡 사용 팁

### 에이전트 조합 패턴

**🔄 코드 개선 워크플로우**
```
1. 언어 전문가 (python-pro, javascript-pro 등)
2. code-reviewer (품질 검토)
3. security-auditor (보안 점검)
4. performance-engineer (성능 최적화)
```

**🚀 새 프로젝트 시작**
```
1. backend-architect (아키텍처 설계)
2. 언어 전문가 (기술 스택에 맞게)
3. security-auditor (보안 설계)
4. devops-troubleshooter (배포 계획)
```

**🐛 버그 해결**
```
1. debugger (문제 분석)
2. 언어 전문가 (코드 수정)  
3. code-reviewer (수정 사항 검토)
4. test-automator (테스트 추가)
```

## 📊 사용량 통계

이 에이전트들은 다음과 같은 프로젝트에서 가장 많이 사용됩니다:

- **python-pro**: 데이터 분석, 백엔드 API, AI/ML 프로젝트
- **javascript-pro**: 웹 애플리케이션, Node.js 서비스
- **code-reviewer**: 모든 프로젝트 (품질 보증)
- **security-auditor**: 웹 서비스, API, 금융 시스템
- **ai-engineer**: 챗봇, 추천 시스템, NLP 애플리케이션

---

**💬 피드백:** 다른 에이전트도 인기 목록에 추가되어야 한다고 생각하시나요? 
[이슈를 생성](https://github.com/your-org/claude-code-subagents-setup/issues)해서 제안해주세요!