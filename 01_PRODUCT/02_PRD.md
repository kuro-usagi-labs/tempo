# Product Requirements Document

## 1. Problem

Many users who feel they climax too quickly do not know whether they should abstain, train, exercise, relax, or seek medical care. Generic stopwatch apps increase pressure, while online tools create privacy concerns.

## 2. Goal

Provide a fully offline system that selects and guides the next appropriate action based on user answers and historical behavior.

## 3. Success criteria

The product succeeds when users report:

- earlier recognition of rising arousal;
- more successful pauses;
- lower anxiety before sessions;
- less rushed behavior;
- consistent exercise and recovery;
- reduced dependence on guided mode;
- appropriate medical referral when warning signs appear.

No success metric should imply guaranteed treatment.

## 4. Primary user journeys

1. New user completes assessment and receives an automatic week plan.
2. User feels aroused and taps **I’m aroused now**.
3. System recommends urge surfing, guided training, rest, or health check.
4. User performs a guided start–stop session.
5. System calculates results and adjusts the next session.
6. User follows scheduled jogging, walking, strength, breathing, and recovery tasks.
7. User reviews progress without comparing against other people.

## 5. Functional requirements

### FR-01 Onboarding

- Require 18+ confirmation.
- Explain local-only storage.
- Explain that the app is not medical diagnosis or emergency care.
- Let the user choose discreet or direct terminology.
- Offer biometric lock.

### FR-02 Baseline assessment

Collect:

- whether the change is lifelong or newly acquired;
- where difficulty occurs;
- perceived control;
- anxiety;
- sleep;
- exercise baseline;
- pornography and rushed habit patterns;
- pain and symptom red flags.

### FR-03 Automatic plan

Generate a seven-day schedule containing a safe combination of:

- guided control sessions;
- breathing or relaxation;
- cardio;
- strength;
- recovery;
- educational modules;
- weekly review.

### FR-04 Urge mode

The **I’m aroused now** flow must:

- ask intensity;
- ask trigger/context;
- ask purpose;
- check pain/injury;
- consider sessions completed recently;
- route to one of a limited set of actions.

### FR-05 Guided session

- preparation phase;
- live arousal input;
- pause threshold;
- recovery timer;
- cycle counter;
- calm/urgent haptic states;
- early completion handling;
- post-session reflection;
- hard maximum session duration.

### FR-06 Adaptive rules

Adjust:

- pause threshold;
- cycle target;
- session frequency;
- recovery duration;
- education modules;
- exercise progression;
- recovery days.

### FR-07 Progress

Display:

- awareness score;
- control score;
- recovery trend;
- tension trend;
- anxiety trend;
- adherence;
- independence level.

### FR-08 Privacy

- Local-only data.
- Biometric/PIN lock.
- Neutral notifications.
- One-tap delete all.
- Encrypted export.
- App switcher privacy cover.

### FR-09 Health safety

Immediately stop guided sexual training when red flags are reported.

## 6. Non-functional requirements

- Works in airplane mode.
- Cold launch target below 1.5 seconds on supported devices.
- Core interactions at 60/120 Hz where available.
- VoiceOver support.
- Reduce Motion support.
- Dynamic Type support.
- No network entitlements in the initial build.
- No third-party SDKs in the MVP.
- Deterministic rules with unit-test coverage above 90% for decision logic.

## 7. Out of scope

- diagnosis;
- medication recommendations;
- live clinician chat;
- pornographic content;
- camera-based erection detection;
- social feed;
- duration leaderboard;
- cloud account;
- partner identity storage;
- generative AI;
- online analytics.
