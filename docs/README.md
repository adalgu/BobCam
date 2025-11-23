# BobCam Implementation Guide

## Quick Start for Next Development Phase

### Immediate Next Steps (This Week)

1. **Add Jaw Movement Detection**
   ```bash
   cd /Users/gunn.kim/study/Bob-Cam-New
   cp main_stable.py main_v3_jaw.py
   # Start implementing AdvancedEatingStatus class
   ```

2. **Test Current YOLO Models**
   ```bash
   cd dev/
   python YOLO.py  # Test existing YOLO integration
   ```

3. **Review Research Findings**
   ```bash
   open docs/research/eating-detection-research-2025.md
   ```

### Key Implementation Points

#### 1. MediaPipe Jaw Landmarks to Add
```python
JAW_LANDMARKS = [172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397, 288, 361, 323]
```

#### 2. YOLO Utensil Classes
- `fork`, `knife`, `spoon` (already in COCO)
- `chopsticks` (needs custom training)

#### 3. Performance Targets
- Accuracy: 75% → 92%
- Mobile-ready: iPhone 15 Pro / Galaxy S24 Ultra
- Real-time: 30+ FPS with occasional hiccups OK

### File Structure Created
```
docs/
├── research/
│   └── eating-detection-research-2025.md    # Research findings
└── development-roadmap.md                   # Implementation plan
```

### Next Session Context
When we continue development:
1. Current stable version: `main_stable.py` 
2. Research completed and documented
3. Ready to implement jaw detection (Phase 1)
4. YOLO models already available in `/dev` folder
5. Target: Detect eating when mouth closed + jaw moving + utensils near mouth

---
Last updated: June 8, 2025
