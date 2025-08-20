# Codex CLI 프롬프트 예시집

## 기본 정보
- **Agent**: ChatGPT (coding assistant)  
- **특징**: OpenAI 기반 코딩 어시스턴트
- **강점**: 빠른 코드 생성, 자동화, 프로토타이핑, 스크립팅
- **모델**: o4-mini (빠르고 효율적), gpt-4o-mini 등

## 기본 사용법

```bash
# 기본 실행 (자동 승인)
codex exec "your prompt here" --model "o4-mini" --full-auto

# 특정 모델 지정
codex exec "your prompt" --model "gpt-4o-mini"

# 읽기 전용 모드 (안전한 분석)
codex exec "your prompt" --model "o4-mini"  # sandbox: read-only

# 쓰기 허용 모드 (파일 수정 가능)
codex exec "your prompt" --model "o4-mini" --full-auto  # sandbox: workspace-write

# 추론 수준 조정
codex exec "your prompt" --model "o4-mini" --reasoning-effort high
```

## 카테고리별 프롬프트 예시

### 1. 빠른 코드 생성

#### 유틸리티 함수 생성
```bash
codex exec "JavaScript에서 배열을 청크 단위로 나누는 함수를 만들어주세요. TypeScript 타입도 포함해주세요." --model "o4-mini" --full-auto
```

#### API 클라이언트 생성
```bash
codex exec "REST API를 호출하는 Python 클라이언트 클래스를 만들어주세요. 에러 처리와 재시도 로직을 포함해주세요." --model "o4-mini" --full-auto
```

#### 데이터 변환 스크립트
```bash
codex exec "CSV 파일을 JSON으로 변환하는 Node.js 스크립트를 작성해주세요. 커맨드라인 인자로 파일 경로를 받도록 해주세요." --model "o4-mini" --full-auto
```

#### 설정 파일 생성기
```bash
codex exec "Webpack 설정 파일을 생성해주세요. React, TypeScript, Hot Reload, 개발/프로덕션 환경 분리를 포함해주세요." --model "o4-mini" --full-auto
```

### 2. 자동화 스크립트

#### 배포 자동화
```bash
codex exec "Docker 컨테이너를 빌드하고 AWS ECR에 푸시하는 자동화 스크립트를 만들어주세요. 버전 태깅과 롤백 기능을 포함해주세요." --model "o4-mini" --full-auto
```

#### 테스트 자동화
```bash
codex exec "Jest를 사용한 자동화된 테스트 실행 스크립트를 만들어주세요. 커버리지 리포트와 슬랙 알림 기능을 포함해주세요." --model "o4-mini" --full-auto
```

#### 데이터베이스 백업 스크립트
```bash
codex exec "PostgreSQL 데이터베이스를 자동으로 백업하고 S3에 업로드하는 Bash 스크립트를 작성해주세요. 로그와 에러 처리를 포함해주세요." --model "o4-mini" --full-auto
```

#### 환경 설정 스크립트
```bash
codex exec "새로운 개발자를 위한 개발 환경 설정 스크립트를 만들어주세요. Node.js, Docker, Git, VSCode 확장 프로그램을 자동 설치하도록 해주세요." --model "o4-mini" --full-auto
```

### 3. 프로토타이핑 및 MVP

#### 간단한 웹 서버
```bash
codex exec "Express.js를 사용한 간단한 REST API 서버를 만들어주세요. CRUD 기능과 미들웨어(인증, 로깅, CORS)를 포함해주세요." --model "o4-mini" --full-auto
```

#### 실시간 채팅 앱
```bash
codex exec "Socket.io를 사용한 실시간 채팅 애플리케이션을 만들어주세요. 프론트엔드(HTML/JS)와 백엔드(Node.js) 모두 포함해주세요." --model "o4-mini" --full-auto
```

#### 데이터 시각화 대시보드
```bash
codex exec "Chart.js를 사용한 데이터 시각화 대시보드를 만들어주세요. 실시간 데이터 업데이트와 반응형 디자인을 포함해주세요." --model "o4-mini" --full-auto
```

#### 파일 업로드 서비스
```bash
codex exec "Multer를 사용한 파일 업로드 서비스를 만들어주세요. 이미지 리사이징, 파일 타입 검증, 프로그레스 바를 포함해주세요." --model "o4-mini" --full-auto
```

### 4. 데이터 처리 및 분석

#### 로그 분석 도구
```bash
codex exec "서버 로그 파일을 분석하는 Python 스크립트를 만들어주세요. 에러 패턴 감지, 통계 생성, 결과를 CSV로 출력하는 기능을 포함해주세요." --model "o4-mini" --full-auto
```

#### API 모니터링 도구
```bash
codex exec "여러 API 엔드포인트의 상태를 모니터링하는 Node.js 스크립트를 만들어주세요. 응답 시간 측정, 알림 기능, 대시보드를 포함해주세요." --model "o4-mini" --full-auto
```

#### 데이터 마이그레이션 스크립트
```bash
codex exec "MySQL에서 PostgreSQL로 데이터를 마이그레이션하는 스크립트를 만들어주세요. 데이터 검증, 진행률 표시, 롤백 기능을 포함해주세요." --model "o4-mini" --full-auto
```

#### 성능 테스트 도구
```bash
codex exec "웹 서버의 성능을 테스트하는 스크립트를 만들어주세요. 동시 요청 처리, 응답 시간 분석, HTML 리포트 생성을 포함해주세요." --model "o4-mini" --full-auto
```

### 5. 개발 도구 및 유틸리티

#### 코드 생성기
```bash
codex exec "React 컴포넌트를 자동 생성하는 CLI 도구를 만들어주세요. 컴포넌트 이름, Props 타입, 스타일 파일을 자동으로 생성하도록 해주세요." --model "o4-mini" --full-auto
```

#### 문서 생성기
```bash
codex exec "TypeScript 코드에서 자동으로 API 문서를 생성하는 도구를 만들어주세요. JSDoc 주석을 파싱하여 Markdown 문서를 생성하도록 해주세요." --model "o4-mini" --full-auto
```

#### 의존성 관리 도구
```bash
codex exec "package.json의 의존성을 분석하고 업데이트 가능한 패키지를 찾는 도구를 만들어주세요. 보안 취약점 체크와 업데이트 시뮬레이션을 포함해주세요." --model "o4-mini" --full-auto
```

#### 환경 변수 관리 도구
```bash
codex exec "여러 환경의 환경 변수를 관리하는 CLI 도구를 만들어주세요. 암호화, 동기화, 검증 기능을 포함해주세요." --model "o4-mini" --full-auto
```

### 6. 테스트 및 품질 보증

#### 단위 테스트 생성
```bash
codex exec "다음 JavaScript 함수에 대한 포괄적인 Jest 테스트를 작성해주세요. Edge case와 에러 상황을 모두 포함해주세요: [함수 코드 첨부]" --model "o4-mini" --full-auto
```

#### E2E 테스트 자동화
```bash
codex exec "Playwright를 사용한 E2E 테스트 스위트를 만들어주세요. 로그인, 폼 제출, 페이지 네비게이션을 테스트하도록 해주세요." --model "o4-mini" --full-auto
```

#### 코드 품질 체크 도구
```bash
codex exec "ESLint와 Prettier를 사용한 코드 품질 체크 스크립트를 만들어주세요. 자동 수정과 리포트 생성 기능을 포함해주세요." --model "o4-mini" --full-auto
```

#### 성능 벤치마크 도구
```bash
codex exec "JavaScript 함수의 성능을 벤치마크하는 도구를 만들어주세요. 실행 시간, 메모리 사용량, 비교 차트를 생성하도록 해주세요." --model "o4-mini" --full-auto
```

### 7. 배포 및 DevOps

#### Docker 컨테이너 설정
```bash
codex exec "Node.js 애플리케이션을 위한 최적화된 Dockerfile을 만들어주세요. 멀티스테이지 빌드, 보안 설정, 헬스체크를 포함해주세요." --model "o4-mini" --full-auto
```

#### Kubernetes 매니페스트
```bash
codex exec "웹 애플리케이션을 위한 Kubernetes 매니페스트를 만들어주세요. Deployment, Service, ConfigMap, Ingress를 포함해주세요." --model "o4-mini" --full-auto
```

#### CI/CD 파이프라인
```bash
codex exec "GitHub Actions를 사용한 CI/CD 파이프라인을 만들어주세요. 테스트, 빌드, 배포, 알림을 포함한 완전한 워크플로우를 작성해주세요." --model "o4-mini" --full-auto
```

#### 인프라 모니터링
```bash
codex exec "서버 리소스를 모니터링하는 스크립트를 만들어주세요. CPU, 메모리, 디스크 사용량을 체크하고 임계값 초과 시 알림을 보내도록 해주세요." --model "o4-mini" --full-auto
```

### 8. 특수 목적 도구

#### 웹 스크래핑 도구
```bash
codex exec "Puppeteer를 사용한 웹 스크래핑 도구를 만들어주세요. 동적 콘텐츠 로딩, 데이터 추출, CSV 저장 기능을 포함해주세요." --model "o4-mini" --full-auto
```

#### 이메일 발송 시스템
```bash
codex exec "Nodemailer를 사용한 이메일 발송 시스템을 만들어주세요. 템플릿 엔진, 첨부파일, 대량 발송, 발송 상태 추적을 포함해주세요." --model "o4-mini" --full-auto
```

#### 파일 동기화 도구
```bash
codex exec "로컬과 원격 서버 간 파일을 동기화하는 도구를 만들어주세요. rsync 기반으로 차분 업로드, 충돌 해결, 로그 기능을 포함해주세요." --model "o4-mini" --full-auto
```

#### QR 코드 생성기
```bash
codex exec "QR 코드를 생성하는 웹 서비스를 만들어주세요. 다양한 크기, 색상 커스터마이징, 벌크 생성 기능을 포함해주세요." --model "o4-mini" --full-auto
```

## 고급 활용 팁

### 1. 컨텍스트 관리
```bash
# 현재 프로젝트 구조를 포함하여 코드 생성
codex exec "현재 프로젝트 구조를 분석하고 적절한 위치에 새로운 API 엔드포인트를 추가해주세요" --model "o4-mini" --full-auto
```

### 2. 반복적 개선
```bash
# 1단계: 기본 구현
codex exec "간단한 TODO 앱을 만들어주세요" --model "o4-mini" --full-auto

# 2단계: 기능 추가 (이전 결과 기반)
codex exec "방금 만든 TODO 앱에 카테고리 기능을 추가해주세요" --model "o4-mini" --full-auto
```

### 3. 추론 수준 조정
```bash
# 간단한 작업: 기본 추론
codex exec "Hello World를 출력하는 함수" --model "o4-mini"

# 복잡한 작업: 높은 추론
codex exec "분산 시스템의 일관성을 보장하는 알고리즘 구현" --model "o4-mini" --reasoning-effort high
```

### 4. 병렬 처리를 위한 배치 실행
```bash
# 여러 유틸리티를 동시에 생성
(codex exec "유틸리티 함수 A 생성" --model "o4-mini" --full-auto) &
(codex exec "유틸리티 함수 B 생성" --model "o4-mini" --full-auto) &
(codex exec "유틸리티 함수 C 생성" --model "o4-mini" --full-auto) &
wait
```

## 다른 Agent와의 협업 패턴

### 1. Codex 생성 → Claude 검토
```bash
# Codex로 빠른 프로토타입 생성
codex exec "결제 처리 API 구현" --model "o4-mini" --full-auto

# Claude로 코드 품질 검토
claude -p "방금 생성된 결제 API 코드를 검토하고 보안과 에러 처리를 개선해주세요"
```

### 2. Zen 계획 → Codex 구현
```bash
# Zen으로 구현 계획 수립
mcp__zen__planner --step "REST API 구현 계획 수립"

# Codex로 빠른 구현
codex exec "위 계획에 따라 REST API를 구현해주세요" --model "o4-mini" --full-auto
```

### 3. Gemini 아이디어 → Codex 프로토타입
```bash
# Gemini로 창의적 아이디어
gemini -p "혁신적인 개발 도구 아이디어 제안"

# Codex로 빠른 프로토타입
codex exec "위 아이디어를 간단한 프로토타입으로 구현해주세요" --model "o4-mini" --full-auto
```

## 성능 최적화 팁

### 1. 모델 선택
- **o4-mini**: 대부분의 코딩 작업에 최적
- **gpt-4o-mini**: 더 복잡한 추론이 필요한 경우

### 2. 프롬프트 최적화
```bash
# 명확하고 구체적인 요구사항
codex exec "Express.js에서 JWT 인증 미들웨어를 만들어주세요. 토큰 검증, 에러 처리, TypeScript 타입 포함" --model "o4-mini" --full-auto

# 불명확한 요구사항 (비권장)
codex exec "인증 기능 만들어주세요" --model "o4-mini" --full-auto
```

### 3. 컨텍스트 활용
```bash
# 현재 프로젝트의 코딩 스타일을 반영
codex exec "현재 프로젝트의 코딩 스타일과 일치하는 새로운 유틸리티 함수를 추가해주세요" --model "o4-mini" --full-auto
```

Codex CLI를 활용하여 빠르고 효율적인 코드 생성과 자동화를 구현해보세요!