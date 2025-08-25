#!/bin/bash

# run_periodic_claude.sh
# 1시간마다 claude 명령어를 10번 실행하는 스크립트
# 사용법: ./run_periodic_claude.sh

echo "🚀 Starting periodic Claude execution..."
echo "⏰ Will run every hour for 10 iterations"
echo "----------------------------------------"

sleep 7200

# 총 10번 반복 (10시간 동안)
for i in {1..10}
do
    echo "📍 Iteration $i/10 - $(date)"
    
    # claude 명령어 실행
    echo "🤖 Executing: claude -c -p --dangerously-skip-permissions \"continue\""
    claude -c -p --dangerously-skip-permissions "continue"
    
    # 마지막 반복이 아니면 1시간 대기
    if [ $i -lt 10 ]; then
        echo "⏳ Waiting 1 hour until next iteration..."
        echo "Next run: $(date -d '+1 hour')"
        echo "----------------------------------------"
        sleep 3600  # 1시간 = 3600초
    else
        echo "✅ All 10 iterations completed!"
    fi
done

echo "🎉 Script finished at $(date)"
