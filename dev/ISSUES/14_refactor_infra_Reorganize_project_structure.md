Title: [refactor] infra: Reorganize project structure to iOS-First Root and backend separation
Labels: workflow:/solve-github-issue, type:refactor, area:infra, priority:p1

# Summary
The current project structure has a "Russian Doll" nesting issue (`BobCam/BobCam-iOS/BobCamAgent`) and mixes Python backend files with the root. This task aims to flatten the iOS project to the root level and move Python files to a dedicated `backend/` directory, establishing a clean "iOS-First" repository structure.

# Background
- **Current State**:
    - `BobCam-iOS/` contains the iOS project but is nested.
    - Root contains various Python scripts (`main_integrated.py`, etc.) mixed with project files.
    - Redundant `Podfile` and `Gemfile` exist at multiple levels.
- **Goal**:
    - Make `BobCamAgent.xcodeproj` accessible directly from the root.
    - Isolate Python backend code.
    - Archive legacy scripts.

# Scope
- Root directory of the repository.
- `BobCam-iOS/` directory.
- Python scripts in root and `src/`.

# Tasks
- [ ] **Preparation**: Ensure git is clean and backup current state.
- [ ] **Backend Organization**:
    - [ ] Create `backend/`, `backend/tests/`, `backend/legacy/`.
    - [ ] Move active Python scripts (v3.0/v2.1) to `backend/`.
    - [ ] Move test scripts to `backend/tests/`.
    - [ ] Move legacy/backup scripts to `backend/legacy/`.
- [ ] **iOS Reorganization**:
    - [ ] Move contents of `BobCam-iOS/*` up to the root `BobCam/`.
    - [ ] Remove the now empty `BobCam-iOS/` folder.
    - [ ] Remove redundant outer configuration files if any remain.
- [ ] **Verification**:
    - [ ] Verify `BobCamAgent.xcworkspace` opens and builds from root.
    - [ ] Verify `pod install` works at root.
    - [ ] Verify Python backend runs from `backend/` (check imports).

# Acceptance Criteria
1.  **iOS Root**: `BobCamAgent.xcodeproj` and `BobCamAgent.xcworkspace` exist at the repository root.
2.  **No Nesting**: `BobCam-iOS` folder is removed.
3.  **Backend Folder**: All Python scripts are inside `backend/` (sub-organized into `src`, `tests`, `legacy` as appropriate or flat if preferred, but separated from root).
4.  **Builds Pass**: iOS app builds successfully. Python scripts execute correctly from their new location.

# Risks
- **Git History**: Moving files might complicate git history tracking (use `git mv`).
- **Path References**: Scripts or Xcode build phases referencing absolute or relative paths might break.
- **Imports**: Python imports might need adjustment if directory structure changes (e.g., `sys.path`).

# References
- Plan Document: `dev/docs/project_structure_cleanup.md`
