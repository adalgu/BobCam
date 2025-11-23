# Create GitHub Issue(s)

Use this command when you have a natural-language problem/goal and need production-ready GitHub issues that the /solve-github-issue workflow can immediately act on.

   - Use curl with $GITHUB_PAT for GitHub API calls.

## Workflow

### Phase 1: Context & Drafting (Agent)
1. Launch the github-issue-maker agent with the provided GOAL:
   - Read CLAUDE.md, ARCHITECTURE.md, relevant dev/docs/**, and recent dev_handoffs/.
   - Search existing issues/PRs to avoid duplicates and reference related work.
   - Decompose the GOAL into one or more discrete issues when appropriate.
   - Produce issue drafts using the standard template (Title, Summary, Background, Scope, Acceptance Criteria, Technical Notes, Task Breakdown, Validation Strategy, Risks/Open Questions, References).

### Phase 2: Conventions & Validation
- Ensure each issue follows conventions:
  - Title: `[type] area: imperative summary` where type ∈ {feature, bugfix, refactor, docs, experiment} and area ∈ {frontend, backend, infra, data, tests, devops}.
  - Labels: include `workflow:/solve-github-issue` and `type:<feature|bugfix|refactor|docs|experiment>`; add area/priority labels as needed (e.g., `area:backend`, `priority:p2`).
  - Dependencies: cross-link issues in body (e.g., `Blocks #123`, `Blocked by #124`).
- Acceptance criteria must be testable and map 1:1 to validation steps.

### Phase 3: Publishing via gh CLI (Do Not Execute Here)
- Append a bash block that registers each issue to the repository using GitHub CLI (gh) with proper labels/metadata so `/solve-github-issue` can pick them up immediately.
- Provide both single-issue and multi-issue examples.

Example:
```bash
# Single issue example
TITLE="[feature] backend: implement scalable transcript batching"
BODY_FILE=".codex/out/issue-backend-transcript-batching.md"

gh issue create \
  --title "$TITLE" \
  --body-file "$BODY_FILE" \
  --label "workflow:/solve-github-issue" \
  --label "type:feature" \
  --label "area:backend" \
  --assignee "@me"

# Multiple issues example (expects headers 'Title:' and 'Labels:' in each file)
for f in .codex/out/issues/*.md; do
  TITLE=$(grep -m1 '^Title:' "$f" | sed 's/^Title:[[:space:]]*//')
  LABEL_ARGS=()
  IFS=',' read -ra LBS <<< "workflow:/solve-github-issue,$(grep -m1 '^Labels:' "$f" | sed 's/^Labels:[[:space:]]*//')"
  for lb in "${LBS[@]}"; do
    lb_trimmed=$(echo "$lb" | xargs)
    [ -n "$lb_trimmed" ] && LABEL_ARGS+=(--label "$lb_trimmed")
  done
  gh issue create --title "$TITLE" --body-file "$f" "${LABEL_ARGS[@]}"
done
```

### Phase 4: Make a local backup
- Copy the issue to dev/ISSUES/<issue-number_issue-title>.md

### Phase 5: Handoff
- After issues are published, hand off to planners/implementers:
  - Next step for each issue: run `/solve-github-issue <number>`

## Rules
- Strategy-only: do not modify code or promise implementation.
- Cite assumptions and missing information explicitly.
- Prefer multiple focused issues over a single monolith; record dependencies.

## Usage
```bash
/create-github-issue "<natural-language goal or problem>"
```

Examples:
```bash
/create-github-issue "Fix frequent websocket reconnects on dashboard and add retry backoff telemetry"
/create-github-issue "Add transcript batching to reduce DB writes and improve latency"
```
