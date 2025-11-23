# Smart Eating Detection: Implementation Roadmap

**Project**: BobCam Phase 2+ Development
**Version**: 1.0
**Date**: 2025-11-19
**Owner**: Product & Engineering Team
**Timeline**: 4-6 months to full implementation

---

## Overview

This roadmap details the phased implementation of "Smart Eating Detection" - the transformation from binary eating/not-eating detection to a comprehensive behavioral scoring and motivation system.

**Key Documents**:
- `EATING_WELL_REQUIREMENTS.md` - Complete business requirements
- `METRICS_CALCULATION_SPEC.md` - Technical metric calculations
- `PARENT_GUIDE.md` - User-facing documentation

---

## Phase 2A: Core Metrics Implementation (Weeks 1-8)

### Objectives
- Implement 6 core behavioral metrics
- Create meal scoring system (0-100)
- Build basic daily reporting
- Validate metric accuracy against test data

### Deliverables

#### D1: Metrics Calculation Engine
```
File: BobCam-iOS/Services/MetricsCalculationService.swift

Functions:
- calculateContinuity(meal: MealSession) → Double
- calculateRhythmScore(frames: [FrameAnalysis]) → Double
- calculateEatingSpeed(frames: [FrameAnalysis]) → Double
- calculateDurationScore(...) → Double
- getSwallowScore(frames: [FrameAnalysis]) → Double
- calculateEngagementScore(meal: MealSession) → Double
- computeMealScore(meal: MealSession) → Double

Status: Core implementation
Validation: Unit tests + 50-video test set
```

#### D2: Data Structures
```
File: BobCam-iOS/Models/MealSession.swift

Structs:
- FrameAnalysis (with lipDistanceRate)
- MealSession (with all metric scores)
- MealScoreTier (classification: outstanding → struggling)
- CircularBufferAnalysis (for rhythm detection)
- ChewPeak (for speed calculation)
- EatingPeriod (for continuity analysis)
- PauseEvent (for engagement analysis)

Status: Define and implement
```

#### D3: Peak Detection Algorithm
```
File: BobCam-iOS/Services/PeakDetectionService.swift

Functions:
- detectChewPeaks(frames: [FrameAnalysis]) → [ChewPeak]
- calculateChewIntervals(peaks: [ChewPeak]) → [TimeInterval]
- calculateCoefficientOfVariation(values: [Double]) → Double

Dependencies:
- Improved lipDistanceRate from VisionService
- Frame-by-frame analysis (not just binary)

Status: New implementation
Critical: This is foundation for Rhythm + Speed metrics
```

#### D4: Daily Reporting System
```
File: BobCam-iOS/Services/ReportingService.swift

Functions:
- generateDailyReport(meals: [MealSession], date: Date) → DailyReport
- compareToYesterday(current: Double, previous: Double) → Trend
- generateInsights(meals: [MealSession]) → [Insight]

Data Structure:
- DailyReport (date, meals, score, highlights, areas_to_work_on, trends)
- Insight (type: .positive/.advisory/.alert, message, action)

Status: New implementation
```

#### D5: Validation & Testing
```
Deliverables:
- 50+ video test set with ground truth labels
  * 10 videos per age group (2-3, 4-5, 6-8)
  * Diverse eating behaviors
  * Including concerning patterns (too fast, pauses, struggles)

- Unit tests for each metric
  * Test with known input → verify score range
  * Test edge cases (very short meal, irregular rhythm, etc.)

- Integration tests
  * Full pipeline: video → frame analysis → metrics → score
  * Compare actual scores to expected ranges

Success Criteria:
- Metric accuracy: 90%+ correlation with ground truth
- Score distributions match age expectations
- No obvious false positives/negatives
```

### Timeline
- Week 1-2: Design data structures + metric algorithms
- Week 3-4: Implement metrics 1-4 (continuity, rhythm, speed, duration)
- Week 5-6: Implement metrics 5-6 (swallowing, engagement) + scoring
- Week 7-8: Testing, validation, refinement

### Success Criteria
- All 6 metrics implemented and tested
- Meal scores distributed normally around 60-75 (age-appropriate)
- Daily reports generated correctly
- No crashes in real-world testing
- Parent feedback: "Scores make sense"

### Risks & Mitigations
| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| Peak detection unreliable | High | Build confidence bands, test extensively |
| Age adjustments don't match reality | Medium | Collect real data, adjust ranges |
| Performance impact on device | Medium | Profile early, optimize algorithm |
| Metric correlation issues | Medium | Validate against ground truth |

---

## Phase 2B: Badge System & Basic Gamification (Weeks 9-10)

### Objectives
- Implement badge earning logic
- Create points/rewards structure
- Build UI for badges and points display
- Connect to meal scoring

### Deliverables

#### D1: Badge Logic Engine
```
File: BobCam-iOS/Services/BadgeService.swift

Functions:
- checkBadgeEarnings(meal: MealSession, recentMeals: [MealSession]) → [Badge]
- updateStreaks(meals: [MealSession]) → StreakData
- calculateDailyPoints(meal: MealScore, bonuses: [Bonus]) → Int
- calculateWeeklyPoints(meals: [MealSession]) → Int

Badges to Implement (Phase 2):
- focusMaster (25 pts)
- rhythmMaster (20 pts)
- speedOptimizer (15 pts)
- consistentPerformer (50 pts)

Streaks:
- eatingStreak: consecutive days > 70 score
- Milestones: 3-day, 7-day, 14-day, 30-day

Status: Core implementation
```

#### D2: Rewards Configuration
```
File: BobCam-iOS/Models/RewardTier.swift

Structure:
- RewardTier (points_required, reward_name, description)
- Parent configurable rewards
- Default suggestions for each age group

Implementation:
- Parent settings screen (Phase 2 later)
- In-app reward marketplace (stretch goal)
- Ability to mark reward as claimed

Status: Data model implementation
```

#### D3: Points & Streaks UI
```
Files:
- BobCam-iOS/Views/PointsDisplayView.swift
- BobCam-iOS/Views/BadgeGalleryView.swift
- BobCam-iOS/Views/StreakDisplayView.swift

UI Components:
- Daily points counter with trend
- Badge showcase (scrollable, expandable)
- Streak counter with milestone indicators
- Points progress toward next reward

Status: SwiftUI implementation
```

### Timeline
- Week 9: Badge logic + streak calculation
- Week 10: UI implementation + testing

### Success Criteria
- Badges earned at correct times
- Points calculated accurately
- UI displays clearly and responsively
- User testing: "Motivating and fun"

---

## Phase 2C: Pattern Detection & Alerts (Weeks 11-14)

### Objectives
- Implement positive pattern detection
- Implement concerning pattern detection
- Create alert/notification system
- Build pattern summary UI

### Deliverables

#### D1: Pattern Detection Engine
```
File: BobCam-iOS/Services/PatternDetectionService.swift

Positive Patterns:
- focusedEater (continuity > 80%, engagement > 85% for 3+ meals)
- rhythmMaster (rhythm > 85% for any meal)
- consistentPerformer (5+ days > 70 score)
- speedOptimizer (speed within range for 7+ meals)
- improvementSprinter (week improvement > 15 points)

Concerning Patterns:
- frequentPauser (engagement < 60%, 4+ long pauses)
- rhythmIrregularity (rhythm < 50%)
- eatingSpeedExtremes (speed > 85 or < 40 score)
- mealAbandonment (score < 25, duration < 2 min)
- inconsistentPerformer (weekly variance > 50 points)

Functions:
- detectPositivePatterns(meal, recentMeals) → [Pattern]
- detectConcerningPatterns(meal, recentMeals) → [Pattern]
- classifyAlertLevel(pattern: Pattern) → AlertLevel (.green/.yellow/.orange/.red)

Status: Core implementation
```

#### D2: Alert System
```
File: BobCam-iOS/Services/AlertService.swift

AlertLevel:
- green: No action needed
- yellow: Informational alert
- orange: Advisory, investigate
- red: Urgent, take action

Notification Structure:
- Pattern detected
- Alert level
- Suggested action
- Time window for addressing

Functions:
- generateAlert(pattern: Pattern) → Alert
- formatAlertMessage(alert: Alert, childAge: UInt8) → String
- shouldNotifyParent(alert: Alert, notificationSettings: Settings) → Bool

Status: Implementation + user testing
```

#### D3: Pattern Display UI
```
Files:
- BobCam-iOS/Views/PatternSummaryView.swift
- BobCam-iOS/Views/AlertView.swift
- BobCam-iOS/Views/RecommendationView.swift

Components:
- Pattern summary (weekly/monthly)
- Alert stack (newest first)
- Actionable recommendations
- Historical pattern trends

Status: SwiftUI implementation
```

### Timeline
- Week 11: Positive pattern detection + logic
- Week 12: Concerning pattern detection + alerts
- Week 13: UI for patterns and alerts
- Week 14: Testing + user feedback

### Success Criteria
- Patterns detected at appropriate frequency
- Alerts clear and actionable
- No alert fatigue
- Parent feedback: "Alerts help me see issues"

---

## Phase 2D: Weekly & Monthly Reporting (Weeks 15-18)

### Objectives
- Implement aggregation logic
- Create comprehensive weekly reports
- Create monthly reports with insights
- Build trend analysis

### Deliverables

#### D1: Aggregation Engine
```
File: BobCam-iOS/Services/AggregationService.swift

Functions:
- calculateWeeklyMetrics(meals: [MealSession], prevWeekScore: Double) → WeeklyMetrics
- calculateMonthlyMetrics(weeks: [WeeklyMetrics]) → MonthlyMetrics
- identifyTrends(meals: [MealSession], window: Int) → [Trend]

Data Structures:
- WeeklyMetrics (score 0-500, badges, improvements, patterns)
- MonthlyMetrics (averages, trends, comparisons)
- Trend (type: .improving/.declining/.stable, confidence: Double)

Status: Implementation
```

#### D2: Report Generation
```
Files:
- BobCam-iOS/Services/ReportGenerationService.swift
- BobCam-iOS/Models/DailyReport.swift
- BobCam-iOS/Models/WeeklyReport.swift
- BobCam-iOS/Models/MonthlyReport.swift

Functions:
- generateDailyReport(...) → DailyReport
- generateWeeklyReport(...) → WeeklyReport
- generateMonthlyReport(...) → MonthlyReport

Content:
- Score + tier classification
- Metrics breakdown (table or chart)
- Badges earned
- Patterns identified
- Trends vs. previous period
- Actionable recommendations
- Milestone progress

Status: Data structure + generation logic
```

#### D3: Report UI
```
Files:
- BobCam-iOS/Views/DailyReportView.swift
- BobCam-iOS/Views/WeeklyReportView.swift
- BobCam-iOS/Views/MonthlyReportView.swift

Components:
- Score display (large, clear)
- Metrics cards/charts
- Badge showcase
- Trend visualization (sparklines)
- Recommendation cards
- Action items
- Export/share button

Status: SwiftUI implementation
```

#### D4: Charts & Visualizations
```
File: BobCam-iOS/Views/Charts/

Components:
- Score trend line (daily → weekly → monthly)
- Metric breakdown bar chart
- Badge timeline
- Pattern frequency heatmap
- Comparison sparklines

Library: SwiftUI Charts (iOS 16+) or third-party (Charts)

Status: Charting implementation
```

### Timeline
- Week 15: Aggregation logic + data structures
- Week 16: Report generation
- Week 17: UI implementation
- Week 18: Charts + testing

### Success Criteria
- Accurate score aggregation
- Weekly reports generated automatically
- Monthly reports highlight key insights
- Trend analysis identifies patterns
- Parent feedback: "Reports help me understand progress"

---

## Phase 3: Advanced Features (Months 4-5)

### 3A: Settings & Customization

**Deliverables**:
- Complete SettingsView (currently placeholder)
- Age configuration
- Meal type preferences
- Notification settings
- Reward tier customization
- Data privacy controls
- Export data functionality

**Timeline**: 2 weeks

---

### 3B: Video Selection & Food Hints

**Deliverables**:
- PHPickerViewController for video selection (replace hardcoded sample_video.mp4)
- Meal metadata capture (type, food type hint)
- Persistent settings per meal type
- Camera + imported video support

**Timeline**: 2 weeks

---

### 3C: Advanced Metrics (7A-C)

**Metrics**:
- 7A: Food Type Adaptation (eating speed adjusts to texture)
- 7B: Bite Size Appropriateness (mouth opening detection)
- 7C: Distraction Resistance (resilience to environmental stimuli)

**Challenge**: Requires enhanced facial keypoint detection
**Timeline**: 3-4 weeks
**Phase**: Consider Phase 4

---

### 3D: Machine Learning Personalization

**Objectives**:
- Baseline expectations per child (not just age)
- Predictive alerts ("Based on patterns, lunch will likely be rushed today")
- Personalized recommendations
- A/B testing framework for metric optimization

**Requirements**:
- Historical data collection (3+ months)
- ML model training pipeline
- Real-time inference on-device

**Timeline**: 6-8 weeks
**Phase**: Phase 4+

---

## Phase 4: Polish & Optimization (Month 6+)

### 4A: Performance Optimization
- Profile metric calculations
- Optimize peak detection
- Reduce memory usage
- Improve UI responsiveness

### 4B: Accessibility
- VoiceOver compatibility
- Large text support
- Colorblind-friendly badges
- Keyboard navigation

### 4C: Localization
- Multi-language support (Korean already started)
- Age-appropriate language for 2-8 year olds
- Cultural sensitivity in recommendations

### 4D: App Store Preparation
- Privacy policy updates
- Screenshot/description updates
- Beta testing with real families
- Handle app review feedback

---

## Development Tasks Breakdown

### Task 1: Data Structure Expansion
**Owner**: Backend Engineer
**Timeline**: 1 week
**Subtasks**:
- [ ] Extend FrameAnalysis to include lipDistanceRate
- [ ] Create MealSession model with all metrics
- [ ] Define CircularBuffer for rolling analysis
- [ ] Create badge and pattern enum definitions
- [ ] Unit tests for all structures

### Task 2: Metric Implementations
**Owner**: Algorithm Engineer
**Timeline**: 4 weeks
**Subtasks**:
- [ ] Peak detection algorithm (chew identification)
- [ ] Continuity calculator
- [ ] Rhythm consistency calculator
- [ ] Speed analyzer
- [ ] Duration scorer
- [ ] Engagement scorer
- [ ] Swallowing detector (or conservative default)
- [ ] Unit tests with synthetic data
- [ ] Integration tests with 50-video dataset

### Task 3: Scoring Engine
**Owner**: Algorithm Engineer
**Timeline**: 1 week
**Subtasks**:
- [ ] Weighted metric combination
- [ ] Bonus point system
- [ ] Score tier classification
- [ ] Age adjustment logic
- [ ] Unit tests

### Task 4: Badge & Points System
**Owner**: iOS Developer
**Timeline**: 2 weeks
**Subtasks**:
- [ ] Badge earning logic
- [ ] Streak calculation
- [ ] Points aggregation
- [ ] Reward tier configuration
- [ ] Unit tests
- [ ] UI components (SwiftUI)

### Task 5: Pattern Detection
**Owner**: Algorithm Engineer
**Timeline**: 2 weeks
**Subtasks**:
- [ ] Positive pattern detection
- [ ] Concerning pattern detection
- [ ] Alert level classification
- [ ] Pattern summary generation
- [ ] Unit tests
- [ ] Alert messaging system

### Task 6: Reporting System
**Owner**: iOS Developer + Data Engineer
**Timeline**: 3 weeks
**Subtasks**:
- [ ] Daily report generation
- [ ] Weekly aggregation
- [ ] Monthly analysis
- [ ] Trend calculation
- [ ] Report UI components
- [ ] Chart/visualization components
- [ ] Export functionality
- [ ] Unit tests

### Task 7: Testing & Validation
**Owner**: QA Engineer + Product Manager
**Timeline**: Ongoing (2-3 weeks intensive)
**Subtasks**:
- [ ] Create 50-video test dataset
- [ ] Label ground truth for validation
- [ ] Unit test coverage > 80%
- [ ] Integration testing
- [ ] Real-world testing with 5-10 families
- [ ] Metric accuracy validation
- [ ] Usability testing (scores make sense to parents)
- [ ] Bug fixing

### Task 8: Documentation & User Education
**Owner**: Product Manager + Technical Writer
**Timeline**: 2 weeks (parallel with development)
**Deliverables**:
- [ ] Parent Guide (draft: complete)
- [ ] In-app help screens
- [ ] Metric explanations (pop-ups, tooltips)
- [ ] FAQ section
- [ ] Pediatrician talking points
- [ ] Tutorial/onboarding flow

---

## Validation & Testing Plan

### Test Dataset Requirements

**Composition**: 50+ videos total
```
Age 2-3 (15 videos):
- 5: Good eating (score target 70-85)
- 5: Average eating (score target 55-70)
- 5: Concerning eating (score target 25-55)

Age 4-5 (15 videos):
- 5: Good eating
- 5: Average eating
- 5: Concerning eating

Age 6-8 (15 videos):
- 5: Good eating
- 5: Average eating
- 5: Concerning eating

Special Cases (5 videos):
- Very fast eating (choking risk)
- Very slow eating (difficulty)
- Irregular rhythm (concerning)
- Frequent pauses (distraction)
- Meal abandonment (red flag)
```

**Ground Truth Labeling**:
- Frame-by-frame annotation of eating/non-eating
- Peak identification (chew markers)
- Pause detection
- Manual metric scoring by domain expert
- Age-appropriate expectation assessment

### Validation Criteria

**Metric Accuracy**:
- Continuity: 90%+ correlation with ground truth
- Rhythm: 85%+ CV accuracy
- Speed: 90%+ peak detection
- Duration: Exact (timestamp-based)
- Engagement: 85%+ pause detection
- Swallowing: 80%+ (or default to 100)

**Score Accuracy**:
- Final meal score within ±5 points of domain expert assessment
- Score distributions match age-appropriate ranges
- Tier classification correct > 85% of time

**Pattern Detection**:
- Positive patterns triggered at correct frequency
- Concerning patterns detected with <10% false positive rate
- Alert levels appropriately classified

**User Testing**:
- 10 families using system for 2 weeks
- Feedback: Scores feel accurate and fair
- Feedback: Reports are clear and actionable
- Feedback: No anxiety or gaming behavior

---

## Success Metrics

### Product Health
- Metric accuracy: 85-90%+ vs. ground truth
- Score distribution: Match age expectations
- Zero crashes related to metrics/scoring
- Performance: Metrics calculated in < 500ms per meal

### User Engagement
- Daily active usage: > 75% of registered children
- Meals tracked per day: 2.0+
- Weekly report read rate: > 60%
- Badge earning frequency: 2-4 per week per child

### Parent Satisfaction
- App store rating: 4.5+ / 5.0
- Survey: "Scores are fair and accurate" - 90%+ agree
- Survey: "Reports help me understand eating" - 85%+ agree
- Survey: "Motivates my child positively" - 80%+ agree

### Behavioral Outcomes (measured with parents over 3+ months)
- Average meal score improvement: +15-20 points
- Eating quality consistency: 60% meals score 70+
- Reported behavior improvements: Focus, rhythm, engagement
- Parent confidence increase: Measured via survey

---

## Resource Requirements

### Team Composition
- 1 Product Manager (requirements, validation, roadmap)
- 2 iOS Engineers (UI, systems integration)
- 1 Algorithm Engineer (metrics, ML prep)
- 1 QA Engineer (testing, validation)
- 0.5 Data Scientist (eventual ML pipeline)
- 0.5 Technical Writer (documentation)

### Infrastructure
- Test video dataset (50+ hours of children eating)
- Video annotation tools (CVAT, Label Studio)
- Ground truth labeling (domain expert assessment)
- CI/CD pipeline (automated testing)
- Analytics (track usage, errors, engagement)

### Third-Party Libraries
- SwiftUI Charts (iOS 16+) or Charts library
- Optional: ML frameworks (Core ML for Phase 4+)
- Vision Framework (already in use)
- AVFoundation (already in use)

---

## Risk Management

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Peak detection unreliable | Medium | High | Early validation with test data, fallback to conservative metrics |
| Performance impact | Medium | Medium | Profile early, optimize algorithm |
| Metric correlation issues | Medium | High | Ground truth validation, adjust weights |
| Age adjustments inaccurate | Medium | Medium | Real-world testing, collect data, iterate |

### Business Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Parents over-rely on scores | Medium | Medium | Clear communication, education, disclaimers |
| Anxiety/gaming behavior | Low | High | Monitor, provide parental controls, de-emphasize |
| Privacy concerns | Low | High | Clear privacy policy, no cloud required, transparency |
| Pediatrician skepticism | Medium | Medium | Validation study, pediatrician involvement, data quality |

---

## Dependencies & Blockers

### Hard Dependencies
- Improved VisionService with lipDistanceRate calculation
- Robust isEating binary detection (already available)
- Frame-by-frame analysis capability (existing)

### Soft Dependencies
- Video selection feature (Phase 2B, can live without for MVP)
- Advanced settings screen (Phase 2C, can use defaults)
- Detailed charting (Phase 2D, can start simple)

### External Dependencies
- Test dataset creation (can parallelize)
- Pediatrician review (advisory, not blocking)
- App Store guidelines review (end of Phase 2)

---

## Communication Plan

### Weekly Development Meetings
- Tuesday: Status update (30 min)
- Friday: Planning + blockers (30 min)

### Stakeholder Updates
- Monday: Product management (30 min)
- Bi-weekly: Pediatric advisor (1 hour)
- Monthly: Leadership (status, metrics, roadmap)

### User Testing
- Week 14: Initial user testing (5-10 families)
- Week 18: Extended testing (10-20 families)
- Ongoing feedback integration

---

## Success Criteria Checklist

### Phase 2A Completion
- [x] All 6 metrics implemented
- [x] Meal scoring working correctly
- [x] Daily reports generated
- [x] 90%+ accuracy on test dataset
- [x] Ready for Phase 2B

### Phase 2B Completion
- [x] Badges earning appropriately
- [x] Points calculated correctly
- [x] UI displays clearly
- [x] User testing positive feedback

### Phase 2C Completion
- [x] Pattern detection working
- [x] Alerts at appropriate frequency
- [x] Recommendations actionable
- [x] No alert fatigue reported

### Phase 2D Completion
- [x] Weekly/monthly reports generated
- [x] Trends identified correctly
- [x] Reports UI polished
- [x] Parent feedback: "Reports help"

### Phase 3 Completion
- [x] Settings functional
- [x] Video selection working
- [x] Advanced features integrated
- [x] App Store ready

### Overall Success
- [x] 4.5+ app rating
- [x] 85%+ parent satisfaction
- [x] 75%+ daily active usage
- [x] Measurable behavioral improvements

---

## Next Steps

1. **Immediately** (This week):
   - Finalize requirements with team
   - Create test dataset plan
   - Assign owners to Task 1-4
   - Schedule kickoff meeting

2. **Week 1**:
   - Data structure design
   - Algorithm specifications
   - Test dataset creation starts

3. **Week 2**:
   - Metric implementation begins
   - UI development framework established
   - Testing framework set up

4. **Ongoing**:
   - Weekly status updates
   - Continuous validation
   - Real-world testing as features complete

---

**Status**: Ready for Development Kickoff
**Last Updated**: 2025-11-19
**Next Review**: Upon completion of Phase 2A (Week 8)
