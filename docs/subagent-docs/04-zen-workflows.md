# Zen Agent (MCP) 프롬프트 예시집

## 기본 정보
- **Agent**: Keystone (senior engineering thought-partner)
- **특징**: 고급 추론, 기술적 의사결정 지원, 협업적 사고
- **강점**: 검증, 실용적 솔루션, 아키텍처 결정, 품질 평가
- **활용 방식**: MCP 채널을 통한 다양한 도구 활용

---

## 🚀 프로덕션 레벨 워크플로우 시나리오

Zen MCP의 진정한 힘은 여러 도구를 하나의 컨텍스트 안에서 유기적으로 연결하여 복잡한 개발 문제를 해결하는 데 있습니다. 다음 시나리오들은 실제 개발 현장에서 마주할 수 있는 문제들을 Zen 워크플로우를 통해 어떻게 해결하는지 보여줍니다.

### 시나리오 1: 신규 기능 개발 (2단계 인증 추가)

**목표**: 사용자 계정 보안 강화를 위해 2단계 인증(2FA) 기능을 안전하고 체계적으로 도입합니다.

**워크플로우:**

**1단계: 기능 구현 계획 수립 (`planner`)**
> 먼저, 2FA 기능 구현에 필요한 모든 작업을 체계적으로 분해하고 계획합니다.

```bash
mcp__zen__planner --step "사용자 2단계 인증(TOTP) 기능 구현을 위한 상세 계획을 수립합니다. 데이터베이스 스키마 변경, 백엔드 API 설계 (enable, verify, disable), 프론트엔드 UI/UX, QR 코드 생성, 복구 코드 시스템, 테스트 전략을 모두 포함해주세요." --step-number 1 --total-steps 8 --next-step-required true --model "o3"
```

**2단계: 계획에 대한 다각적 검토 (`consensus`)**
> 수립된 계획을 바탕으로, 보안(o3)과 사용자 경험(gemini-pro) 관점에서 발생할 수 있는 잠재적 문제를 미리 검토하고 합의를 도출합니다.

```bash
mcp__zen__consensus --step "planner로 수립된 2FA 구현 계획을 검토합니다. 특히 보안 취약점과 사용자 경험 저해 요소를 중심으로 분석해주세요." --step-number 1 --total-steps 2 --next-step-required true --findings "2FA 계획 검토 시작" --models '[{"model": "o3", "stance": "against", "stance_prompt": "보안 관점에서 이 계획의 허점을 비판적으로 검토해줘."}, {"model": "gemini-2.5-pro", "stance": "for", "stance_prompt": "사용자 경험 관점에서 이 계획의 장점을 강조하고 발전시켜줘."}]'
```

**(개발자가 합의된 계획에 따라 코드를 구현합니다.)**

**3단계: 구현된 코드 리뷰 (`codereview`)**
> 개발이 완료된 코드를 대상으로 잠재적인 버그, 보안 허점, 성능 문제를 검토���니다.

```bash
# 주의: codereview 도구는 첫 번째 호출 후 실제 파일을 조사한 뒤 두 번째 호출이 필요합니다
mcp__zen__codereview --step "새롭게 구현된 2FA 관련 코드 전체를 리뷰합니다. 특히 인증 로직의 보안 취약점, 데이터 처리 과정, API 명세 준수 여부를 중점적으로 봐주세요." --step-number 1 --total-steps 5 --next-step-required true --findings "2FA 코드 리뷰 시작" --model "gemini-2.5-pro" --relevant-files ["/src/routes/auth.js", "/src/services/twoFactor.js", "/src/models/user.js"]
```

**4단계: 테스트 케이스 생성 (`testgen`)**
> 코드의 안정성을 보장하기 위해 다양한 엣지 케이스를 포함한 테스트 코드를 자동으로 생성합니다.

```bash
mcp__zen__testgen --step "2FA 기능의 핵심 로직(활성화, 코드 검증, 비활성화)에 대한 단위 및 통합 테스트를 생성합니다. 성공 케이스, 실패 케이스(잘못된 코드, 만료된 코드), 동시성 문제 등을 모두 고려해주세요." --step-number 1 --total-steps 4 --next-step-required true --findings "테스트 케이스 생성 시작" --model "o3" --relevant-files ["/src/services/twoFactor.js"]
```

**5단계: 최종 커밋 전 검증 (`precommit`)**
> 모든 변경사항을 최종적으로 검토하여, 다른 시스템에 미칠 수 있는 부작용은 없는지, 요구사항은 모두 충족되었는지 확인합니다.

```bash
mcp__zen__precommit --step "2FA 기능 추가와 관련된 모든 코드 변경사항을 최종 검증합니다. 회귀 버그 발생 가능성, 문서 업데이트 누락, 환경 변수 설정 문제를 확인해주세요." --step-number 1 --total-steps 3 --next-step-required true --findings "최종 커밋 전 검증 시작" --model "o3" --compare-to "main"
```

---

### 시나리오 2: 원인 불명의 버그 수정 및 리팩토링

**목표**: 프로덕션 환경에서 간헐적으로 발생하는 '주문 처리 누락' 버그의 근본 원인을 찾아 해결하고, 재발 방지를 위해 관련 코드를 리팩토링합니다.

**워크플로우:**

**1단계: 버그 원인 분석 (`debug`)**
> 로그, 코드, 재현 시나리오를 바탕으로 버그의 근본 원인을 체계적으로 추적합니다.

```bash
mcp__zen__debug --step "프로덕션에서 간헐적으로 주문 처리(processOrder)가 실패하는 문제를 분석합니다. 관련 로그 파일을 검토하고, 비동기 처리, 외부 API 의존성, 데이터베이스 트랜잭션 문제를 중심으로 원인을 추적해주세요." --step-number 1 --total-steps 6 --next-step-required true --findings "주문 처리 누락 버그 분석 시작" --hypothesis "외부 결제 API 응답 지연 시, 재시도 로직의 타임아웃 처리 문제��� 추정됨" --model "o3" --relevant-files ["/src/services/orderProcessor.js", "/logs/production.log"]
```

**2단계: 문제 코드의 영향 범위 분석 (`tracer`)**
> 버그의 원인으로 지목된 함수의 호출 관계와 종속성을 추적하여, 수정 시 발생할 수 있는 잠재적 부작용을 파악합니다.

```bash
mcp__zen__tracer --step "버그 원인으로 추정되는 `handlePaymentTimeout` 함수의 모든 호출 경로와, 이 함수가 호출하는 다른 함수들을 추적하여 전체 영향 범위를 파악합니다." --step-number 1 --total-steps 3 --next-step-required true --findings "영향 범위 분석 시작" --target-description "handlePaymentTimeout 함수의 호출 관계 분석" --trace-mode "precision" --model "gemini-2.5-pro"
```

**(개발자가 버그를 수정합니다.)**

**3단계: 재발 방지를 위한 리팩토링 분석 (`refactor`)**
> 버그 수정 후, 관련 코드 영역의 구조적 문제(높은 복잡도, 강한 결합)를 찾아내어 재발 방지를 위한 리팩토링 포인트를 도출합니다.

```bash
mcp__zen__refactor --step "버그가 발생했던 `orderProcessor.js` 파일의 코드 품질이 낮고 복잡도가 높습니다. SRP(단일 책임 원칙)에 따라 클래스를 분리하고, 비동기 로직을 `async/await`로 통일하�� 리팩토링 방안을 제시해주세요." --step-number 1 --total-steps 4 --next-step-required true --findings "리팩토링 분석 시작" --refactor-type "decompose" --model "o3"
```

**4단계: 기술 부채 및 해결 과정 문서화 (`docgen`)**
> 디버깅 과정에서 발견된 함정(gotchas)과 리팩토링 내용을 문서화하여 팀의 지식 자산으로 남깁니다.

```bash
mcp__zen__docgen --step "`orderProcessor` 모듈의 문서를 생성합니다. 특히 이번에 수정한 타임아웃 처리 로직의 주의사항과, 리팩토링으로 개선된 아키텍처를 명확히 설명해주세요." --step-number 1 --total-steps 2 --next-step-required true --findings "문서 생성 시작" --model "gemini-2.5-pro" --num-files-documented 0 --total-files-to-document 1
```

---

### 시나리오 3: 레거시 모듈 현대화

**목표**: 오래된 jQuery 기반의 관리자 페이지를 React 기반의 최신 아키텍처로 안전하게 전환하기 위한 전체 계획을 수립하고 실행합니다.

**워크플로우:**

**1단계: 현황 분석 (`analyze`)**
> 먼저 레거시 모듈의 코드 구조, 파일 간 의존성, 핵심 기능을 파악하여 현대화 작업의 범위와 복잡도를 측정합니다.

```bash
mcp__zen__analyze --step "jQuery로 작성된 레거시 관리자 ��이지의 전체 구조를 분석합니다. 주요 기능, 데이터 흐름, 외부 라이브러리 의존성을 파악하여 마이그레이션의 난이도를 평가해주세요." --step-number 1 --total-steps 5 --next-step-required true --findings "레거시 코드 분석 시작" --analysis-type "architecture" --model "o3" --relevant-files ["/admin/js"]
```

**2단계: 현대화 전략 수립 (`thinkdeep`)**
> 분석 결과를 바탕으로, 전면 재작성(Big Bang), 점진적 개선(Strangler Fig) 등 다양한 현대화 전략의 장단점을 심도 깊게 비교 분석합니다.

```bash
mcp__zen__thinkdeep --step "레거시 관리자 페이지 현대화 전략을 수립합니다. 전면 재작성과 점진적 개선(Strangler Fig 패턴) 방식의 장단점, 리스크, 비용을 비교 분석하여 최적의 접근법을 제안해주세요." --step-number 1 --total-steps 4 --next-step-required true --findings "현대화 전략 수립 시작" --model "gemini-2.5-pro"
```

**3단계: 마이그레이션 상세 계획 수립 (`planner`)**
> 결정된 전략(예: 점진적 개선)에 따라, 마일스톤, 작업 단위, 우선순위를 포함한 구체적인 실행 계획을 수립합니다.

```bash
mcp__zen__planner --step "Strangler Fig 패턴을 사용한 관리자 페이지 마이그레이션의 상세 실�� 계획을 수립합니다. 각 페이지/기능별 전환 우선순위, 레거시-신규 코드 공존 방안, 데이터 동기화 전략을 포함해주세요." --step-number 1 --total-steps 10 --next-step-required true --model "o3"
```

**4단계: 신규 아키텍처 보안 감사 (`secaudit`)**
> 본격적인 개발에 앞서, 새로 설계된 React 기반 아키텍처의 잠재적 보안 위협을 사전에 평가하고 방어 전략을 수립합니다.

```bash
mcp__zen__secaudit --step "새롭게 설계될 React 기반 관리자 페이지 아키텍처의 보안 감사를 수행합니다. CSRF, XSS, 인증/인가, API 통신 보안을 중심으로 검토해주세요." --step-number 1 --total-steps 4 --next-step-required true --findings "신규 아키텍처 보안 감사 시작" --audit-focus "owasp" --threat-level "high" --model "gemini-2.5-pro"
```

---

## 🛠️ 단일 도구 프롬프트 예시

이 섹션에서는 각 Zen 도구를 개별적으로 사용하는 방법을 보여줍니다.

### 1. 기술적 의사결정 및 검증 (chat)

#### 아키텍처 결정 검증
```bash
mcp__zen__chat "마이크로서비스 vs 모놀리식 아키텍처 중 우리 프로젝트에 적합한 선택을 도와주세요. 팀 규모 5명, 초기 스타트업, 빠른 개발 속도가 중요합니다." --model "gemini-2.5-pro"
```

#### 기술 스택 선정 검증
```bash
mcp__zen__chat "React vs Vue.js vs Angular 중 선택을 고민하고 있습니다. 우리 팀의 상황과 요구사항을 고려해 최적의 선택을 도와주세요. 팀원 대부분이 JavaScript 중급자이고, SEO가 중요한 프로젝트입니다." --model "o3"
```

### 2. 복잡한 문제 분석 (thinkdeep)

#### 성능 병목 현상 분석
```bash
mcp__zen__thinkdeep --step "웹 애플리케이션의 응답 시간이 점진적으로 느려지고 있습니다. 가능한 원인들을 체계적으로 분석하고 우선순위별 해결 방안을 제시해주세요." --step-number 1 --total-steps 5 --next-step-required true --findings "초기 조사 시작" --model "o3"
```

#### 확장성 계획 수립
```bash
mcp__zen__thinkdeep --step "현재 10만 사용자에서 100만 사용자로 확장하기 위한 시스템 개선 방안을 체계적으로 분석해주세요." --step-number 1 --total-steps 6 --next-step-required true --findings "확장성 분석 시작" --model "o3"
```

### 3. 다중 관점 합의 도출 (consensus)

#### 개발 방법론 선택
```bash
mcp__zen__consensus --step "애자일 vs 워터폴 vs DevOps 중심 개발 방법론 중 우리 팀에게 최적인 것을 결정하고 싶습니다. 팀 규모 8명, 원격 근무, 빠른 시장 ���시가 중요합니다." --step-number 1 --total-steps 3 --next-step-required true --findings "개발 방법론 비교 분석 시작" --models '[{"model": "o3", "stance": "for"}, {"model": "gemini-2.5-pro", "stance": "neutral"}, {"model": "o4-mini", "stance": "against"}]'
```

### 4. 체계적 계획 수립 (planner)

#### 기술 부채 해결 계획
```bash
mcp__zen__planner --step "누적된 기술 부채를 체계적으로 해결하는 3개월 계획을 수립해주세요. 비즈니스 영향을 최소화하면서 점진적으로 개선하는 전략이 필요합니다." --step-number 1 --total-steps 6 --next-step-required true --model "gemini-2.5-pro"
```

### 5. 전문 분석 및 검토

#### 종합적 코드 분석 (analyze)
```bash
# 주의: analyze 도구는 첫 번째 단계에서 relevant-files 파라미터가 필수입니다
mcp__zen__analyze --step "현재 Node.js 백엔드 프로젝트의 전반적인 상태를 분석해주세요. 아키텍처, 성능, 보안, 유지보수성 모든 측면을 검토해주세요." --step-number 1 --total-steps 4 --next-step-required true --findings "프로젝트 전반 분석 시작" --analysis-type "general" --model "o3" --relevant-files ["/src", "/tests", "/docs"]
```

#### 보안 감사 (secaudit)
```bash
mcp__zen__secaudit --step "웹 애플리케이션의 종합적인 보안 감사를 수행해주세요. 인증, 인가, 데이터 보호, API 보안을 중점적으로 검토해주세요." --step-number 1 --total-steps 5 --next-step-required true --findings "보안 감사 시작" --audit-focus "comprehensive" --threat-level "high" --model "gemini-2.5-pro"
```

#### 리팩토링 분석 (refactor)
```bash
mcp__zen__refactor --step "레거시 JavaScript 코드의 리팩토링 기회를 분석해주세요. 현대적 ES6+ 문법, 모듈화, 테스트 가능성 개선을 중심으로 검토해주세요." --step-number 1 --total-steps 4 --next-step-required true --findings "리팩토링 분석 시작" --refactor-type "modernize" --model "o3"
```

#### 디버깅 지원 (debug)
```bash
mcp__zen__debug --step "프로덕션에서 간헐적으로 발생하는 메모리 누수 문제를 분석해주세요. Node.js 애플리케이션에서 특정 API 호출 후 메모리 사용량이 점진적으로 증가합니다." --step-number 1 --total-steps 5 --next-step-required true --findings "메모리 누수 분석 시작" --hypothesis "API 호출과 관련된 메모리 누수 의심" --model "o3"
```

### 6. 고급 활용 패턴

#### 연속 대화를 통한 심화 분석
```bash
# 1단계: 초기 분석
ZEN_ID=$(mcp__zen__chat "프로젝트 아키텍처를 분석해주세요" --model "o3" | grep continuation_id)

# 2단계: 심화 분석 (이전 대화 이어��)
mcp__zen__chat "방금 분석한 내용을 바탕으로 구체적인 개선 방안을 제시해주세요" --continuation-id "$ZEN_ID" --model "o3"
```

#### 파일 컨텍스트 포함 분석
```bash
# 주의: --files가 아니라 --relevant-files를 사용해야 합니다
mcp__zen__analyze --step "이 핵심 파일들의 구조와 상호작용을 분석해주세요" --step-number 1 --total-steps 3 --next-step-required true --findings "파일 기반 분석 시작" --analysis-type "general" --model "gemini-2.5-pro" --relevant-files ["/src/main.js", "/src/api.js"]
```

---

## ⚠️ 중요한 파라미터 주의사항

### 테스트를 통해 발견된 필수 요구사항

1. **analyze 도구**: 첫 번째 단계에서 `--relevant-files` 파라미터가 필수입니다.
2. **codereview 도구**: 첫 번째 호출 후 실제 파일을 조사한 뒤 두 번째 호출이 필요합니다.
3. **consensus 도구**: `--models` 파라미터는 JSON 배열 형식으로 제공해야 합니다.
4. **모든 워크플로우 도구**: `--step`, `--step-number`, `--total-steps`, `--next-step-required`, `--findings`, `--model` 파라미터가 필수입니다.

### 성공적으로 테스트된 도구들

✅ **chat**: 기본 대화 기능 정상 작동  
✅ **thinkdeep**: 복잡한 문제 분석 정상 작동  
✅ **consensus**: 다중 모델 합의 도출 정상 작동  
✅ **planner**: 체계적 계획 수립 정상 작동  
✅ **codereview**: 코드 리뷰 (2단계 프로세스) 정상 작동  
⚠️ **analyze**: relevant-files 파라미터 필수 (수정됨)

모든 도구가 정상적으로 호출 가능하며, 문서의 파라미터 오류가 수정되었습니다.
