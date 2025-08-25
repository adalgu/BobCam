#!/bin/bash

# run_periodic_claude_phase2.sh
# 2시간 대기 → 5분마다 20회 반복 → 2시간 대기 → 5분마다 20회 반복
# 사용법: ./run_periodic_claude_phase2.sh

echo "🚀 Starting Phase 2 periodic Claude execution..."
echo "📋 Pattern: 2h wait → 20x every 5min → 2h wait → 20x every 5min"
echo "⏰ Total duration: ~7 hours"
echo "----------------------------------------"

# 첫 번째 2시간 대기
echo "⏳ Phase 1: Waiting 2 hours before first execution cycle..."
echo "   Next execution: $(date -d '+2 hours')"
sleep 7200  # 2시간 = 7200초

# 첫 번째 5분마다 20회 반복
echo "🔥 Phase 2: Starting first 20-iteration cycle (every 5 minutes)"
for i in {1..20}
do
    echo "📍 Cycle 1 - Iteration $i/20 - $(date)"
    
    # claude 명령어 실행
    echo "🤖 Executing: claude -c -p --dangerously-skip-permissions \"continue\""
    claude -c -p --dangerously-skip-permissions "continue with utilize subagent"
    
    # 마지막 반복이 아니면 5분 대기
    if [ $i -lt 20 ]; then
        echo "⏳ Waiting 5 minutes until next iteration..."
        echo "Next run: $(date -d '+5 minutes')"
        echo "----------------------------------------"
        sleep 300  # 5분 = 300초
    else
        echo "✅ First 20-iteration cycle completed!"
    fi
done

# 두 번째 2시간 대기
echo "⏳ Phase 3: Waiting 2 hours before second execution cycle..."
echo "   Next execution: $(date -d '+2 hours')"
sleep 7200  # 2시간 = 7200초

# 두 번째 5분마다 20회 반복
echo "🔥 Phase 4: Starting second 20-iteration cycle (every 5 minutes)"
for i in {1..20}
do
    echo "📍 Cycle 2 - Iteration $i/20 - $(date)"
    
    # claude 명령어 실행
    echo "🤖 Executing: claude -c -p --dangerously-skip-permissions \"continue\""
    claude -c -p --dangerously-skip-permissions "continue with utilize subagent"
    
    # 마지막 반복이 아니면 5분 대기
    if [ $i -lt 20 ]; then
        echo "⏳ Waiting 5 minutes until next iteration..."
        echo "Next run: $(date -d '+5 minutes')"
        echo "----------------------------------------"
        sleep 300  # 5분 = 300초
    else
        echo "✅ Second 20-iteration cycle completed!"
    fi
done

echo "🎉 All phases completed at $(date)"
echo "📊 Summary:"
echo "   - Phase 1: 2 hours wait"
echo "   - Phase 2: 20 iterations every 5 minutes (1h 40min)"
echo "   - Phase 3: 2 hours wait"
echo "   - Phase 4: 20 iterations every 5 minutes (1h 40min)"
echo "   - Total: ~7 hours"
