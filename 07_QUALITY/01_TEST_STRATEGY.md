# Test Strategy

## Unit tests

### Rule engine

- Every safety rule.
- Rule priority conflicts.
- Deterministic output.
- Explainability reason codes.
- Override restrictions.

### Scheduler

- no consecutive sessions;
- weekly maximum;
- recovery day preservation;
- missed-task rebalance;
- quiet-hours handling;
- daylight-saving/time-zone changes.

### Scoring

- bounds 0–100;
- no reward for extra sessions;
- rest adherence reward;
- stable moving averages;
- missing-data handling.

### State machines

- all valid transitions;
- invalid transition rejection;
- safety hold from every active state.

## Integration tests

- SwiftData migrations;
- local notification regeneration;
- biometric relock;
- export encryption/decryption;
- HealthKit permission denial;
- app launch in airplane mode.

## UI tests

- onboarding;
- urge flow;
- threshold warning;
- early completion;
- safety block;
- data deletion;
- Dynamic Type;
- VoiceOver labels.

## Motion tests

- Reduce Motion fallbacks;
- haptic disabled state;
- no repeated warning haptics after pause;
- interruption handling when app backgrounds.

## Privacy tests

- app switcher hides content;
- notification text remains neutral;
- no sensitive logs;
- no network requests;
- deleted data is not restored after relaunch.

## Performance tests

- launch time;
- session timer drift;
- scrolling at 60/120 Hz;
- SwiftData query latency;
- battery use during 20-minute guided session.
