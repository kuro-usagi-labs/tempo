# Deterministic Rule Engine Specification

## Objective

Make TEMPO feel intelligent without AI. The engine receives local facts, evaluates ordered rules, and returns a recommendation with a human-readable reason.

## Design

Use three layers:

1. **Safety gate** — highest priority; can block training.
2. **Readiness evaluator** — determines rest, regulation, exercise, or training.
3. **Progression evaluator** — adjusts future targets and schedules.

## Required inputs

```swift
struct DecisionContext {
    let now: Date
    let programPhase: ProgramPhase
    let urgeIntensity: Int
    let trigger: UrgeTrigger?
    let userIntent: UrgeIntent?
    let pain: Bool
    let irritation: Bool
    let urinaryBurning: Bool
    let unusualDischarge: Bool
    let bloodReported: Bool
    let pelvicOrTesticularPain: Bool
    let fever: Bool
    let anxiety: Int
    let sleepHours: Double?
    let hoursSinceLastSession: Double?
    let guidedSessionsLast7Days: Int
    let exerciseMinutesLast7Days: Int
    let consecutiveLateStops: Int
    let successfulCyclesRecent: [Int]
    let missedTasksLast7Days: Int
}
```

## Required outputs

```swift
struct Recommendation {
    let action: RecommendedAction
    let severity: RecommendationSeverity
    let reasonCode: String
    let userMessageKey: String
    let parameters: [String: Double]
    let blocksGuidedTraining: Bool
}
```

## Rule priority

1. Emergency or urgent symptom guidance
2. Medical assessment recommendation
3. Injury/irritation recovery
4. Overtraining protection
5. High-anxiety regulation
6. Scheduled guided session
7. Urge-surfing recommendation
8. Exercise recommendation
9. Education/review
10. User override with warnings

## Example rule

```swift
Rule(
    id: "SAFETY_URINARY_DISCHARGE",
    priority: 1000,
    predicate: { $0.urinaryBurning || $0.unusualDischarge },
    result: Recommendation(
        action: .healthCheck,
        severity: .medical,
        reasonCode: "urinary_or_discharge_symptoms",
        userMessageKey: "health.stopTraining.urinary",
        parameters: [:],
        blocksGuidedTraining: true
    )
)
```

## Explainability

Every recommendation must expose:

- what was recommended;
- why it was recommended;
- when the system will reassess;
- whether the user can override;
- what warning signs require professional care.

## Determinism

Given identical context and ruleset version, the output must be identical. Save `rulesetVersion` on every recommendation and session record.

## Versioning

Rules are compiled in the app. A local JSON representation may be used for configuration, but must be validated against a strict schema at build time. No remote rule updates in the offline version.
