# Local Data Model

## SwiftData entities

### UserProfile

- id
- createdAt
- terminologyMode
- preferredActivityWindows
- quietHours
- biometricLockEnabled
- healthKitEnabled
- currentProgramPhase
- rulesetVersion

### BaselineAssessment

- completedAt
- acquiredOrLifelong
- controlDifficulty
- anxietyBaseline
- sleepBaseline
- exerciseBaseline
- rushedHabitScore
- stimulusPatternScore
- redFlagAnswers

### DailyPlan

- date
- generatedAt
- rulesetVersion
- status
- rationaleCode

### PlannedActivity

- kind
- dateWindow
- estimatedMinutes
- status
- priority
- sourceRuleID

### GuidedSession

- startedAt
- endedAt
- terminalState
- targetCycles
- pauseThreshold
- maximumDuration
- preAnxiety
- postAnxiety
- painReported
- irritationReported
- notesEncrypted

### ArousalEvent

- sessionID
- timestampOffset
- level
- eventType

### PauseCycle

- sessionID
- index
- startOffset
- endOffset
- arousalBefore
- arousalAfter
- lateStop
- successful

### UrgeCheckIn

- createdAt
- intensity
- trigger
- intent
- safetyAnswers
- recommendation
- ruleID
- overridden

### ExerciseLog

- date
- type
- durationMinutes
- intensity
- source
- perceivedDifficulty
- painReported

### ScoreSnapshot

- date
- awareness
- control
- recovery
- calm
- consistency
- independenceLevel

### SymptomFlag

- createdAt
- type
- severity
- resolvedAt
- blocksTraining

## Data retention

- Keep raw event-level session data for 90 days by default.
- Keep weekly aggregate scores indefinitely until deletion.
- Let users delete notes separately.
- HealthKit-derived data should be cached minimally and recalculated where possible.

## Migration

Every schema version needs:

- migration plan;
- rollback test fixture;
- sample anonymized dataset;
- data deletion verification.
