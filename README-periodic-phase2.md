# Periodic Claude Execution Script - Phase 2

## 개요
이 스크립트는 2시간 대기 → 5분마다 20회 반복 → 2시간 대기 → 5분마다 20회 반복 패턴으로 Claude 명령어를 실행합니다.

## 파일 구성
- `run_periodic_claude_phase2.sh`: Phase 2 실행 스크립트
- `README-periodic-phase2.md`: Phase 2 사용 설명서

## 실행 패턴
```
Phase 1: 2시간 대기
Phase 2: 5분마다 20회 반복 (1시간 40분)
Phase 3: 2시간 대기
Phase 4: 5분마다 20회 반복 (1시간 40분)
총 소요 시간: 약 7시간
```

## 사용 방법

### 1. 기본 실행
```bash
./run_periodic_claude_phase2.sh
```

### 2. 백그라운드에서 실행
```bash
nohup ./run_periodic_claude_phase2.sh > claude_phase2.log 2>&1 &
```

### 3. screen/tmux 사용
```bash
# screen 사용
screen -S claude-phase2
./run_periodic_claude_phase2.sh

# tmux 사용
tmux new -s claude-phase2
./run_periodic_claude_phase2.sh
```

## 모니터링
실행 중인 스크립트 확인:
```bash
ps aux | grep run_periodic_claude_phase2.sh
```

로그 확인:
```bash
# 실시간 로그
tail -f claude_phase2.log

# 전체 로그
cat claude_phase2.log
```

## 중단 방법
```bash
# 프로세스 찾기
ps aux | grep run_periodic_claude_phase2.sh

# 프로세스 종료
kill [PID]

# 강제 종료 (필요시)
kill -9 [PID]
```

## 예상 실행 시간표
시작 시간 기준:
- 0:00 - 스크립트 시작
- 2:00 - 첫 번째 20회 반복 시작
- 3:40 - 첫 번째 반복 완료, 2시간 대기
- 5:40 - 두 번째 20회 반복 시작
- 7:20 - 모든 작업 완료

## 주의사항
- 긴 대기 시간이 있으므로 백그라운드 실행 권장
- 시스템 절전 모드 설정 확인
- 충분한 배터리 또는 전원 연결 권장
- 로그 파일을 통해 진행 상황 확인 가능
