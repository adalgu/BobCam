#!/bin/bash

# run_claude_agent_cycle.sh
# 실행자-계획자 사이클 자동화 스크립트
# 실행자: TODO.md 읽고 작업 수행 → REPORT.md 업데이트
# 계획자: REPORT.md 읽고 DoD Review → TODO.md 업데이트

# 설정
CYCLE_DIR="agent_cycle"
ARCHIVE_DIR="$CYCLE_DIR/archive"
TODO_FILE="$CYCLE_DIR/TODO.md"
REPORT_FILE="$CYCLE_DIR/REPORT.md"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 디렉토리 생성
mkdir -p "$ARCHIVE_DIR"

# 초기화 함수
init_cycle() {
    echo "🔄 Initializing Agent Cycle..."
    
    # 초기 TODO.md 생성 (없으면)
    if [ ! -f "$TODO_FILE" ]; then
        cat > "$TODO_FILE" << 'EOF'
# TODO.md - Agent Task List

## Current Sprint
- [ ] Initialize project structure
- [ ] Set up development environment
- [ ] Create basic documentation

## Backlog
- [ ] Implement core features
- [ ] Add testing framework
- [ ] Performance optimization

## Definition of Done (DoD)
- [ ] Code compiles without errors
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Code review completed
- [ ] Performance benchmarks met
EOF
    fi
    
    # 초기 REPORT.md 생성 (없으면)
    if [ ! -f "$REPORT_FILE" ]; then
        cat > "$REPORT_FILE" << 'EOF'
# REPORT.md - Agent Execution Report

## Last Execution
- **Date**: $(date)
- **Agent**: Initial Setup
- **Status**: Cycle initialized

## Completed Tasks
- [x] Cycle initialization

## Issues Encountered
- None

## Next Steps
- Ready for first execution cycle
EOF
    fi
}

# 아카이브 함수
archive_report() {
    if [ -f "$REPORT_FILE" ]; then
        ARCHIVE_NAME="REPORT_${TIMESTAMP}.md"
        cp "$REPORT_FILE" "$ARCHIVE_DIR/$ARCHIVE_NAME"
        echo "📁 Archived previous report: $ARCHIVE_NAME"
    fi
}

# 실행자 함수
executor() {
    echo "🤖 Starting Executor Phase..."
    
    # 현재 TODO.md 읽기
    echo "📋 Reading TODO.md..."
    cat "$TODO_FILE"
    
    # 실행 프롬프트 생성
    cat > "$CYCLE_DIR/executor_prompt.txt" << EOF
You are the Executor Agent. Your task is to:
1. Read TODO.md carefully
2. Execute the highest priority task
3. Update REPORT.md with your findings
4. Mark completed tasks in TODO.md

Current TODO:
$(cat "$TODO_FILE")

Previous Report:
$(cat "$REPORT_FILE")

Please:
- Focus on ONE task at a time
- Provide detailed execution steps
- Include any issues encountered
- Update task status in TODO.md
- Write comprehensive report in REPORT.md

Execute the next highest priority task now.
EOF

    # Claude 실행
    echo "🤖 Executing Claude as Executor..."
    claude -c -p --dangerously-skip-permissions "Execute as Executor Agent. Read $TODO_FILE and follow instructions in $CYCLE_DIR/executor_prompt.txt"
    
    echo "✅ Executor phase completed"
}

# 계획자 함수
planner() {
    echo "🧠 Starting Planner Phase..."
    
    # 최신 REPORT.md 읽기
    echo "📊 Reading latest REPORT.md..."
    cat "$REPORT_FILE"
    
    # 계획 프롬프트 생성
    cat > "$CYCLE_DIR/planner_prompt.txt" << EOF
You are the Planner Agent. Your task is to:
1. Review the latest REPORT.md
2. Perform DoD (Definition of Done) Review
3. Update TODO.md based on findings
4. Plan next tasks

Latest Report:
$(cat "$REPORT_FILE")

Current TODO:
$(cat "$TODO_FILE")

Please:
- Review if DoD criteria are met
- Update task statuses based on report
- Add new tasks if needed
- Prioritize remaining tasks
- Ensure TODO.md is actionable

Update TODO.md and prepare for next executor cycle.
EOF

    # Claude 실행
    echo "🧠 Executing Claude as Planner..."
    claude -c -p --dangerously-skip-permissions "Execute as Planner Agent. Read $REPORT_FILE and follow instructions in $CYCLE_DIR/planner_prompt.txt"
    
    echo "✅ Planner phase completed"
}

# 메인 실행
main() {
    echo "🚀 Starting Claude Agent Cycle..."
    echo "📋 Pattern: Executor → Planner → Archive → Repeat"
    
    # 초기화
    init_cycle
    
    # 사이클 실행
    while true; do
        echo "----------------------------------------"
        echo "🔄 Starting new cycle at $(date)"
        
        # 이전 REPORT 아카이브
        archive_report
        
        # 실행자 실행
        executor
        
        # 잠시 대기
        echo "⏳ Waiting 30 seconds before planner phase..."
        sleep 30
        
        # 계획자 실행
        planner
        
        echo "✅ Cycle completed at $(date)"
        echo "⏳ Waiting 5 minutes before next cycle..."
        echo "----------------------------------------"
        sleep 300  # 5분 대기
        
    done
}

# 스크립트 시작
main
