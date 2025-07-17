## Brief overview

이 문서는 프로젝트의 Git 브랜치 전략에 대한 규칙을 정의합니다. 브랜치 이름에 작업의 목적, 환경, 내용을 명확히 표기하여 협업 효율성을 높이고, Git Hooks 및 CI/CD를 통해 규칙을 자동화하는 것을 목표로 합니다.

## Branch Naming Convention

- 브랜치 이름은 다음 형식을 따라야 합니다: `타입/환경/기능-설명[#이슈번호]`
- **타입**: 작업의 성격을 나타냅니다.
  - `feature`: 새로운 기능 개발
  - `bugfix`: 버그 수정
  - `refactor`: 코드 리팩토링
  - `experiment`: 실험적인 기능 개발
  - `docs`: 문서 수정
- **환경**: 작업이 이루어진 환경을 명시합니다.
  - 형식: `llm이름-개발머신이름`
  - 예시: `gemini-macbook`, `claude-macmini`
- **기능-설명**: 작업 내용을 명확하고 간결하게 설명합니다.
  - 단어는 하이픈(`-`)으로 연결합니다.
  - 예시: `add-translation-api`, `fix-login-error`
- **이슈번호 (선택 사항)**: 관련 이슈가 있는 경우, 이름 끝에 `#이슈번호`를 추가합니다.
- **전체 예시**:
  - `feature/gemini-macbook/add-translation-api`
  - `bugfix/claude-macmini/fix-login-error#42`
  - `experiment/gpt4-macbook/test-new-prompt`

## Automation with Git Hooks

- 개발자가 원격 저장소에 코드를 push하기 전, 로컬에서 브랜치 이름 규칙을 검사하기 위해 Git `pre-push` 훅을 사용합니다.
- 규칙에 맞지 않는 브랜치는 push가 자동으로 차단되어 실수를 방지합니다.
- 아래 스크립트를 `.git/hooks/pre-push` 파일로 설정하여 사용할 수 있습니다.

  ```bash
  #!/bin/bash
  ALLOWED_TYPES="feature|bugfix|refactor|experiment|docs"
  BRANCH_REGEX="^($ALLOWED_TYPES)\/([a-z0-9]+-[a-z0-9]+)\/([a-z0-9]+-)*[a-z0-9]+(#\d+)?$"
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

  if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "dev" ]]; then
      exit 0
  fi

  if [[ ! "$CURRENT_BRANCH" =~ $BRANCH_REGEX ]]; then
      echo "[POLICY ERROR] 잘못된 브랜치 이름입니다."
      echo "규칙: 타입/llm-머신/기능-설명[#이슈번호]"
      echo "예시: feature/gemini-macbook/add-login-feature#123"
      exit 1
  fi
  exit 0
  ```

## Automation with CI/CD

- Git Hooks를 우회하는 경우에 대비하여, GitHub Actions와 같은 CI/CD 파이프라인에서 브랜치 이름을 최종 검증합니다.
- Pull Request가 생성되거나 업데이트될 때마다 워크플로우가 실행되어 규칙을 강제합니다.
- 아래 워크플로우를 `.github/workflows/branch-lint.yml`로 추가하여 사용할 수 있습니다.

  ```yaml
  name: Branch Naming Convention
  on:
    pull_request:
      types: [opened, edited, synchronize]

  jobs:
    lint-branch-name:
      runs-on: ubuntu-latest
      steps:
        - name: Check Branch Name
          run: |
            BRANCH_NAME="${{ github.head_ref }}"
            REGEX="^(feature|bugfix|refactor|experiment|docs)\/([a-z0-9]+-[a-z0-9]+)\/([a-z0-9]+-)*[a-z0-9]+(#\d+)?$"
            if [[ ! "$BRANCH_NAME" =~ $REGEX ]]; then
              echo "::error::Branch name '${BRANCH_NAME}' does not follow the convention: 타입/llm-머신/기능-설명"
              exit 1
            fi
  ```

## Advanced Workflow

- **Conventional Commits**: 브랜치 전략과 함께 Conventional Commits 규칙을 도입하여 커밋 메시지를 구조화합니다.
- **Semantic Release**: `semantic-release` 도구를 활용하여 버전 관리, 릴리스 노트 생성, 배포 알림 등 전체 릴리스 과정을 자동화하는 것을 권장합니다.
