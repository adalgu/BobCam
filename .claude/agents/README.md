# Claude Code Subagents Collection

이 폴더는 Claude Code의 50개 전문 서브에이전트들을 분야별로 정리한 컬렉션입니다.

## 📁 분야별 서브에이전트

### 🏗️ [Development & Architecture](./development-architecture/)

**6개 서브에이전트**

- 백엔드/프론트엔드 아키텍처 설계
- UI/UX 디자인
- 모바일 앱 개발
- GraphQL 아키텍처
- 아키텍처 리뷰

### 💻 [Language Specialists](./language-specialists/)

**11개 서브에이전트**

- Python, JavaScript, TypeScript, Java, Go, Rust, C/C++, PHP
- SQL 전문가
- iOS 개발

### 🛠️ [Infrastructure & Operations](./infrastructure-operations/)

**9개 서브에이전트**

- DevOps 및 배포
- 클라우드 아키텍처
- 데이터베이스 관리
- 네트워크 엔지니어링
- 개발자 경험 최적화

### 🔍 [Quality & Security](./quality-security/)

**7개 서브에이전트**

- 코드 리뷰 및 테스트 자동화
- 보안 감사
- 디버깅 및 오류 분석
- 성능 최적화
- 웹 리서치

### 🤖 [Data & AI](./data-ai/)

**6개 서브에이전트**

- 데이터 과학 및 엔지니어링
- AI/ML 엔지니어링
- MLOps
- 프롬프트 엔지니어링

### 💼 [Business & Marketing](./business-marketing/)

**5개 서브에이전트**

- 비즈니스 분석
- 콘텐츠 마케팅
- 영업 자동화
- 고객 지원
- 법무 자문

### 🎯 [Specialized Domains](./specialized-domains/)

**6개 서브에이전트**

- API 문서화
- 결제 시스템 통합
- 금융 분석 및 리스크 관리
- 레거시 현대화
- 컨텍스트 관리

## 🎯 모델별 분류

### 🚀 Haiku (Fast & Cost-Effective) - 8 agents

- `data-scientist` - SQL queries and data analysis
- `api-documenter` - OpenAPI/Swagger documentation
- `business-analyst` - Metrics and KPI tracking
- `content-marketer` - Blog posts and social media
- `customer-support` - Support tickets and FAQs
- `sales-automator` - Cold emails and proposals
- `search-specialist` - Web research and information gathering
- `legal-advisor` - Privacy policies and compliance documents

### ⚡ Sonnet (Balanced Performance) - 31 agents

- 언어별 전문가들 (python-pro, javascript-pro, typescript-pro, golang-pro, rust-pro, c-pro, cpp-pro, php-pro, java-pro, ios-developer, sql-pro)
- 개발 및 아키텍처 (frontend-developer, backend-architect, ui-ux-designer, mobile-developer, graphql-architect)
- 인프라 및 운영 (devops-troubleshooter, deployment-engineer, database-optimizer, database-admin, terraform-specialist, network-engineer, dx-optimizer)
- 품질 및 보안 (test-automator, code-reviewer, debugger, error-detective, performance-engineer)
- 데이터 및 AI (data-engineer, ml-engineer, legacy-modernizer, payment-integration)

### 🧠 Opus (Maximum Capability) - 11 agents

- `ai-engineer` - LLM applications and RAG systems
- `security-auditor` - Vulnerability analysis
- `incident-responder` - Production incident handling
- `mlops-engineer` - ML infrastructure
- `architect-reviewer` - Architectural consistency
- `cloud-architect` - Cloud infrastructure design
- `prompt-engineer` - LLM prompt optimization
- `context-manager` - Multi-agent coordination
- `quant-analyst` - Financial modeling
- `risk-manager` - Portfolio risk management

## 🚀 사용 방법

### 자동 위임

Claude Code가 작업 내용을 분석하여 적절한 서브에이전트를 자동으로 선택합니다.

### 명시적 호출

특정 서브에이전트를 직접 호출할 수 있습니다:

```bash
"backend-architect를 사용해서 사용자 인증 API를 설계해주세요"
"code-reviewer를 사용해서 최근 변경사항을 검토해주세요"
"security-auditor를 사용해서 보안 취약점을 스캔해주세요"
```

### 멀티 에이전트 협업

복잡한 작업에서는 여러 서브에이전트가 협업합니다:

```bash
"사용자 인증 시스템을 구현하고 보안 검사를 진행해주세요"
# → backend-architect → frontend-developer → security-auditor → test-automator
```

## 📚 관련 문서

- **[메인 README.md](../README.md)** - 전체 프로젝트 개요
- **[전략 문서](../docs/subagent-strategy/)** - 서브에이전트 활용 전략
- **[Build with Claude Code-Subagents.md](../Build with Claude Code-Subagents.md)** - 공식 문서

## 📝 라이센스

이 프로젝트는 MIT 라이센스 하에 배포됩니다.
