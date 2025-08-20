# Claude CLI 프롬프트 예시집

## 기본 정보
- **Agent**: Claude Code (Anthropic's official CLI assistant)
- **특징**: 소프트웨어 엔지니어링 특화
- **강점**: 코드 분석, 디버깅, 개발 워크플로우, 시스템 설계
- **전문 영역**: 아키텍처, 코드 리뷰, 테스팅, 개발 베스트 프랙티스

## 기본 사용법

```bash
# 기본 프롬프트
claude -p "your prompt here"

# 출력 후 종료 (파이프라인용)
claude -p "your prompt" --print

# JSON 출력 형식
claude -p "your prompt" --print --output-format json

# 권한 모드 설정
claude -p "your prompt" --permission-mode bypassPermissions

# 특정 모델 지정
claude -p "your prompt" --model "claude-sonnet-4-20250514"

# 도구 제한
claude -p "your prompt" --allowedTools "Bash Edit Read"
```

## 카테고리별 프롬프트 예시

### 1. 코드 분석 및 리뷰

#### 코드 품질 분석
```bash
claude -p "다음 Python 코드의 품질을 분석하고 개선점을 제안해주세요. 성능, 가독성, 유지보수성 관점에서 평가해주세요: [코드 첨부]"
```

#### 보안 코드 리뷰
```bash
claude -p "이 웹 애플리케이션 코드에서 보안 취약점을 찾아주세요. OWASP Top 10 기준으로 분석하고 해결 방안을 제시해주세요: [코드 첨부]"
```

#### 성능 최적화 분석
```bash
claude -p "다음 데이터베이스 쿼리의 성능을 분석하고 최적화 방안을 제안해주세요. 인덱스 사용과 쿼리 구조 개선을 포함해주세요: [SQL 쿼리]"
```

#### 코드 스멜 탐지
```bash
claude -p "이 클래스에서 코드 스멜을 찾아 리팩토링 방안을 제안해주세요. SOLID 원칙과 디자인 패턴 적용도 고려해주세요: [클래스 코드]"
```

### 2. 아키텍처 설계 및 시스템 디자인

#### 마이크로서비스 아키텍처 설계
```bash
claude -p "전자상거래 플랫폼을 마이크로서비스 아키텍처로 설계해주세요. 서비스 분해, 데이터 일관성, 통신 패턴을 포함한 상세한 설계를 제공해주세요."
```

#### 데이터베이스 스키마 설계
```bash
claude -p "소셜 미디어 플랫폼의 데이터베이스 스키마를 설계해주세요. 정규화, 인덱스 전략, 확장성을 고려한 설계를 제공해주세요."
```

#### API 설계
```bash
claude -p "RESTful API를 설계해주세요. 리소스 모델링, HTTP 메소드 사용, 버전 관리, 에러 처리 전략을 포함한 완전한 API 명세를 제공해주세요."
```

#### 캐싱 전략 설계
```bash
claude -p "고트래픽 웹 서비스를 위한 다층 캐싱 전략을 설계해주세요. Redis, CDN, 애플리케이션 레벨 캐시를 활용한 종합적인 전략을 제안해주세요."
```

### 3. 개발 워크플로우 및 DevOps

#### CI/CD 파이프라인 설계
```bash
claude -p "Node.js 애플리케이션을 위한 GitHub Actions CI/CD 파이프라인을 설계해주세요. 테스트, 빌드, 배포, 롤백 전략을 포함해주세요."
```

#### Docker 컨테이너화 전략
```bash
claude -p "멀티스테이지 Docker 빌드를 활용한 Python 애플리케이션 컨테이너화 전략을 제안해주세요. 이미지 크기 최적화와 보안을 고려해주세요."
```

#### 모니터링 및 로깅 설계
```bash
claude -p "마이크로서비스 환경을 위한 종합적인 모니터링 및 로깅 전략을 설계해주세요. Prometheus, Grafana, ELK 스택 활용 방안을 포함해주세요."
```

#### 배포 전략 설계
```bash
claude -p "블루-그린 배포와 카나리 배포 전략을 Kubernetes 환경에서 구현하는 방법을 상세히 설명해주세요. 실제 구현 가능한 매니페스트 파일도 포함해주세요."
```

### 4. 테스팅 및 품질 보증

#### 테스트 전략 수립
```bash
claude -p "복잡한 웹 애플리케이션을 위한 종합적인 테스트 전략을 수립해주세요. 단위 테스트, 통합 테스트, E2E 테스트의 범위와 도구 선택을 포함해주세요."
```

#### 테스트 코드 생성
```bash
claude -p "다음 함수에 대한 포괄적인 단위 테스트를 작성해주세요. Edge case와 에러 상황을 모두 포함해주세요: [함수 코드]"
```

#### 성능 테스트 설계
```bash
claude -p "웹 API의 성능 테스트 시나리오를 설계하고 JMeter 또는 K6를 사용한 테스트 스크립트를 작성해주세요. 부하 테스트와 스트레스 테스트를 포함해주세요."
```

#### 테스트 자동화 구축
```bash
claude -p "Selenium과 Playwright를 활용한 E2E 테스트 자동화 프레임워크를 설계해주세요. 페이지 오브젝트 모델과 데이터 드리븐 테스트를 포함해주세요."
```

### 5. 디버깅 및 문제 해결

#### 성능 문제 진단
```bash
claude -p "웹 애플리케이션의 응답 시간이 급격히 느려졌습니다. 체계적인 성능 진단 방법과 도구 사용법을 알려주세요. 프로파일링과 모니터링 접근법을 포함해주세요."
```

#### 메모리 누수 분석
```bash
claude -p "Node.js 애플리케이션에서 메모리 누수가 의심됩니다. 힙 덤프 분석 방법과 메모리 누수를 찾는 체계적인 접근법을 알려주세요."
```

#### 분산 시스템 디버깅
```bash
claude -p "마이크로서비스 환경에서 특정 요청이 실패하고 있습니다. 분산 추적을 활용한 디버깅 방법과 로그 상관관계 분석 기법을 알려주세요."
```

#### 데이터베이스 성능 튜닝
```bash
claude -p "PostgreSQL 데이터베이스에서 특정 쿼리가 느립니다. EXPLAIN ANALYZE 결과를 분석하고 성능 튜닝 방안을 제시해주세요: [쿼리 실행 계획]"
```

### 6. 개발 도구 및 환경 설정

#### 개발 환경 구축
```bash
claude -p "Python 웹 개발을 위한 완전한 개발 환경을 구축해주세요. Poetry, pre-commit hooks, VSCode 설정, Docker 개발 환경을 포함해주세요."
```

#### 코드 품질 도구 설정
```bash
claude -p "JavaScript/TypeScript 프로젝트를 위한 코드 품질 도구 스택을 설정해주세요. ESLint, Prettier, Husky, lint-staged 설정을 포함해주세요."
```

#### 자동화 스크립트 작성
```bash
claude -p "개발 워크플로우를 자동화하는 스크립트를 작성해주세요. 프로젝트 초기화, 의존성 설치, 테스트 실행, 배포를 포함한 Makefile 또는 npm scripts를 만들어주세요."
```

#### IDE 설정 최적화
```bash
claude -p "VSCode를 Full-Stack 개발을 위해 최적화해주세요. 필수 확장 프로그램, 설정 파일, 디버깅 구성, 작업 영역 설정을 포함해주세요."
```

### 7. 코드 생성 및 리팩토링

#### 디자인 패턴 구현
```bash
claude -p "Observer 패턴을 TypeScript로 구현해주세요. 타입 안전성과 실제 사용 예시를 포함한 완전한 구현을 제공해주세요."
```

#### 레거시 코드 리팩토링
```bash
claude -p "다음 레거시 코드를 현대적인 JavaScript ES6+ 문법으로 리팩토링해주세요. 가독성과 유지보수성을 개선하고 테스트 가능한 구조로 변경해주세요: [레거시 코드]"
```

#### API 클라이언트 생성
```bash
claude -p "REST API 명세를 바탕으로 TypeScript HTTP 클라이언트를 생성해주세요. 타입 정의, 에러 처리, 재시도 로직을 포함해주세요: [API 명세]"
```

#### 데이터 변환 유틸리티
```bash
claude -p "복잡한 JSON 데이터 구조를 변환하는 유틸리티 함수를 작성해주세요. 타입 안전성과 에러 처리를 포함해주세요: [입력/출력 데이터 예시]"
```

### 8. 보안 및 컴플라이언스

#### 보안 감사
```bash
claude -p "웹 애플리케이션의 보안 체크리스트를 만들고 현재 코드베이스를 감사해주세요. 인증, 인가, 데이터 보호, 입력 검증을 포함해주세요."
```

#### 보안 코딩 가이드라인
```bash
claude -p "Node.js 애플리케이션을 위한 보안 코딩 가이드라인을 작성해주세요. SQL 인젝션, XSS, CSRF 방어와 보안 헤더 설정을 포함해주세요."
```

#### 암호화 구현
```bash
claude -p "사용자 데이터 암호화를 위한 안전한 구현을 제공해주세요. bcrypt를 사용한 패스워드 해싱과 AES를 사용한 데이터 암호화를 포함해주세요."
```

#### GDPR 컴플라이언스
```bash
claude -p "웹 애플리케이션에서 GDPR 컴플라이언스를 구현하는 방법을 알려주세요. 데이터 처리 동의, 데이터 삭제, 데이터 포터빌리티를 포함해주세요."
```

## 고급 활용 팁

### 1. 파일 기반 분석
```bash
# 현재 프로젝트의 코드를 분석
claude -p "현재 프로젝트의 아키텍처를 분석하고 개선점을 제안해주세요" --all-files

# 특정 디렉토리 추가
claude -p "이 API 코드를 리뷰해주세요" --add-dir ./src/api
```

### 2. 체인된 프롬프팅
```bash
# 1단계: 아키텍처 분석
claude -p "현재 시스템의 아키텍처 문제점을 찾아주세요" > analysis.txt

# 2단계: 개선안 제시 (이전 결과 활용)
claude -p "다음 분석 결과를 바탕으로 구체적인 개선 계획을 수립해주세요: $(cat analysis.txt)"
```

### 3. 권한 모드 활용
```bash
# 자동으로 파일 수정 허용
claude -p "코드 스타일을 일관되게 수정해주세요" --permission-mode bypassPermissions

# 계획 모드 (실행하지 않고 계획만)
claude -p "대규모 리팩토링 계획을 수립해주세요" --permission-mode plan
```

### 4. 도구 제한을 통한 안전한 분석
```bash
# 읽기 전용 분석
claude -p "코드 품질을 분석해주세요" --allowedTools "Read Glob Grep"

# 웹 검색 포함 분석
claude -p "최신 보안 베스트 프랙티스와 비교 분석해주세요" --allowedTools "Read WebSearch"
```

## 출력 형식 활용

### 1. JSON 형식으로 구조화된 분석
```bash
claude -p "코드 메트릭을 JSON 형식으로 분석해주세요" --print --output-format json
```

### 2. 파이프라인 연결
```bash
# Claude 분석 결과를 다른 도구로 전달
claude -p "보안 취약점을 찾아주세요" --print | grep -i "critical"
```

### 3. 스크립트 통합
```bash
#!/bin/bash
# 자동화된 코드 리뷰 스크립트
REVIEW_RESULT=$(claude -p "코드 리뷰를 수행하고 점수를 매겨주세요" --print)
echo "$REVIEW_RESULT" > review-report.md
```

이 예시들을 활용하여 Claude CLI의 강력한 엔지니어링 역량을 프로젝트에 적용해보세요!