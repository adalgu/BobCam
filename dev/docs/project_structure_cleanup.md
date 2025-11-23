# Project Structure Analysis & Cleanup Plan

## 1. Current Situation Analysis

The project currently suffers from a "Russian Doll" structure where the iOS project is nested inside a folder with the same name, leading to redundancy and potential confusion.

### Current Hierarchy
```text
BobCam/ (Root)
├── BobCam-iOS/ (Level 1)
│   ├── BobCamAgent.xcworkspace (Redundant/Outer)
│   ├── Podfile (Redundant/Outer)
│   ├── Gemfile
│   └── BobCamAgent/ (Level 2 - The "Real" Project Root)
│       ├── BobCamAgent.xcodeproj (The Project File)
│       ├── BobCamAgent.xcworkspace (The Active Workspace)
│       ├── Podfile (The Active Podfile)
│       ├── BobCamAgent/ (Source Code)
│       ├── BobCamAgentTests/
│       └── BobCamAgentUITests/
```

### Identified Issues
1.  **Redundant Configuration**: There are `Podfile`s and `Gemfile`s at both Level 1 and Level 2.
2.  **Confusing Nesting**: `BobCam-iOS/BobCamAgent/BobCamAgent` is difficult to navigate.
3.  **Split State**: The outer Podfile references the inner project (`project 'BobCamAgent/BobCamAgent.xcodeproj'`), attempting to bridge the gap, but this is non-standard and fragile.

## 2. Recommended Cleanup Strategy: "Flatten the Hierarchy"

The goal is to eliminate the intermediate `BobCamAgent` folder (Level 2) so that `BobCam-iOS` becomes the true project root.

### Target Hierarchy
```text
BobCam/ (Root)
└── BobCam-iOS/ (Level 1 - New Project Root)
    ├── BobCamAgent.xcodeproj
    ├── BobCamAgent.xcworkspace
    ├── Podfile
    ├── Gemfile
    ├── BobCamAgent/ (Source Code)
    ├── BobCamAgentTests/
    └── BobCamAgentUITests/
```

## 3. Execution Plan (Step-by-Step)

> **⚠️ Warning**: This operation involves moving files. Ensure you have a clean git state before proceeding.

### Step 1: Preparation
1.  Close Xcode completely.
2.  Ensure all changes are committed to git.

### Step 2: Clean Old Artifacts
Remove the **outer** configuration files that are currently wrapping the project.
```bash
cd BobCam/BobCam-iOS
rm BobCamAgent.xcworkspace
rm Podfile
rm Podfile.lock
rm -rf Pods
```

### Step 3: Move Content Up
Move the contents of the inner `BobCamAgent` folder up one level.
```bash
# Move everything from inner folder to current folder
mv BobCamAgent/* .
mv BobCamAgent/.gitignore . 2>/dev/null || true
mv BobCamAgent/.swiftlint.yml . 2>/dev/null || true

# Remove the now-empty inner shell folder
rmdir BobCamAgent
```

### Step 4: Re-initialize
Now that the files are in `BobCam-iOS`, we need to ensure paths are correct.
1.  Open the `Podfile` (now in `BobCam-iOS`) and ensure it looks correct (it shouldn't need the `project '...'` line anymore if it had it).
2.  Run `pod install`.

### Step 5: Verify
1.  Open `BobCamAgent.xcworkspace` (now directly in `BobCam-iOS`).
2.  Build the project (Cmd+B).
3.  Run tests (Cmd+U).

## 4. Alternative: "Accept & Prune"
If moving files is considered too risky right now, an alternative is to simply **delete the outer wrapper files** and treat the inner folder as the root.

1.  Delete `BobCam-iOS/BobCamAgent.xcworkspace`, `Podfile`, `Gemfile`.
2.  Always open the project from `BobCam-iOS/BobCamAgent/`.
3. (Optional) Rename `BobCam-iOS` to something like `ios-wrapper` to make it clear it's just a container, or rename the inner folder to `src`.

## 5. Alternative: iOS-First Root (Addressing "Can't Level 1 be Root?")

The user asked: *"Can't BobCam-iOS/ (Level 1) be the root?"*

**Yes, absolutely.** This is often the cleanest approach if the repository is primarily for the iOS app.

### The Strategy
Instead of having `BobCam/BobCam-iOS/...`, we move the iOS project files **directly to the top-level `BobCam/` folder** and move the Python files to a dedicated `backend/` or `python/` folder.

### Target Hierarchy (iOS-First)
```text
BobCam/ (Root)
├── BobCamAgent.xcodeproj  <-- iOS Project directly in Root
├── BobCamAgent.xcworkspace
├── Podfile
├── BobCamAgent/           <-- iOS Source Code
├── BobCamAgentTests/
├── backend/               <-- Python files moved here (instead of src/)
│   ├── main.py
│   └── ...
└── dev/
```

### Pros & Cons
*   **Pros**: Standard iOS repo structure. Xcode opens the root folder cleanly. Less nesting.
*   **Cons**: Python files become a subdirectory (which is fine if they are secondary).

### Execution Plan (iOS-First)
1.  **Move Python**: Move all root `*.py` files to `backend/`.
2.  **Move iOS Up**: Move contents of `BobCam-iOS/*` to `BobCam/` (Root).
3.  **Cleanup**: Remove empty `BobCam-iOS` folder.


## 5. Root Directory Cleanup (Python/Legacy)

The root directory contains a mix of active Python scripts, legacy backups, and test files.

### Categorization

**Active / Core (Move to `src/`)**
*   `main_integrated.py` (v3.0 - Latest Active) -> `src/main.py` (Recommended rename)
*   `main_enhanced.py` (v2.1 - Advanced Detection) -> `src/main_enhanced.py`
*   `main_working.py` (v2.1 - Stable) -> `src/main_stable_v2.py`
*   `advanced_eating_status.py` (Dependency)
*   `alarm_system.py` (Dependency)
*   `integrated_alarm_system.py` (Dependency)
*   `utensil_detector.py` (Dependency)
*   `voice_trigger_manager.py` (Dependency)
*   `meal_timing_analyzer.py` (Dependency)

**Tests (Move to `tests/`)**
*   `test_integrated_system.py`
*   `test_phase1.py`
*   `test_phase1_simple.py`

**Legacy / Backups (Move to `legacy/`)**
*   `main_enhanced_backup.py`
*   `src/main_stable.py` (Old v2.0)
*   `src/main-gui.py`
*   `src/main-gui2.py`
*   `src/main-local.py`
*   `src/main.py` (Old)
*   `src/main2.py`
*   `src/sample.py`
*   `src/extract_lip_regions.py`

### Execution Plan (Root Cleanup)

1.  **Create Directories**:
    ```bash
    mkdir -p src
    mkdir -p tests
    mkdir -p legacy
    ```

2.  **Move Legacy Files**:
    *   Move existing cluttered files from `src/` to `legacy/` first to clear the way.
    ```bash
    mv src/* legacy/
    mv main_enhanced_backup.py legacy/
    ```

3.  **Move Tests**:
    ```bash
    mv test_*.py tests/
    ```

4.  **Move Active Source**:
    ```bash
    mv main_integrated.py src/main.py
    mv main_enhanced.py src/
    mv main_working.py src/main_stable_v2.py
    mv advanced_eating_status.py src/
    mv alarm_system.py src/
    mv integrated_alarm_system.py src/
    mv utensil_detector.py src/
    mv voice_trigger_manager.py src/
    mv meal_timing_analyzer.py src/
    ```

5.  **Verify Imports**:
    *   Since all related scripts are moved to `src/`, running `python src/main.py` should work as `sys.path[0]` will be `src`.
    *   If running tests from `tests/`, might need to adjust python path (e.g., `PYTHONPATH=. pytest tests/`).
