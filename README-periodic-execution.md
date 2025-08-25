# Periodic Claude Execution Script

## 개요
이 스크립트는 1시간마다 `claude -c -p --dangerously-skip-permissions "continue and report to user with slack hook"` 명령어를 10번 실행하는 자동화 스크립트입니다.

## 파일 구성
- `run_periodic_claude.sh`: 메인 실행 스크립트
- `README-periodic-execution.md`: 사용 설명서

## 사용 방법

### 1. 기본 실행
```bash
./run_periodic_claude.sh
```

### 2. 백그라운드에서 실행
```bash
nohup ./run_periodic_claude.sh > claude_execution.log 2>&1 &
```

### 3. screen/tmux 사용
```bash
# screen 사용
screen -S claude-runner
./run_periodic_claude.sh

# tmux 사용
tmux new -s claude-runner
./run_periodic_claude.sh
```

## 스크립트 동작
1. 총 10번 반복 실행 (10시간 동안)
2. 매 반복마다 현재 시간 표시
3. claude 명령어 실행
4. 1시간 대기 (3600초)
5. 모든 반복 완료 후 종료

## 모니터링
실행 중인 스크립트 확인:
```bash
ps aux | grep run_periodic_claude.sh
```

로그 확인:
```bash
# 실시간 로그
tail -f claude_execution.log

# 전체 로그
cat claude_execution.log
```

## 중단 방법
```bash
# 프로세스 찾기
ps aux | grep run_periodic_claude.sh

# 프로세스 종료
kill [PID]
```

## 주의사항
- 스크립트 실행 중 터미널을 닫지 마세요
- 백그라운드 실행 시 `nohup` 또는 `screen`/`tmux` 사용 권장
- 시스템 절전 모드 설정 확인 (절전 모드 진입 시 sleep 중단될 수 있음)
