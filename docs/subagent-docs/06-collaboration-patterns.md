# Subagent 병렬 워크플로우 전략

## 개요

4개의 subagent CLI (Gemini, Claude, Zen, Codex)를 활용한 효율적인 병렬 작업 전략과 실전 워크플로우를 제시합니다.

## 핵심 원칙

### 1. 역할 기반 분담
각 agent의 강점을 활용한 명확한 역할 분담
- **창조**: Gemini → 아이디어, 콘텐츠, 창의적 해결책
- **검증**: Zen → 기술적 타당성, 품질 평가, 의사결정 지원  
- **구현**: Claude → 아키텍처, 코드 리뷰, 시스템 설계
- **생산**: Codex → 빠른 코딩, 자동화, 프로토타이핑

### 2. 단계적 파이프라인
순차적 또는 병렬적 작업 흐름 설계

### 3. 피드백 루프
각 단계의 결과를 다음 단계에 반영하는 순환 구조

## 전략 패턴별 상세 가이드

### Pattern 1: 순차적 파이프라인 전략

#### 🚀 기본 순차 플로우
```
Gemini (아이디어) → Zen (검증) → Claude (설계) → Codex (구현)
```

**실행 예시:**
```bash
# 1단계: 창의적 아이디어 생성
IDEA=$(gemini -p "개발자 생산성을 높이는 혁신적인 도구 아이디어 5가지 제안")

# 2단계: 기술적 타당성 검증  
VALIDATION=$(mcp__zen__chat "다음 아이디어들의 기술적 타당성과 구현 가능성을 평가해주세요: $IDEA" --model "o3")

# 3단계: 아키텍처 설계
DESIGN=$(claude -p "검증된 아이디어를 바탕으로 시스템 아키텍처를 설계해주세요: $VALIDATION")

# 4단계: 프로토타입 구현
codex exec "다음 설계를 바탕으로 MVP를 구현해주세요: $DESIGN" --model "o4-mini" --full-auto
```

#### 📊 데이터 중심 순차 플로우
```
Claude (분석) → Gemini (인사이트) → Zen (검증) → Codex (자동화)
```

**사용 사례**: 로그 분석 → 패턴 발견 → 해결책 검증 → 자동화 구현

### Pattern 2: 병렬 분산 전략

#### 🌟 관점별 병렬 분석
```bash
# 동일한 문제를 4가지 관점에서 동시 분석
(
  echo "=== Gemini 창의적 관점 ===" > creative_view.md
  gemini -p "창의적 관점에서 [문제] 분석하고 혁신적 해결책 제안" >> creative_view.md
) &

(
  echo "=== Claude 엔지니어링 관점 ===" > engineering_view.md  
  claude -p "엔지니어링 관점에서 [문제] 분석하고 기술적 해결책 제안" >> engineering_view.md
) &

(
  echo "=== Zen 전략적 관점 ===" > strategic_view.md
  mcp__zen__thinkdeep --step "전략적 관점에서 [문제] 분석하고 실용적 해결책 제안" --step-number 1 --total-steps 3 --next-step-required true --findings "전략 분석 시작" --model "o3" >> strategic_view.md
) &

(
  echo "=== Codex 구현 관점 ===" > implementation_view.md
  codex exec "구현 관점에서 [문제] 분석하고 빠른 해결책 제안" --model "o4-mini" >> implementation_view.md
) &

wait

# 결과 통합
echo "## 통합 분석 결과" > integrated_analysis.md
cat creative_view.md engineering_view.md strategic_view.md implementation_view.md >> integrated_analysis.md
```

#### ⚡ 기능별 병렬 개발
```bash
# 여러 기능을 동시에 개발
mkdir -p parallel_dev/{frontend,backend,database,deployment}

# 프론트엔드 개발
(
  cd parallel_dev/frontend
  codex exec "React 컴포넌트 생성: 사용자 대시보드" --model "o4-mini" --full-auto
) &

# 백엔드 API 개발  
(
  cd parallel_dev/backend
  codex exec "Express.js API 엔드포인트 생성: 사용자 관리" --model "o4-mini" --full-auto
) &

# 데이터베이스 스키마
(
  cd parallel_dev/database  
  claude -p "PostgreSQL 스키마 설계: 사용자 및 권한 관리"
) &

# 배포 설정
(
  cd parallel_dev/deployment
  codex exec "Docker와 Kubernetes 배포 설정 생성" --model "o4-mini" --full-auto
) &

wait
```

### Pattern 3: 반복적 개선 전략

#### 🔄 품질 향상 루프
```bash
# 반복적 개선 스크립트
improve_iteratively() {
    local iteration=1
    local max_iterations=5
    
    while [ $iteration -le $max_iterations ]; do
        echo "=== Iteration $iteration ==="
        
        # 1. Codex로 빠른 구현
        codex exec "현재 요구사항에 맞는 코드 구현" --model "o4-mini" --full-auto > "iteration_${iteration}_code.txt"
        
        # 2. Claude로 코드 리뷰
        claude -p "다음 코드를 리뷰하고 개선점 제안: $(cat iteration_${iteration}_code.txt)" > "iteration_${iteration}_review.txt"
        
        # 3. Zen으로 품질 검증
        mcp__zen__codereview --step "코드 품질을 종합적으로 평가하고 다음 개선 방향 제시" --step-number 1 --total-steps 2 --next-step-required true --findings "품질 검증 시작" --model "o3" > "iteration_${iteration}_quality.txt"
        
        # 4. Gemini로 창의적 개선안
        gemini -p "현재 구현을 더 창의적이고 사용자 친화적으로 개선하는 방법 제안: $(cat iteration_${iteration}_quality.txt)" > "iteration_${iteration}_creative.txt"
        
        ((iteration++))
        
        # 만족도 체크 (실제로는 사용자 입력 또는 품질 지표)
        if [ $iteration -gt 3 ]; then
            echo "품질 목표 달성, 개선 루프 종료"
            break
        fi
    done
}
```

#### 📈 점진적 기능 확장
```
기본 MVP → 기능 확장 → 최적화 → 고도화
   ↓           ↓         ↓        ↓
 Codex    → Gemini  → Claude → Zen (검증)
```

### Pattern 4: 전문화 클러스터 전략

#### 🎯 도메인별 전문 팀 구성

**웹 개발 클러스터:**
```bash
# 프론트엔드 전문화
frontend_team() {
    # Gemini: UI/UX 아이디어
    gemini -p "현대적이고 직관적인 대시보드 UI 컨셉 제안" > ui_concept.md
    
    # Codex: React 컴포넌트 구현  
    codex exec "UI 컨셉을 React 컴포넌트로 구현" --model "o4-mini" --full-auto
    
    # Claude: 코드 최적화
    claude -p "React 컴포넌트 성능 최적화 및 베스트 프랙티스 적용"
    
    # Zen: 사용성 검증
    mcp__zen__analyze --step "UI/UX 품질 및 접근성 분석" --analysis-type "quality"
}

# 백엔드 전문화  
backend_team() {
    # Claude: 아키텍처 설계
    claude -p "확장 가능한 마이크로서비스 아키텍처 설계"
    
    # Codex: API 구현
    codex exec "RESTful API 및 데이터베이스 연동 구현" --model "o4-mini" --full-auto
    
    # Zen: 보안 검증
    mcp__zen__secaudit --step "API 보안 취약점 분석" --audit-focus "comprehensive"
    
    # Gemini: 성능 최적화 아이디어
    gemini -p "API 성능을 혁신적으로 개선할 수 있는 방법 제안"
}
```

**데이터 과학 클러스터:**
```bash
# 데이터 분석 파이프라인
data_science_team() {
    # Claude: 데이터 아키텍처
    claude -p "대용량 데이터 처리 파이프라인 설계"
    
    # Codex: 분석 스크립트 생성
    codex exec "Python 데이터 분석 및 시각화 스크립트 구현" --model "o4-mini" --full-auto
    
    # Gemini: 인사이트 발굴
    gemini -p "데이터에서 숨겨진 패턴과 비즈니스 인사이트 발굴"
    
    # Zen: 결과 검증
    mcp__zen__analyze --step "분석 결과의 통계적 유의성 및 비즈니스 적용 가능성 검증"
}
```

### Pattern 5: 실시간 협업 전략

#### 💬 대화형 협업 세션
```bash
# 실시간 문제 해결 세션
collaborative_session() {
    local problem="$1"
    local session_id=$(date +%s)
    
    echo "=== 협업 세션 시작: $problem ===" > "session_${session_id}.log"
    
    # 1. 문제 분석 (Zen)
    echo "--- Zen 분석 ---" >> "session_${session_id}.log"
    mcp__zen__thinkdeep --step "$problem을 체계적으로 분석해주세요" --step-number 1 --total-steps 3 --next-step-required true --findings "문제 분석 시작" --model "o3" >> "session_${session_id}.log"
    
    # 2. 창의적 해결책 (Gemini)
    echo "--- Gemini 창의적 해결책 ---" >> "session_${session_id}.log"  
    gemini -p "다음 문제에 대한 창의적이고 혁신적인 해결책을 제안해주세요: $problem" >> "session_${session_id}.log"
    
    # 3. 기술적 구현 방안 (Claude)
    echo "--- Claude 기술적 구현 ---" >> "session_${session_id}.log"
    claude -p "위 해결책들을 실제로 구현하기 위한 기술적 방안을 설계해주세요: $(tail -20 session_${session_id}.log)" >> "session_${session_id}.log"
    
    # 4. 빠른 프로토타입 (Codex)
    echo "--- Codex 프로토타입 ---" >> "session_${session_id}.log"
    codex exec "위 설계를 바탕으로 실행 가능한 프로토타입을 구현해주세요: $(tail -30 session_${session_id}.log)" --model "o4-mini" --full-auto >> "session_${session_id}.log"
    
    echo "협업 세션 완료: session_${session_id}.log"
}

# 사용 예시
collaborative_session "웹 애플리케이션의 로딩 속도 개선"
```

### Pattern 6: 품질 보증 중심 전략

#### 🔍 다층 품질 검증
```bash
# 품질 검증 파이프라인
quality_assurance_pipeline() {
    local artifact="$1"  # 검증할 대상 (코드, 문서, 설계 등)
    
    # Layer 1: 기본 품질 체크 (Codex)
    echo "=== Layer 1: 기본 품질 체크 ===" 
    codex exec "다음 산출물의 기본적인 품질 문제를 찾아 수정해주세요: $artifact" --model "o4-mini" --full-auto > quality_layer1.txt
    
    # Layer 2: 전문적 리뷰 (Claude)
    echo "=== Layer 2: 전문적 리뷰 ==="
    claude -p "다음 산출물을 전문가 관점에서 심층 리뷰해주세요: $(cat quality_layer1.txt)" > quality_layer2.txt
    
    # Layer 3: 창의적 개선 (Gemini)  
    echo "=== Layer 3: 창의적 개선 ==="
    gemini -p "다음 산출물을 더 혁신적이고 사용자 친화적으로 개선하는 방법을 제안해주세요: $(cat quality_layer2.txt)" > quality_layer3.txt
    
    # Layer 4: 최종 검증 (Zen)
    echo "=== Layer 4: 최종 검증 ==="
    mcp__zen__consensus --step "모든 개선사항을 종합하여 최종 품질을 평가하고 승인 여부를 결정해주세요" --step-number 1 --total-steps 2 --next-step-required true --findings "최종 품질 검증" --models [{"model": "o3", "stance": "neutral"}, {"model": "gemini-2.5-pro", "stance": "neutral"}] > quality_final.txt
    
    echo "품질 검증 완료. 결과: quality_final.txt"
}
```

## 실전 워크플로우 시나리오

### 시나리오 1: 새로운 웹 서비스 개발

```bash
#!/bin/bash
# 웹 서비스 전체 개발 워크플로우

web_service_development() {
    echo "🚀 웹 서비스 개발 시작"
    
    # Phase 1: 기획 및 설계 (병렬)
    echo "📋 Phase 1: 기획 및 설계"
    (
        echo "비즈니스 요구사항 분석 중..."
        gemini -p "혁신적인 온라인 마켓플레이스 서비스 기획안 작성" > business_plan.md
    ) &
    
    (
        echo "기술 아키텍처 설계 중..."  
        claude -p "확장 가능한 온라인 마켓플레이스 시스템 아키텍처 설계" > tech_architecture.md
    ) &
    
    (
        echo "기술적 타당성 검증 중..."
        mcp__zen__analyze --step "온라인 마켓플레이스 기술 스택 분석 및 검증" --step-number 1 --total-steps 3 --next-step-required true --findings "기술 분석 시작" --model "o3" > tech_feasibility.md
    ) &
    
    wait
    echo "✅ Phase 1 완료"
    
    # Phase 2: 핵심 기능 개발 (병렬)
    echo "⚙️ Phase 2: 핵심 기능 개발"
    mkdir -p development/{frontend,backend,database}
    
    (
        cd development/frontend
        codex exec "React 기반 마켓플레이스 프론트엔드 구현" --model "o4-mini" --full-auto
    ) &
    
    (
        cd development/backend
        codex exec "Node.js Express API 서버 구현" --model "o4-mini" --full-auto  
    ) &
    
    (
        cd development/database
        claude -p "PostgreSQL 데이터베이스 스키마 및 마이그레이션 스크립트 작성"
    ) &
    
    wait
    echo "✅ Phase 2 완료"
    
    # Phase 3: 품질 보증 (순차)
    echo "🔍 Phase 3: 품질 보증"
    claude -p "전체 코드베이스 품질 리뷰 및 개선사항 제안" > code_review.md
    mcp__zen__secaudit --step "보안 취약점 종합 분석" --step-number 1 --total-steps 3 --next-step-required true --findings "보안 감사 시작" --model "o3" > security_audit.md
    gemini -p "사용자 경험 개선을 위한 창의적 아이디어 제안" > ux_improvement.md
    
    echo "✅ Phase 3 완료"
    
    # Phase 4: 배포 준비 (병렬)
    echo "🚀 Phase 4: 배포 준비"
    (
        codex exec "Docker 컨테이너 및 Kubernetes 배포 설정" --model "o4-mini" --full-auto
    ) &
    
    (
        codex exec "CI/CD 파이프라인 구성" --model "o4-mini" --full-auto
    ) &
    
    (
        claude -p "모니터링 및 로깅 시스템 설계"
    ) &
    
    wait
    echo "✅ Phase 4 완료"
    
    echo "🎉 웹 서비스 개발 워크플로우 완료!"
}
```

### 시나리오 2: 레거시 시스템 현대화

```bash
#!/bin/bash
# 레거시 시스템 현대화 워크플로우

legacy_modernization() {
    echo "🔧 레거시 시스템 현대화 시작"
    
    # Phase 1: 현황 분석
    echo "📊 현황 분석 단계"
    claude -p "레거시 시스템 아키텍처 분석 및 문제점 도출" > legacy_analysis.md
    mcp__zen__analyze --step "레거시 시스템 기술 부채 및 위험 요소 분석" --analysis-type "architecture" --model "o3" > risk_analysis.md
    
    # Phase 2: 현대화 전략 수립  
    echo "📋 전략 수립 단계"
    mcp__zen__planner --step "레거시 시스템 단계적 현대화 계획 수립" --step-number 1 --total-steps 6 --next-step-required true --model "gemini-2.5-pro" > modernization_plan.md
    
    # Phase 3: 단계별 실행
    echo "⚙️ 실행 단계"
    
    # 3-1: 데이터 마이그레이션
    codex exec "데이터베이스 마이그레이션 스크립트 작성" --model "o4-mini" --full-auto > data_migration.py
    
    # 3-2: API 현대화
    (
        claude -p "RESTful API 설계 및 구현 방안" > api_design.md
        codex exec "모던 API 구현" --model "o4-mini" --full-auto
    ) &
    
    # 3-3: 프론트엔드 현대화
    (
        gemini -p "현대적 사용자 인터페이스 디자인 제안" > ui_design.md
        codex exec "React 기반 프론트엔드 구현" --model "o4-mini" --full-auto  
    ) &
    
    wait
    
    # Phase 4: 품질 검증
    echo "🔍 품질 검증 단계"
    mcp__zen__consensus --step "현대화 결과 종합 평가" --step-number 1 --total-steps 2 --next-step-required true --findings "현대화 품질 평가" --models [{"model": "o3", "stance": "neutral"}, {"model": "gemini-2.5-pro", "stance": "neutral"}] > quality_assessment.md
    
    echo "✅ 레거시 시스템 현대화 완료!"
}
```

## 성능 최적화 및 모니터링

### 1. 병렬 실행 최적화
```bash
# 최적 병렬 실행 수 계산 (CPU 코어 수 기반)
PARALLEL_JOBS=$(nproc)
echo "최적 병렬 작업 수: $PARALLEL_JOBS"

# 작업 풀 관리
manage_job_pool() {
    local max_jobs=$1
    local current_jobs=0
    
    for task in "${tasks[@]}"; do
        if [ $current_jobs -ge $max_jobs ]; then
            wait -n  # 하나의 작업이 완료될 때까지 대기
            ((current_jobs--))
        fi
        
        eval "$task" &
        ((current_jobs++))
    done
    
    wait  # 모든 작업 완료 대기
}
```

### 2. 결과 통합 및 보고
```bash
# 결과 자동 통합 시스템
integrate_results() {
    echo "# 통합 분석 보고서" > final_report.md
    echo "생성 시간: $(date)" >> final_report.md
    echo "" >> final_report.md
    
    # 각 agent 결과 통합
    if [ -f gemini_result.md ]; then
        echo "## 창의적 관점 (Gemini)" >> final_report.md
        cat gemini_result.md >> final_report.md
        echo "" >> final_report.md
    fi
    
    if [ -f claude_result.md ]; then
        echo "## 엔지니어링 관점 (Claude)" >> final_report.md  
        cat claude_result.md >> final_report.md
        echo "" >> final_report.md
    fi
    
    if [ -f zen_result.md ]; then
        echo "## 전략적 검증 (Zen)" >> final_report.md
        cat zen_result.md >> final_report.md
        echo "" >> final_report.md
    fi
    
    if [ -f codex_result.md ]; then
        echo "## 구현 결과 (Codex)" >> final_report.md
        cat codex_result.md >> final_report.md
    fi
    
    echo "📊 통합 보고서 생성 완료: final_report.md"
}
```

### 3. 실시간 진행 상황 모니터링
```bash
# 진행 상황 모니터링 대시보드
monitor_progress() {
    local total_tasks=$1
    local completed=0
    
    while [ $completed -lt $total_tasks ]; do
        clear
        echo "🔄 Subagent 병렬 작업 진행 상황"
        echo "================================"
        echo "전체 작업: $total_tasks"
        echo "완료: $completed"
        echo "진행률: $(( completed * 100 / total_tasks ))%"
        echo ""
        
        # 각 agent 상태 확인
        check_agent_status "Gemini" "gemini_status.txt"
        check_agent_status "Claude" "claude_status.txt"  
        check_agent_status "Zen" "zen_status.txt"
        check_agent_status "Codex" "codex_status.txt"
        
        sleep 5
        completed=$(count_completed_tasks)
    done
    
    echo "✅ 모든 작업 완료!"
}
```

이 전략들을 조합하여 프로젝트 특성과 요구사항에 맞는 최적의 subagent 협업 워크플로우를 구성해보세요!