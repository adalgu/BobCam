## Brief overview
This document outlines the versioning and documentation strategy for projects. It distinguishes between major and minor updates to ensure the Memory Bank is updated appropriately based on the significance of the changes.

## Versioning Strategy
- **Major Versions**: Represent significant new features, architectural changes, or substantial refactoring. These are changes that alter the core functionality or structure of the project.
- **Minor Versions**: Represent smaller enhancements, bug fixes, or incremental feature additions (e.g., UI tweaks, performance improvements).

## Documentation Workflow for Minor Versions
- **Goal**: To record changes efficiently without a full documentation overhaul.
- **Process**:
  - Update `memory-bank/activeContext.md` to describe the new feature or change.
  - Update `memory-bank/progress.md` to reflect the current status and completion of the new feature.
  - Other core documents (`projectbrief.md`, `systemPatterns.md`, etc.) are generally not modified for minor updates unless a small change directly impacts a core principle described within them.

## Documentation Workflow for Major Versions
- **Goal**: To ensure the Memory Bank provides a complete and accurate snapshot of the project's new state.
- **Process**:
  - A full review and update of **all** relevant Memory Bank files is required.
  - `projectbrief.md`: Update if the project's core objectives have evolved.
  - `systemPatterns.md`: Update to reflect any new architectural patterns or significant changes to the system design.
  - `techContext.md`: Update if new libraries, frameworks, or technologies were introduced.
  - `activeContext.md` and `progress.md`: Update to reflect the new features and current project status.

---
### Examples of Updates

#### Major Update Examples (`v1.x.x` -> `v2.0.0`)
*   Integrating a new, complex backend like YOLO for object detection.
*   Completely overhauling the UI from Tkinter to a web-based framework like Flask.
*   Adding fundamentally new capabilities, such as user accounts or a data analytics dashboard.

#### Minor Update Examples (`v1.0.x` -> `v1.1.0` or `v1.1.x` -> `v1.2.0`)
*   Adding a new, self-contained feature, like the screen fade effect.
*   Refining the detection algorithm with new metrics.
*   Improving the layout of the UI without changing the core framework.
*   Adding a new text-to-speech notification.

#### Patch Update Examples (`v1.0.0` -> `v1.0.1`)
*   Fixing a bug that causes a crash.
*   Correcting a typo in the UI.
*   Improving the visibility of visual elements (like the landmark thickness change).
