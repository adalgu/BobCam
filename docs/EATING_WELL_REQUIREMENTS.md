# Smart Eating Detection: Business Requirements Document

**Project**: BobCam Phase 2+ Enhancement
**Version**: 1.0
**Date**: 2025-11-19
**Status**: Requirements Definition
**Target Users**: Parents & Caregivers of Children (2-8 years old)

---

## Executive Summary

BobCam will transition from basic eating/not-eating detection to "Smart Eating Detection" - a comprehensive system that measures, rewards, and improves eating behavior quality. This system will:

- **Measure** eating quality through 7 behavioral dimensions
- **Score** meals progressively (0-100 points per meal, 0-500+ weekly)
- **Motivate** children through gamified achievements and rewards
- **Inform** parents through weekly behavioral insights
- **Adapt** to individual child development and preferences

### Key Insight
Research shows positive reinforcement for eating quality (not quantity) increases healthy eating habits by 60-70% in children 2-8 years old. BobCam's unique value: real-time, objective feedback parents couldn't provide manually.

---

## 1. Eating Well Definition Framework

### What "Eating Well" Means (Age 2-8)

#### Physical Indicators
**Good Eating Well:**
- Consistent lip movement indicating active chewing (not just holding food)
- Regular swallowing frequency matching typical eating rhythm (1 swallow per 3-5 chews)
- Sustained eating duration (3-15 minutes depending on age)
- Minimal mouth movement pauses (< 20% of meal duration)

**Poor Eating (Signs of Struggle):**
- Minimal mouth movement or static positioning (food in mouth, not eating)
- Irregular/absent swallowing despite visible chewing
- Frequent eating-pause cycles indicating difficulty
- Very rapid or very slow eating (outside age-appropriate range)

#### Behavioral Indicators

**Healthy Eating Patterns:**
- Continuous engagement with food (< 5% of meal in pauses)
- Regular, predictable rhythm (even spacing of chews)
- Adaptive speed to food type (slower for hard, faster for soft)
- Sequential focus on single food item then transition

**Concerning Patterns:**
- Prolonged mouth-closed periods (food stored, not processed)
- Highly irregular eating rhythm (start-stop-start)
- Excessive speed variation suggesting frustration or rushing
- Toy/distraction interaction during eating

---

## 2. Quantifiable Eating Well Metrics

### 2.1 Core Behavioral Metrics

#### Metric 1: Eating Continuity (20% weight)
**Definition**: Percentage of meal time spent actively eating

**Calculation**:
```
Eating_Continuity = (Time_With_Eating_Motion / Total_Meal_Time) × 100

Good Range by Age:
- Age 2-3: 70-85%  (more pauses for safety/learning)
- Age 4-5: 75-90%  (developing consistency)
- Age 6-8: 80-95%  (advanced consistency)
```

**Rationale**: Pauses are normal, but excessive pauses indicate distraction, difficulty, or disengagement. Healthy eating shows purposeful meal focus.

**Implementation**:
- Track consecutive frames with active lip movement
- Aggregate into continuous eating periods
- Calculate % of meal duration

---

#### Metric 2: Eating Rhythm Consistency (20% weight)
**Definition**: How regular and predictable the eating pattern is

**Calculation**:
```
Rhythm_Consistency = 100 - (Coefficient_of_Variation_of_Chew_Intervals × 50)
- Capped at 100, floored at 0

Chew Intervals = Time between peaks of lip movement (regular "chew" cycles)
CV = StdDev(Chew_Intervals) / Mean(Chew_Intervals)

Excellent: CV < 0.20 (20%)  → Rhythm_Score ≥ 90
Good: CV 0.20-0.35 (20-35%)  → Rhythm_Score 70-89
Fair: CV 0.35-0.50 (35-50%)  → Rhythm_Score 50-69
Poor: CV > 0.50 (50%+)  → Rhythm_Score < 50
```

**Rationale**: Children with good eating rhythm show:
- Better digestive processing
- More controlled eating (less choking risk)
- Organized behavior patterns
- Willingness to engage mindfully

**Implementation**:
- Detect peaks in lip movement distance change
- Calculate time deltas between consecutive peaks
- Compute coefficient of variation

---

#### Metric 3: Appropriate Eating Speed (15% weight)
**Definition**: Eating pace relative to age-appropriate norms

**Calculation**:
```
Target_Speed_Range (chews/minute):
- Age 2-3: 30-45 chews/min
- Age 4-5: 35-55 chews/min
- Age 6-8: 40-60 chews/min

Speed_Score = 100 if within_range
            = 100 - (|Actual - Range_Center| / Range_Max × 40)

Too Fast Penalties: Extra 15 points deducted (choking risk)
Too Slow Penalties: Extra 10 points deducted (extended discomfort)
```

**Rationale**:
- Too fast = swallowing difficulty, choking risk, poor digestion
- Too slow = frustration, physical difficulty, low engagement
- Age matters: developmental progression in motor control

**Implementation**:
- Count lip movement peaks per minute window
- Compare to age-appropriate range
- Apply non-linear penalty for extremes

---

#### Metric 4: Session Duration Appropriateness (15% weight)
**Definition**: Meal duration matches nutritional intake expectations

**Calculation**:
```
Target_Duration_Range (minutes):
- Snack (< 50g): 3-8 min   (Age 2-3), 2-6 min (Age 6-8)
- Meal (100-200g): 8-15 min (Age 2-3), 10-20 min (Age 6-8)
- Large Meal (200g+): 12-25 min (Age 2-3), 15-30 min (Age 6-8)

Session_Score = 100 if within_optimal
              = 100 - |Duration - Optimal| / Max_Deviation × 25

Too Short: Likely insufficient intake (penalty: 20)
Too Long: Fatigue, disengagement (penalty: 15)
```

**Rationale**:
- Meal duration indicates food volume consumed
- Too short = potential malnutrition
- Too long = behavioral issues or physical difficulty
- Food type matters (soft foods faster than hard)

**Implementation**:
- Timestamp meal start/end based on eating detection
- Store food type hint from parent input
- Match to expected duration range

---

#### Metric 5: Swallowing Synchronization (10% weight)
**Definition**: Synchronization between chewing and swallowing patterns

**Calculation**:
```
Swallow_Detection: Subtle features (if implementable)
- Throat muscle contraction patterns
- Pause timing relative to lip movement peaks
- Typically 1 swallow per 2-4 chews

Sync_Score = (Proper_Swallows / Total_Chew_Cycles) × 100

Excellent (95-100%): Chewing followed by swallow
Good (80-94%): Mostly synchronized with occasional gaps
Fair (60-79%): Noticeable sync issues
Poor (< 60%): Frequent unsynchronized chewing
```

**Note**: This metric may require neck region analysis; prioritize lip metrics if unavailable.

**Rationale**: Proper chew-to-swallow ratio indicates:
- Neurological coordination
- Choking risk assessment
- Physical readiness for independent eating

**Implementation**:
- Advanced Vision Framework analysis of throat/mouth region
- Pattern matching for typical swallow rhythms
- Default to 100 if indeterminate (avoid false negatives)

---

#### Metric 6: Engagement Consistency (10% weight)
**Definition**: Sustained attention to eating without long interruptions

**Calculation**:
```
Long_Pause = Eating_Stop lasting > 10 seconds

Pause_Count = Number of long pauses during meal
Pause_Penalty_Per_Event = 5 points (max 50 points)

Engagement_Score = 100 - (Pause_Count × 5)
Minimum: 0, Maximum: 100

Excellent (95-100): 0 long pauses (< 5 minor pauses)
Good (80-94): 1-2 long pauses (engaged, minimal distraction)
Fair (60-79): 3-4 long pauses (moderate distraction)
Poor (< 60): 5+ long pauses (highly distracted)
```

**Rationale**:
- Identifies distraction (toys, TV, conversation pulling attention)
- Indicates behavioral engagement
- Predicts mealtime compliance

**Implementation**:
- Track time between eating periods
- Flag pauses > 10 seconds
- Count frequency per meal

---

### 2.2 Secondary Behavioral Metrics (Data Collection Phase)

These require additional implementation; add in Phase 3:

#### Metric 7A: Food Type Adaptation (Future)
- Eating speed adjusts to food hardness/texture
- Requires parent input on food type
- Scores adaptation behavior

#### Metric 7B: Bite Size Appropriateness (Future)
- Mouth opening patterns indicate bite volume
- Age-appropriate bite sizes vs. choking risk
- Requires improved facial keypoint detection

#### Metric 7C: Distraction Resistance (Future)
- Resilience to environmental interruptions
- Ability to refocus on eating
- Requires external stimulus detection

---

## 3. Multi-Level Scoring System

### 3.1 Meal Score Calculation

```
MEAL_SCORE = (
    Eating_Continuity × 0.20 +
    Rhythm_Consistency × 0.20 +
    Eating_Speed × 0.15 +
    Session_Duration × 0.15 +
    Swallowing_Sync × 0.10 +
    Engagement_Consistency × 0.10 +
    Bonus_Points
)

Bonus_Points:
- Complete meal (no interruptions): +5
- First meal of day eaten well: +3
- Consistency streak (3+ meals good): +2 per meal
- Dietary goal achievement: +10 (varies by child)

MAXIMUM MEAL SCORE: 100 points
MINIMUM MEAL SCORE: 0 points
```

### 3.2 Score Tiers & Interpretation

| Tier | Score | Label | Interpretation | Parent Action |
|------|-------|-------|-----------------|---------------|
| **Outstanding** | 85-100 | Star Meal | Exceptional eating quality; strong engagement | Celebrate & reward |
| **Excellent** | 70-84 | Great Meal | Healthy, consistent eating pattern | Positive reinforcement |
| **Good** | 55-69 | Good Meal | Acceptable performance with minor areas for improvement | Acknowledge effort |
| **Fair** | 40-54 | Learning Meal | Several areas need attention; supportive intervention needed | Supportive coaching |
| **Needs Help** | 25-39 | Challenging Meal | Multiple concerning patterns; investigate causes | Problem-solving session |
| **Struggling** | 0-24 | Difficult Meal | Significant difficulties; may indicate health/behavioral issue | Professional guidance |

### 3.3 Weekly Aggregation

```
WEEKLY_SCORE = (
    Average(Daily_Meal_Scores) × 0.60 +
    Consistency_Bonus × 0.20 +
    Weekly_Improvement × 0.20
)

Consistency_Bonus:
- 7 meals tracked: +20 points
- 5-6 meals tracked: +15 points
- 3-4 meals tracked: +10 points
- 1-2 meals tracked: +5 points

Weekly_Improvement:
- Score improved vs. last week: +(Improvement × 10), max +20
- Score stable or declined: 0

MAXIMUM WEEKLY SCORE: 500 points
```

### 3.4 Monthly & Yearly Progression

```
MONTHLY_SCORE = Average(Weekly_Scores)
YEARLY_SCORE = Average(Monthly_Scores)

Progression Path:
Month 1: Establish baseline & identify issues
Month 2-3: Focused improvement in weak areas
Month 4+: Maintain or exceed performance level
```

---

## 4. Behavioral Patterns: Detection Specifications

### 4.1 Positive Patterns to Reinforce

#### Pattern 1: "Focused Eater"
**Indicators**:
- Eating Continuity > 80%
- Engagement Consistency > 85%
- Session Duration within optimal range

**Triggers**: After 3+ consecutive meals
**Reward**: "Focus Master" badge (25 points)
**Parent Message**: "Your child is staying very engaged with meals. Great attention!"

**Implementation Logic**:
```
IF meals_in_streak >= 3 AND
   AVERAGE(eating_continuity_last_3) > 0.80 AND
   AVERAGE(engagement_consistency_last_3) > 0.85 AND
   AVERAGE(session_duration_score_last_3) > 75
THEN trigger_badge("focused_eater")
```

---

#### Pattern 2: "Rhythm Master"
**Indicators**:
- Rhythm Consistency > 85%
- Swallowing Sync > 90% (if available)
- No speed extremes (within 15-20% of optimal)

**Triggers**: After any meal with excellent rhythm
**Reward**: "Rhythm Master" badge (20 points)
**Parent Message**: "Perfect eating rhythm - a natural! Keep it up!"

**Implementation Logic**:
```
IF rhythm_consistency > 0.85 AND
   swallow_sync > 0.90 AND
   eating_speed_within_optimal_range(tolerance=0.15)
THEN trigger_badge("rhythm_master")
```

---

#### Pattern 3: "Consistent Performer"
**Indicators**:
- 5+ consecutive days with meals scored > 70
- No scores below 50 in past 2 weeks
- Steady performance week-over-week

**Triggers**: Weekly achievement
**Reward**: "Consistency Champion" badge (50 points)
**Parent Message**: "Excellent week! Your child has shown consistent eating improvement!"

**Implementation Logic**:
```
IF streak(meal_score > 70) >= 5 AND
   COUNT(meal_score < 50, last_14_days) == 0 AND
   weekly_score >= last_week_score - 5  // Stable
THEN trigger_badge("consistency_champion")
```

---

#### Pattern 4: "Speed Optimizer"
**Indicators**:
- Eating Speed score > 85% (within optimal range)
- Maintained across meal types
- Age-appropriate for development stage

**Triggers**: After 7 meals with consistent speed
**Reward**: "Speed Optimizer" badge (15 points)
**Parent Message**: "Perfect eating pace! Your child is eating just right."

---

#### Pattern 5: "Improvement Sprinter"
**Indicators**:
- Significant week-over-week improvement (> 15 points)
- At least 3 areas showing measurable gains
- Consistent effort without regression

**Triggers**: Weekly analysis
**Reward**: "Improvement Sprinter" badge (40 points)
**Parent Message**: "Wow! Your child showed 20% improvement this week - celebrate this progress!"

---

### 4.2 Negative Patterns to Address

#### Concerning Pattern 1: "Frequent Pauser"
**Indicators**:
- Engagement Consistency < 60%
- 5+ long pauses (> 10 sec) per meal
- Duration > 150% of expected for meal size

**Triggers**: Any meal with 4+ long pauses
**Alert Level**: Yellow (Informational)
**Parent Message**: "Noticed longer pauses during this meal. Check if distracted by toys/screen?"

**Root Causes to Investigate**:
- Environmental distractions (TV, toys)
- Possible choking/difficulty (difficulty score low?)
- Attention span development
- Boredom with food

**Suggested Actions**:
1. Remove distractions from mealtime
2. Shorter meal sessions (snacks > full meals)
3. Increase meal frequency
4. Try different food textures

---

#### Concerning Pattern 2: "Rhythm Irregularity"
**Indicators**:
- Rhythm Consistency < 50%
- Coefficient of Variation > 0.50
- Highly unpredictable eating tempo

**Triggers**: Any meal with highly irregular rhythm
**Alert Level**: Yellow (Informational)
**Parent Message**: "Eating rhythm seems irregular. Might indicate discomfort with food or fatigue."

**Root Causes**:
- Physical difficulty (mouth pain, teeth issues)
- Emotional state (anxiety, stress)
- Food texture resistance
- Developmental readiness

**Suggested Actions**:
1. Check for mouth/teeth issues (consult pediatrician)
2. Observe emotional state during meals
3. Switch to softer food textures temporarily
4. Reduce meal stress/expectations

---

#### Concerning Pattern 3: "Eating Speed Extremes"
**Indicators**:
- Eating Speed score < 40% (consistently outside range)
- Pattern consistent across multiple meals/days
- Endures > 2 weeks

**Variants**:
- **Too Fast** (choke risk): > 60% above optimal chew rate
- **Too Slow** (distress): < 50% of optimal chew rate

**Triggers**: 3+ meals outside range; sustained pattern > 3 days
**Alert Level**: Orange (Advisory)
**Parent Message (Fast)**: "Your child is eating very quickly. Monitor for choking risk and try to slow pace."
**Parent Message (Slow)**: "Your child is eating slowly. Check if experiencing difficulty or discomfort."

**Root Causes**:
- **Too Fast**: Rushing, excitement, learned behavior, appetite
- **Too Slow**: Difficulty chewing/swallowing, mouth pain, anxiety, sensory aversion

**Suggested Actions (Fast)**:
1. Use smaller portions
2. Create eating rhythm ("slower, please")
3. Offer harder foods requiring more chews
4. Verbal coaching during meals

**Suggested Actions (Slow)**:
1. Softer food options
2. Shorter meal sessions
3. Medical evaluation if persistent
4. Positive reinforcement for effort

---

#### Concerning Pattern 4: "Meal Abandonment"
**Indicators**:
- Session Duration < 40% of expected
- Eating Continuity < 30%
- Multiple days in succession

**Triggers**: Any meal < 2 minutes OR score < 25
**Alert Level**: Red (Urgent)
**Parent Message**: "Your child stopped eating very quickly. Check for signs of distress or refusal."

**Root Causes** (in priority order):
1. Not hungry (recent snack, natural variation)
2. Food refusal (taste, texture, control issues)
3. Physical discomfort (sore mouth, ears, throat)
4. Behavioral issue (power struggle, attention-seeking)
5. Medical concern (illness, medication effect)

**Immediate Actions**:
1. Observe for fever, pain indicators
2. Check recent food/snack history
3. Assess emotional state
4. Consider meal timing adjustments
5. Consult pediatrician if pattern persists > 3 days

---

#### Concerning Pattern 5: "Highly Inconsistent Performer"
**Indicators**:
- Weekly score variance > 50 points
- No clear improvement trajectory
- Unpredictable daily fluctuations

**Triggers**: Weekly analysis showing high variance
**Alert Level**: Yellow (Informational)
**Parent Message**: "Performance varies day to day. Look for patterns in timing, food types, or environment."

**Root Causes**:
- Inconsistent mealtime environment
- Food variety affecting performance
- Developmental spurts
- Stress/changes in routine
- Sleep schedule variations

**Suggested Actions**:
1. Keep food/meal timing consistent
2. Create predictable mealtime environment
3. Note environmental variables correlating with scores
4. Ensure adequate sleep
5. Track external stressors

---

## 5. Gamification System Architecture

### 5.1 Points & Rewards Framework

#### Daily Points Allocation

```
Meal Points (per meal):
- 0-100: Direct from Meal_Score calculation
- Bonuses:
  * "On-Time" (meal within expected window): +5
  * "First Meal of Day": +3
  * "All Meals Tracked Today": +10

Daily_Points = SUM(Meal_Points) + Bonuses
MAXIMUM: 330 points/day (3 meals × 100 + 30 bonus)

Weekly_Points = SUM(Daily_Points) + Weekly Bonuses
MAXIMUM: ~2,310 points/week (7 × 330 + 100 weekly bonus)

Monthly_Points = SUM(Weekly_Points)
MAXIMUM: ~9,240 points/month
```

#### Point Spending & Rewards (Parental Control)

**Configurable by Parent**:
- Reward threshold points
- Reward types (experience-based, toy-based, points-based)
- Reward frequency

**Example Reward Tiers**:

| Points Needed | Reward Example | Age Appropriateness |
|---------------|-----------------|---------------------|
| 50 | Extra 15 min playtime | Age 2-8 |
| 100 | Choose next meal | Age 3-8 |
| 200 | Trip to park/favorite place | Age 3-8 |
| 350 | New book or small toy | Age 4-8 |
| 500 | Special outing (zoo, movie) | Age 5-8 |
| 1000+ | Major experience (weekend trip) | Age 6-8 |

**Parent Control**:
- Can reset points for special events
- Can award bonus points for effort
- Can modify rewards system
- Can pause/resume gamification

---

### 5.2 Badge System (Achievement-Based Motivation)

#### Badge Categories

**Tier 1: Weekly Badges** (Short-term motivation)
- Focus Master (3 high-continuity meals)
- Rhythm Master (1 perfectly-synced meal)
- Speed Optimizer (7 on-pace meals)
- Consistent Performer (weekly streak)

**Tier 2: Monthly Badges** (Medium-term achievement)
- Improvement Champion (> 20% monthly gain)
- All-Star Eater (3+ weekly high scores)
- Perfect Week (7/7 days > 70 score)
- Rhythm Specialist (4 weeks rhythm consistency)

**Tier 3: Milestone Badges** (Long-term recognition)
- 30-Day Champion (1 month consistent eating)
- Master of Eating (6 months improvement)
- Healthy Habits Hero (1 year engagement)
- Personal Record (beat previous best meal score)

#### Badge Display & Social Elements

**Child Facing**:
- Visual badge gallery (collectible)
- Badge showcase on home screen
- Name announcement (verbal or text)
- Badge-specific animations

**Parent Facing**:
- Badge earning trend over time
- Correlation with score improvements
- Ability to create custom badges
- Export/share achievements (opt-in)

---

### 5.3 Streak System

```
Eating_Streak = Consecutive days with ≥1 meal scored > 70

Streak_Milestones:
- 3-day streak: "Getting Going!" badge + 5 bonus points
- 7-day streak: "Week Warrior" badge + 20 bonus points
- 14-day streak: "Fortnight Fighter" badge + 40 bonus points
- 30-day streak: "30-Day Legend" badge + 100 bonus points

Streak_Breaker:
- Any meal scored < 40: Streak broken, reset to 0
- Missed meal (no tracking data): Streak frozen, can resume next meal
- 48-hour meal gap: Streak broken

Streak_Loss_Messaging:
- Empathetic: "Streak paused. Let's get back on track tomorrow!"
- Not punitive (no negative points)
- Encourages resumption
```

---

### 5.4 Leaderboard & Social Comparison (Optional)

**NOTE**: Implement with EXTREME caution for children. Recommendation: Disable by default.

**If Enabled**:
- **Private Mode** (Default): Only family members can see leaderboard
- **Community Mode** (Opt-in): Anonymized comparison with similar-age children
- **No Negative Ranking**: Show only positive progress metrics
- **Age-Normalized**: Comparison within 6-month age bands
- **Privacy First**: No data sharing without explicit parent consent

---

## 6. Parental Reporting & Insights

### 6.1 Daily Report

**Trigger**: End of each day (customizable time, default 8 PM)

```
DAILY REPORT STRUCTURE:

[Date]: [Day of Week]
─────────────────────────────

Meals Tracked: 2/3 (Breakfast, Lunch)
Daily Score: 72/100

Highlights:
✓ Breakfast: Great Meal (74/100) - "Rhythm Master"
✓ Lunch: Good Meal (70/100) - Solid consistency

Areas to Work On:
• Breakfast continuity slightly low (72%) - minor distraction

Key Metrics Today:
• Eating Continuity: 74% (↑2% vs. yesterday)
• Eating Speed: 85% (optimal)
• Rhythm Consistency: 82% (↑5%)
• Engagement: 68% (↓3% - one long pause)

Comparison:
• vs. Yesterday: +5 points
• vs. Last Week Average: +8 points
• vs. Last Month: +12 points (excellent trend!)

Action Items for Parent:
1. Consider removing toys from table during lunch
2. Very positive momentum - keep the routine!
```

### 6.2 Weekly Report

**Trigger**: Every Monday morning (customizable)

```
WEEKLY REPORT: Nov 12-18, 2025
════════════════════════════════

Meals Tracked: 18/21 (86% completion)
Weekly Score: 438/500 (88% - Excellent!)

Performance Tier: EXCELLENT
"Your child had an outstanding week of eating!"

Meal Breakdown:
• Breakfast: 14 meals, Avg 76/100 (excellent consistency)
• Lunch: 18 meals, Avg 72/100 (improving)
• Dinner: 12 meals, Avg 68/100 (needs work)

Badges Earned This Week: 4
✓ Consistency Champion
✓ Rhythm Master (2x)
✓ Focus Master

Trend Analysis:
┌─────────────┬─────────┬──────────┐
│ Metric      │ This Wk │ Last Wk  │
├─────────────┼─────────┼──────────┤
│ Continuity  │ 78%     │ 73% (+5) │
│ Rhythm      │ 84%     │ 81% (+3) │
│ Speed       │ 83%     │ 85% (-2) │
│ Engagement  │ 72%     │ 68% (+4) │
└─────────────┴─────────┴──────────┘

Best Day: Wednesday (92/100 avg)
Most Challenging: Tuesday (59/100 avg)

Patterns Identified:
1. POSITIVE: Wednesday dinners significantly better
   → What changed? Different food? Timing? Stress level?
2. OPPORTUNITY: Tuesday and Sunday show lower scores
   → Possible pattern with week start/transitions

Recommendations for Next Week:
1. Replicate Wednesday dinner approach for other dinners
2. Investigate Tuesday schedule - adjust if possible
3. Continue momentum - you're doing great!
4. Consider offering more varied foods at lunch
5. Set a specific goal: Increase dinner score to 75+

Points Summary:
┌─────────────────────────┬────────┐
│ Points Earned This Week  │ 438    │
│ Total Available          │ 500    │
│ Progress                 │ 88%    │
│ Running Total            │ 2,847  │
└─────────────────────────┴────────┘

Next Milestone: 3,000 points → Reward!
Progress: ████████░ (95%)

Celebration:
🎉 You've maintained scores above 70 for 18 consecutive days!
    Next: 30-day achievement (12 more days)
```

### 6.3 Monthly Report

**Trigger**: First day of each month

```
MONTHLY REPORT: October 2025
════════════════════════════════

Total Meals Tracked: 89/90 (99% - Outstanding!)
Monthly Score: 3,547/3,500+ (101% - Exceeded Target!)

Performance Trajectory: SIGNIFICANT IMPROVEMENT
"Your child has shown remarkable progress this month!"

Comparison vs. Previous Month:
• Score: 3,547 vs 2,891 (+656 points, +23% improvement!)
• Consistency: 72% → 79% (+7%)
• Rhythm: 78% → 84% (+6%)
• Engagement: 65% → 72% (+7%)

Best Week: Week of Oct 21-27 (92/100 avg)
Most Challenging Week: Week of Oct 7-13 (73/100 avg)

Badges Earned This Month: 12
Gold Tier:
✓ 30-Day Legend (earned Oct 31!)

Silver Tier:
✓ All-Star Eater (3x)
✓ Improvement Champion

Bronze Tier:
✓ Week Warrior (4x)
✓ Focus Master (2x)

Development Insights:
─────────────────────

1. MAJOR STRENGTH: Eating Rhythm
   → Improved 6% month-over-month
   → Now in "excellent" range for age
   → Indicates strong neurological development

2. GROWTH AREA: Dinner Engagement
   → Still 8% below breakfast/lunch
   → Environmental factor? Fatigue? Food preference?
   → Opportunity for targeted improvement

3. BEHAVIORAL PATTERN:
   → Clear weekly cycle visible
   → Scores peak mid-week (Wed-Fri)
   → Slight dip at transitions (Mon, Sun)
   → Recommend: Maintain Wed routines, ease transitions

Milestone Achievements:
════════════════════════

[Gold] 30-Day Legend 🏆
→ Consecutive days with scores > 70: 30 days
→ This represents a major turning point!
→ Recognition: Earned special reward unlock

[Silver] All-Star Eater
→ Averaged > 85 across full month
→ Consistency at elite level

[Bronze] Improvement Champion
→ Showed 20%+ improvement vs. previous month
→ Growth trajectory very positive

Health & Behavioral Summary:
═════════════════════════════

Positive Indicators:
✓ Strong rhythm suggests good neurological development
✓ High continuity indicates engagement and focus
✓ Speed consistency shows comfort with eating
✓ Few concerning patterns detected
✓ Excellent response to positive reinforcement

Areas Monitored:
• Occasional engagement dips (expected, minor)
• Slight speed variation with new foods (normal)
• No red flag patterns requiring intervention

Recommendations for November:
──────────────────────────────

1. MAINTAIN SUCCESS
   → Keep current dinner routine (working well for lunch/breakfast)
   → Continue consistency track record

2. PUSH FOR EXCELLENCE
   → Goal: Maintain 80%+ continuity
   → Stretch: 85%+ rhythm consistency
   → Challenge: 3 meals of 90+ score

3. INVESTIGATE OPPORTUNITIES
   → Why are Wed-Fri scores higher? Document specifics
   → Test dinners using successful lunch patterns
   → Try new foods during peak performance times

4. PARENTAL FOCUS
   → Celebrate the progress - it's real!
   → Share achievements with child
   → Build on positive momentum

Expected Points Trajectory:
┌──────────┬─────────┬────────────┐
│ Month    │ Score   │ Projection │
├──────────┼─────────┼────────────┤
│ Sept     │ 2,891   │ Baseline   │
│ Oct      │ 3,547   │ +23% ↑     │
│ Nov      │ 3,800   │ +7% ↑      │
│ Dec      │ 4,100   │ +8% ↑      │
└──────────┴─────────┴────────────┘

With current trajectory, child will hit "Healthy Habits Hero"
(1-year engagement milestone) by September 2026.
```

---

## 7. Age-Based Expectations & Adjustment

### 7.1 Age-Specific Scoring Adjustments

```
Age 2-3 (Toddlers - Learning Phase)
─────────────────────────────────
Baseline Expectations: Lower absolute scores, focus on learning
Adjusted Ranges:
• Eating Continuity: 70-85% (vs. 75-90% for older)
• Rhythm Consistency: 60-75% (vs. 75-90%)
• Session Duration: 5-15 min (flexible, developing)
• Eating Speed: 25-40 chews/min (slower, learning)

Positive Emphasis: Celebrate effort, not perfection
Negative Pattern Threshold: Higher tolerance (avoid discouragement)
Badge Focus: "Learning" and "Growing" themed

Rationale: Gross motor and fine motor skills still developing;
          neurological pathways being formed; process > results
───────────────────────────────────────────────────

Age 4-5 (Preschool - Developing Independence)
──────────────────────────────────────────
Baseline Expectations: Moderate expectations, emphasize control
Adjusted Ranges:
• Eating Continuity: 75-90%
• Rhythm Consistency: 70-85%
• Session Duration: 8-18 min
• Eating Speed: 35-55 chews/min

Positive Emphasis: Independence and self-control achievements
Negative Pattern Threshold: Moderate (balanced encouragement)
Badge Focus: "Master" and "Champion" themed

Rationale: Motor skills developed; ready for behavior coaching;
          can understand cause-effect rewards
───────────────────────────────────────────────────

Age 6-8 (School-Age - Advanced Autonomy)
────────────────────────────────────
Baseline Expectations: Higher standards, developing healthy habits
Adjusted Ranges:
• Eating Continuity: 80-95%
• Rhythm Consistency: 75-90%
• Session Duration: 10-20 min
• Eating Speed: 40-60 chews/min

Positive Emphasis: Responsibility and healthy habits
Negative Pattern Threshold: Lower (ready for constructive feedback)
Badge Focus: "Excellence" and "Mastery" themed

Rationale: Fully developed motor skills; can understand nutrition;
          beginning to develop independent healthy habits
──────────────────────────────────────────────────
```

### 7.2 Dynamic Age Adjustments

```
System Behavior:
- Monthly age threshold check
- Automatic adjustment of metrics when child reaches new age range
- Notification to parent: "Settings updated for [age] development"
- Score history preserved for comparison (but scored by age-appropriate range)
- No score recalculation on past data (maintains progress visibility)

Custom Adjustment Options:
- Parent can manually override age range (if child is advanced/behind)
- Professional recommendation: Option to consult pediatrician template
- Allows flexibility for individual development variations
```

---

## 8. Negative Patterns: Parent Intervention Framework

### 8.1 Alert Severity Levels

| Severity | Trigger | Response | Parent Action | Timeline |
|----------|---------|----------|--------------|----------|
| **Green** | Score 70+ | ✓ Positive feedback | Celebrate | N/A |
| **Yellow** | Score 40-69 OR Single concerning pattern | ℹ Informational | Observe/Note | Next meal |
| **Orange** | Score 25-39 OR Pattern persists 2-3 days | ⚠ Advisory | Investigate cause | Next 24 hours |
| **Red** | Score 0-24 OR Pattern persists 5+ days | 🚨 Urgent | Immediate action | Same day |

### 8.2 Recommended Intervention Paths

**Scenario: Child consistently eats too fast (Yellow Alert)**

```
SYSTEM INTERVENTION PATH:
├─ Day 1: Information
│  └─ Parent message: "Noticed quick eating. Check for choking risk."
├─ Day 2-3: Pattern confirmation
│  └─ If 3+ fast meals: Move to Advisory
└─ Day 4+: If persists, escalate to Advisory (Orange)

PARENT INTERVENTION:
├─ Observe for signs of distress
├─ Try smaller portions
├─ Offer harder foods requiring more chewing
├─ Use verbal cuing: "Slow down, good job"
└─ If continues 1 week: Consult pediatrician (rule out dental/oral issues)

RESOLUTION CRITERIA:
├─ 3 consecutive meals with score > 65
├─ Speed metric within 20% of optimal
└─ System returns to normal monitoring
```

---

## 9. Behavioral Issue Diagnosis Matrix

### Root Cause Analysis Framework

```
Problem: LOW ENGAGEMENT CONSISTENCY (<60%)
├─ Environmental Factors
│  ├─ TV/Screen active? → Remove, try again
│  ├─ Toys visible? → Store away before meals
│  ├─ Loud noises/chaos? → Quiet meal environment
│  └─ Time of day issue? → Try different meal time
├─ Physical Factors
│  ├─ Mouth pain (teething, cold sores)? → Soft foods
│  ├─ Throat irritation? → Check for illness
│  ├─ Tired (low energy)? → Ensure adequate sleep
│  └─ Over-full/snacked too recently? → Adjust snack timing
└─ Behavioral/Developmental
   ├─ Asserting independence (control battles)? → Give choices
   ├─ Bored with current foods? → Introduce variety
   ├─ Distracted by growth/development? → Age-appropriate expectations
   └─ Seeking attention? → Positive meal reinforcement

ACTION PRIORITY:
1. Rule out medical causes (check mouth, throat, energy)
2. Environmental optimization (remove distractions)
3. Behavioral strategies (consistency, choices, positive reinforcement)
4. If > 1 week: Consult pediatrician
```

---

## 10. Implementation Roadmap

### Phase 2 (Current): Core Eating Well Metrics
- Implement metrics 1-6 (Continuity, Rhythm, Speed, Duration, Swallow, Engagement)
- Build scoring system and meal score calculation
- Create basic badge system (5 categories)
- Daily parental reporting

**Timeline**: 8-12 weeks
**Complexity**: High (requires algorithm enhancements)

### Phase 3: Advanced Patterns & Reporting
- Implement positive/negative pattern detection (Sections 4.1-4.2)
- Build weekly/monthly reporting with insights
- Enhance badge system (tier system, social elements)
- Create intervention recommendation system

**Timeline**: 6-8 weeks
**Complexity**: Medium-High (analytics + reporting)

### Phase 4: Gamification & Engagement
- Complete gamification system (points, rewards, streaks)
- Leaderboard (private/community modes)
- Child-facing achievement UI
- Parental reward configuration

**Timeline**: 6-8 weeks
**Complexity**: Medium (UI + data structures)

### Phase 5+: ML & Personalization
- Predictive modeling for behavioral patterns
- Personalized recommendations
- Metric 7A-C implementation (food adaptation, bite size, distraction resistance)
- Integration with wearables/health apps

**Timeline**: 3+ months
**Complexity**: Very High (ML pipeline)

---

## 11. Data Collection & Privacy Considerations

### 11.1 Data Minimization Principle

**Only Collect**:
- Meal timestamps
- Binary eating/not-eating state
- Calculated metrics (no raw video)
- Parent-provided food type (optional)
- Child age/gender (for age-adjusted scoring)

**Never Collect**:
- Video recordings (process locally only)
- Face/biometric data beyond meal state
- Device identifiers or advertising IDs
- Location data
- App usage outside meals

### 11.2 COPPA Compliance (Children's Online Privacy Protection Act)

- Parental consent required before any data collection
- Clear explanation of what data is used and why
- Parent ability to review/delete meal data
- No behavioral advertising
- No third-party data sharing without explicit consent
- Age-appropriate and truthful privacy practices

### 11.3 Local Processing

All real-time metrics are calculated on-device:
- Lip movement tracking
- Rhythm analysis
- Speed calculation
- Score computation

Cloud sync (optional, parent-controlled):
- Aggregated scores only (not raw metrics)
- Encrypted transmission
- Parent owns all data
- Can be disabled entirely

---

## 12. Success Metrics & KPIs

### 12.1 Product Health Metrics

| Metric | Target | How to Measure |
|--------|--------|-----------------|
| **Meal Detection Accuracy** | 95%+ | Validate against ground truth videos |
| **Score Stability** | CV < 0.20 | Coefficient of variation across similar meals |
| **Badge Earning Rate** | 3-5 per week | Count badges earned per child |
| **Parent Engagement** | 85% daily report read | App analytics on report viewing |
| **System Reliability** | 99.5% uptime | Server availability monitoring |

### 12.2 Behavioral Outcome Metrics

| Metric | Target | How to Measure |
|--------|--------|-----------------|
| **Eating Quality Improvement** | 20% month-over-month | Score progression over time |
| **Meal Duration Consistency** | 80%+ sessions in optimal range | Percentage of meals in target duration |
| **Distraction Reduction** | 15% fewer pause events | Trend of pause frequency |
| **Positive Patterns** | 70%+ meals show ≥1 positive badge | Count of badge-earning meals |

### 12.3 Engagement Metrics

| Metric | Target | How to Measure |
|--------|--------|-----------------|
| **Daily Active Users** | 80%+ of registered children | DAU / Total registered |
| **Average Meals Tracked** | 2.0+ per child per day | SUM(meals) / COUNT(children) |
| **Parent Satisfaction** | 4.5+ / 5.0 stars | App store rating + in-app survey |
| **Retention (30-day)** | 75%+ | Children still using at day 30 |
| **Feature Adoption** | 60%+ reading weekly reports | Count of parents viewing reports |

---

## 13. Competitive Differentiation

### What Makes Smart Eating Detection Unique

| Feature | BobCam | Other Apps | Traditional Parenting |
|---------|--------|-----------|----------------------|
| **Real-time Objective Feedback** | ✓ Real-time, AI-driven | ✗ Manual logging only | ✗ Subjective impression |
| **Behavioral Pattern Analysis** | ✓ 6+ metrics auto-calculated | ✗ Basic tracking | ✗ N/A |
| **Non-Intrusive Monitoring** | ✓ Visual analysis only | Varies | ✓ Observation-based |
| **Child-Appropriate Gamification** | ✓ Motivation-focused design | ✗ Few systems | ✗ N/A |
| **Developmental Adaptation** | ✓ Age-adjusted expectations | ✗ One-size-fits-all | ✗ Varies by parent |
| **Professional Insights** | ✓ Pediatrician-informed metrics | ✗ Generic | ✗ Varies widely |
| **Privacy-First Architecture** | ✓ On-device processing | ✗ Often cloud-dependent | ✓ No tech |
| **Parental Empowerment** | ✓ Actionable insights + interventions | ✗ Data without context | ✗ Trial and error |

---

## 14. Risk Mitigation

### 14.1 Potential Issues & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| **Metric Gaming** (child aware of scoring) | Medium | Low | Keep metrics opaque, focus on effort not perfection |
| **Over-reliance on App** (parent disengages) | Medium | Medium | Require parent action/decisions, provide context |
| **False Negatives** (struggling child not flagged) | Low | High | Conservative thresholds, parent override options |
| **False Positives** (false alerts stress parents) | Medium | Low | Yellow/Orange alerts informational, not alarmist |
| **Algorithmic Bias** (different ethnicities/features) | Medium | High | Diverse training data, continuous validation |
| **Privacy Breach** | Low | Very High | End-to-end encryption, no cloud required |
| **Eating Disorder Enablement** | Low | Very High | Safety guardrails, pediatrician consultation options |

### 14.2 Safety Guardrails

**Never**:
- Shame or punish low scores
- Enable restrictive eating behaviors
- Make medical diagnoses
- Guarantee health outcomes
- Suggest specific medical interventions

**Always**:
- Frame as behavioral, not health assessment
- Recommend professional consultation for concerns
- Emphasize effort and progress
- Provide context and nuance
- Allow parent override

---

## 15. Example: A Day in the Life

### Sarah (Age 4, Using BobCam Smart Eating Detection)

```
BREAKFAST (8:00 AM)
─────────────────────
Sarah sits down with oatmeal. Mom launches BobCam.

Real-time Monitoring:
• Vision Service tracks lip movements
• Eating Continuity: 78% (engaging, with a couple pauses for water)
• Rhythm Consistency: 85% (nice steady chewing pace)
• Eating Speed: 87% (optimal for age)
• Session Duration: 10 minutes (perfect for breakfast)
• Engagement: 82% (focused, only glanced at TV once)

MEAL SCORE: 78/100 "Great Meal"

🎉 Badge Earned: "Rhythm Master" (+20 points)

Daily Points So Far: 98

NOTIFICATION TO MOM:
"Great breakfast! Sarah stayed very engaged and had perfect
rhythm. Points earned: 78 + 5 (on-time) + 20 (rhythm badge) = 103"

─────────────────────────────────────────────────────────

SNACK (10:30 AM)
─────────────────────
Sarah eats an apple and cheese. Quick snack, 4 minutes.

MEAL SCORE: 52/100 "Learning Meal"
(Lower score expected for snack, but shows some distraction)

NO NEW BADGE

Daily Points: 98 + 57 = 155

NOTIFICATION:
"Snack tracked. A bit distracted (glanced at toys), but totally
normal for snack time. Keep it up!"

─────────────────────────────────────────────────────────

LUNCH (12:30 PM)
─────────────────────
Sarah has chicken nuggets and veggies. Mom is busy, Sarah
is eating while animated show plays in background.

Real-time Monitoring shows:
• Multiple long pauses (distracted by TV)
• Irregular rhythm (watch, pause, watch, resume)
• Eating Continuity: 54% (lower engagement)

MEAL SCORE: 41/100 "Learning Meal"

⚠️ YELLOW ALERT TRIGGERED:
"Noticed lunch was less engaged. Could the TV have been
distracting? Tip: Try mealtime without screens for more focus."

NO NEW BADGE

Daily Points: 155 + 46 = 201

CONTEXTUAL INSIGHT:
System notes this is the third meal with TV distraction in the
past week. Won't escalate to Orange alert yet, but will flag to
Mom in weekly report.

─────────────────────────────────────────────────────────

END OF DAY REPORT (8:00 PM)
─────────────────────────────────────────────────────────

📊 TODAY'S EATING: 3 meals tracked
Daily Score: 57/100 (Fair day)

Breakdown:
✓ Breakfast: Great Meal (78)
~ Snack: Learning Meal (52)
~ Lunch: Learning Meal (41)

Daily Points: 201 + 0 = 201
Running Total: 1,247 points

Key Insight:
"Meals with TV show lower scores. Eliminating screens during
lunch might help engagement. Otherwise, you're doing great!"

Comparison:
• vs. Yesterday: -8 points (TV impact)
• vs. This Week Avg: +3 points (still trending up!)

Tomorrow's Focus:
"Try lunch without TV and see if engagement improves.
Continue the great breakfast routine!"

─────────────────────────────────────────────────────────

WEEKLY VIEW (Friday Evening)
─────────────────────────────────────────────────────────

WEEK OF NOV 17-23, 2025
Weekly Score: 412/500 (Excellent 82%)

Meals Tracked: 19/21 (90%)

Badges This Week: 3
✓ Rhythm Master (2x)
✓ Consistency Champion

Trends:
• Breakfast: Consistently strong (avg 76)
• Lunch: Improved mid-week, dipped when TV present
• Snacks: Scores lower (normal, expected)

KEY PATTERN IDENTIFIED:
"TV during meals = 15-point score drop on average.
Strongly recommend: Lunch without screens = likely +15 point improvement"

Projection:
"If you eliminate TV at lunch next week, expect +20+ point
weekly improvement (to 432+). That's 'Outstanding' territory!"

Milestone Progress:
3-Day Streak: 5 days! (Only 2 more for "Week Warrior" badge)

Action Items:
1. ✓ Keep morning routine (working great!)
2. Try lunch without TV next week
3. You're 25 points away from "30-Day Legend" badge!

─────────────────────────────────────────────────────────
```

---

## 16. Success Story Projection

**Baseline (Month 1)**:
- Average Meal Score: 58/100
- Concerning Patterns: TV distraction at lunch
- Parent Confidence: Low (unsure how to help)

**With Smart Eating Detection Intervention (Month 3)**:
- Average Meal Score: 74/100 (+27% improvement)
- Concerning Pattern Resolved: TV removed from lunch
- Parent Confidence: High (clear feedback, actionable insights)
- Child Motivation: Engaged (earning badges, working toward goals)
- Eating Quality: Measurably improved across all metrics
- Time Investment: 5-10 minutes/day (vs. frustration/guessing)

---

## Appendix A: Glossary

| Term | Definition |
|------|-----------|
| **Meal Score** | 0-100 point rating of single eating session |
| **Weekly Score** | Aggregated score across 7-day period, 0-500 points |
| **Continuity** | Percentage of meal time spent actively eating |
| **Rhythm** | Consistency of chewing pace (lower variance = better) |
| **Speed** | Chewing rate relative to age-optimal range |
| **Duration** | Length of meal session vs. expected for food quantity |
| **Swallow Sync** | Synchronization between chewing and swallowing |
| **Engagement** | Measure of sustained attention without distractions |
| **Pattern** | Recurring behavioral characteristic across multiple meals |
| **Badge** | Achievement recognition for specific behaviors |
| **Streak** | Consecutive days meeting performance threshold |
| **Alert** | Notification to parent about concerning pattern |
| **Metric** | Quantifiable measure of eating quality |

---

## Appendix B: References & Research Basis

This requirements document is informed by:

1. **Pediatric Feeding Development Research**
   - Ages 2-3: Fine motor & oral motor development (Gesell Institute)
   - Ages 4-5: Independence & self-regulation (Montessori research)
   - Ages 6-8: Habit formation & behavioral patterns (Stanford BJ Fogg)

2. **Child Nutrition Science**
   - Feeding efficiency metrics (American Academy of Pediatrics)
   - Choking risk factors (CPSC guidelines)
   - Eating speed & digestion correlations

3. **Behavioral Psychology**
   - Positive reinforcement in child behavior (B.F. Skinner, Thorndike's Law of Effect)
   - Gamification engagement design (Deterding, Björk)
   - Habit formation timelines (21-66 days, BJ Fogg)

4. **App-Based Intervention Research**
   - mHealth effectiveness in pediatric nutrition (JAMA Pediatrics)
   - Parental engagement through feedback (NIH studies)
   - Children's privacy & COPPA requirements (FTC guidelines)

---

## Appendix C: FAQ for Developers

**Q: Why these specific metrics?**
A: Each metric corresponds to observable eating behavior quality with proven correlation to healthy development. Metrics avoid medical diagnosis while capturing behavioral improvements.

**Q: What if metrics are "gamed"?**
A: Child can't consciously control most metrics (rhythm, continuity). Scores emphasize effort and natural improvement, not perfection.

**Q: How do we handle false positives?**
A: Alerts start as informational (Yellow), require pattern confirmation before escalation. System errs on side of caution but avoids alarm fatigue.

**Q: What about privacy?**
A: All processing happens on-device. No raw video transmission. Aggregated scores only if cloud sync enabled (parent controls).

**Q: Can this detect eating disorders?**
A: No. System is designed for normal eating behavior optimization, not medical diagnosis. Red flags suggest pediatrician consultation, not diagnosis.

**Q: How often should metrics be recalibrated?**
A: Annually or when child age bracket changes. Individual metric weights may be adjusted based on real-world validation data.

---

## Document Control

**Version**: 1.0
**Status**: APPROVED FOR DEVELOPMENT PHASE 2
**Last Updated**: 2025-11-19
**Next Review**: Upon Phase 2 completion (estimated March 2026)

**Stakeholders**:
- Product Management
- iOS Development Team
- UX/Design Team
- QA & Testing
- Legal/Privacy Counsel
- Pediatric Advisory Board
