# 명령어 레퍼런스

이 문서는 Claude Projects AI 협력 개발 시스템에서 사용하는 명령어들에 대한 상세한 가이드입니다.

## 🎯 명령어 시스템 개요

명령어를 입력하면 해당 모드의 세부 프롬프트가 자동으로 활성화됩니다.
명령어는 `/`로 시작하며, 옵션 파라미터를 추가할 수 있습니다.

### 기본 문법

```
/[명령어] [옵션] [파라미터]
```

---

## 📋 명령어 목록

### `/roadmap` - 프로젝트 로드맵 관리

프로젝트의 진행 상황을 체계적으로 관리하는 로드맵 문서를 생성하고 업데이트합니다.

#### 사용법

```bash
/roadmap [옵션] [파라미터]
```

#### 옵션

- **`/roadmap init`** - 새 프로젝트 로드맵 생성

  - 새로운 프로젝트를 시작할 때 사용
  - 프로젝트 구조와 주요 페이즈를 설정
  - 예시: `/roadmap init`

- **`/roadmap update`** - 현재 진행 상황 업데이트

  - 작업 완료 상태를 반영
  - 새로운 태스크 추가 또는 수정
  - 예시: `/roadmap update`

- **`/roadmap status`** - 전체 진행률 확인

  - 현재 진행률과 다음 우선순위 확인
  - 간단한 상태 보고서 생성
  - 예시: `/roadmap status`

- **`/roadmap add [태스크명]`** - 새 태스크 추가
  - 특정 태스크를 로드맵에 추가
  - 예시: `/roadmap add "사용자 인증 구현"`

#### 출력 파일

- `project_roadmap.md` - 메인 로드맵 파일
  - 진행률, 페이즈별 태스크, 마일스톤 등 포함
  - 변경로그는 별도 파일로 분리 관리
- `change_log.md` - 변경 히스토리 전용 파일
  - 모든 업데이트 내역 및 결정사항 기록
  - 진행률 변화 추이 및 타임라인 관리

---

### `/handoff` - 핸드오프 프롬프트 생성

현재 개발 세션의 컨텍스트를 다음 세션으로 전달하기 위한 핸드오프 프롬프트를 생성합니다.

#### 사용법

```bash
/handoff [타입] [사유]
```

#### 옵션

- **`/handoff auto`** - 자동 핸드오프 프롬프트 생성

  - 현재 세션의 모든 컨텍스트를 자동으로 수집
  - 진행 중인 작업과 다음 우선순위를 분석
  - 예시: `/handoff auto`

- **`/handoff manual [사유]`** - 수동 핸드오프 (사유 포함)

  - 사용자가 지정한 특정 사유로 핸드오프
  - 특별한 주의사항이나 맥락을 추가
  - 예시: `/handoff manual "API 키 이슈로 임시 중단"`

- **`/handoff quick`** - 빠른 핸드오프 (최소 정보)
  - 간단한 핸드오프 프롬프트 생성
  - 긴급하게 세션을 전환해야 할 때 사용
  - 예시: `/handoff quick`

#### 출력 파일

- `.handoff_prompts/handoff_YYYYMMDD_HHMMSS.md`
- 완전한 컨텍스트와 다음 세션 지침 포함

---

### `/review` - 코드 리뷰

CollaboraChat 프로젝트의 코드 품질 기준에 맞춰 체계적인 리뷰를 수행합니다.

#### 사용법

```bash
/review [범위] [파일명/모듈명]
```

#### 옵션

- **`/review file [파일명]`** - 특정 파일 리뷰

  - 단일 파일에 대한 상세 리뷰
  - 예시: `/review file app.py`
  - 예시: `/review file components/chat.py`

- **`/review module [모듈명]`** - 모듈 단위 리뷰

  - 관련된 여러 파일을 포함한 모듈 리뷰
  - 예시: `/review module auth`
  - 예시: `/review module ui`

- **`/review all`** - 전체 코드베이스 리뷰

  - 프로젝트 전체에 대한 종합적인 리뷰
  - 아키텍처 레벨의 검토 포함
  - 예시: `/review all`

- **`/review recent`** - 최근 변경사항 리뷰

  - 마지막 커밋 이후 변경된 코드만 리뷰
  - 예시: `/review recent`

- **`/review security`** - 보안 중심 리뷰
  - 보안 취약점에 집중한 리뷰
  - API 키, 인증, 데이터 보호 등
  - 예시: `/review security`

#### 리뷰 우선순위 옵션

```bash
/review [범위] --priority=[보안|성능|유지보수성|사용성]
```

- 예시: `/review file app.py --priority=보안`

---

### `/design` - 기능 설계

새로운 기능의 완전한 설계와 구현 계획을 수립합니다.

#### 사용법

```bash
/design [기능명] [옵션]
```

#### 기본 사용

- **`/design [기능명]`** - 새 기능 설계
  - 완전한 기능 설계 문서 생성
  - 예시: `/design "실시간 채팅 기능"`
  - 예시: `/design "사용자 프로필 관리"`

#### 고급 옵션

- **`/design [기능명] --quick`** - 간단한 설계

  - 빠른 프로토타입을 위한 최소 설계
  - 예시: `/design "로그인 기능" --quick`

- **`/design [기능명] --detailed`** - 상세한 설계

  - 모든 세부사항을 포함한 완전한 설계
  - 예시: `/design "결제 시스템" --detailed`

- **`/design [기능명] --api`** - API 중심 설계
  - API 인터페이스에 집중한 설계
  - 예시: `/design "검색 기능" --api`

#### 설계 범위 옵션

- **`--frontend`** - 프론트엔드 중심 설계
- **`--backend`** - 백엔드 중심 설계
- **`--fullstack`** - 풀스택 설계 (기본값)

---

### `/status` - 현재 상황 확인

프로젝트의 현재 상태를 빠르게 파악하고 다음 액션을 결정합니다.

#### 사용법

```bash
/status [옵션]
```

#### 옵션

- **`/status`** - 기본 상태 확인

  - 전체 진행률과 우선순위 태스크
  - 예시: `/status`

- **`/status detailed`** - 상세한 상태 보고서

  - 모든 페이즈별 상세 정보 포함
  - 예시: `/status detailed`

- **`/status quick`** - 빠른 상태 확인

  - 핵심 정보만 간단히 표시
  - 예시: `/status quick`

- **`/status timeline`** - 타임라인 기반 상태
  - 시간순으로 진행 상황 표시
  - 예시: `/status timeline`

---

## 🔧 고급 사용법

### 명령어 조합

여러 명령어를 순차적으로 실행할 수 있습니다:

```bash
/status quick && /roadmap update && /handoff auto
```

### 조건부 명령어

특정 조건에서만 실행되는 명령어:

```bash
/review all --if-changed
/handoff auto --if-phase-complete
```

### 배치 명령어

여러 작업을 일괄 처리:

```bash
/batch [
  "/review recent",
  "/roadmap update",
  "/status quick"
]
```

---

## 📝 사용 시나리오

### 1. 새 프로젝트 시작

```bash
/roadmap init
/design "프로젝트 핵심 기능"
/status
```

### 2. 일일 개발 루틴

```bash
/status quick
/review recent
/roadmap update
```

### 3. 세션 전환

```bash
/review file [작업한 파일]
/roadmap update
/handoff auto
```

### 4. 기능 개발 사이클

```bash
/design "[새 기능명]"
/roadmap add "[설계된 태스크들]"
/status timeline
```

### 5. 프로젝트 점검

```bash
/status detailed
/review all --priority=보안
/roadmap status
```

---

## ⚠️ 주의사항

### 명령어 실행 순서

- 항상 `/status`로 현재 상황을 먼저 파악
- 큰 변경 전에는 `/review`로 현재 코드 상태 확인
- 세션 종료 전에는 반드시 `/handoff` 실행

### 파일 관리

- 명령어 실행 결과로 생성되는 파일들을 정기적으로 정리
- `.handoff_prompts/` 폴더의 오래된 파일들 관리
- `project_roadmap.md`는 항상 최신 상태 유지

### 성능 고려사항

- `/review all`은 대용량 프로젝트에서 시간이 오래 걸릴 수 있음
- `/design --detailed`은 토큰을 많이 사용할 수 있음
- 필요에 따라 적절한 옵션 선택

---

## 🆘 문제 해결

### 명령어가 작동하지 않는 경우

1. 명령어 문법 확인 (`/` 로 시작하는지)
2. 파일 경로 및 권한 확인
3. MCP 연결 상태 확인

### 파일 생성 오류

1. 작업 폴더 접근 권한 확인
2. 디스크 용량 확인
3. 파일명 충돌 확인

### 예상과 다른 결과

1. `/status`로 현재 상태 재확인
2. `project_roadmap.md` 내용 검토
3. 이전 핸드오프 프롬프트 확인

이 명령어 시스템을 통해 효율적이고 체계적인 AI 협력 개발이 가능합니다.
