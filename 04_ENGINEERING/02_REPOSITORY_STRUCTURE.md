# Repository Structure

```text
Tempo/
├── App/
│   ├── TempoApp.swift
│   ├── AppEnvironment.swift
│   ├── RootCoordinator.swift
│   └── PrivacyCoverView.swift
├── Features/
│   ├── Onboarding/
│   ├── Assessment/
│   ├── Today/
│   ├── UrgeMode/
│   ├── GuidedSession/
│   ├── Breathing/
│   ├── Exercise/
│   ├── Progress/
│   ├── Learn/
│   ├── HealthCheck/
│   └── Settings/
├── Domain/
│   ├── Models/
│   ├── UseCases/
│   ├── Rules/
│   ├── Scoring/
│   ├── Scheduling/
│   ├── Program/
│   └── Safety/
├── Data/
│   ├── Persistence/
│   ├── Repositories/
│   ├── Keychain/
│   ├── Export/
│   ├── Notifications/
│   └── HealthKit/
├── DesignSystem/
│   ├── Tokens/
│   ├── Components/
│   ├── Motion/
│   ├── Haptics/
│   └── PreviewFixtures/
├── Resources/
│   ├── Content/
│   ├── Rules/
│   ├── Audio/
│   ├── Haptics/
│   └── Localizable.xcstrings
├── Tests/
│   ├── DomainTests/
│   ├── RuleEngineTests/
│   ├── SchedulerTests/
│   ├── PersistenceTests/
│   ├── SnapshotTests/
│   └── UITests/
└── Docs/
```

## File naming

- One primary type per file.
- Features use `FeatureNameView`, `FeatureNameModel`, `FeatureNameRoute`.
- Use cases use verbs: `GenerateWeeklyPlan`, `EvaluateUrge`, `CompleteSession`.
- Domain models avoid Apple framework types when practical.
