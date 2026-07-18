# iOS Architecture

## Architecture choice

Use native SwiftUI with a modular Clean Architecture and unidirectional feature state. Avoid a large external framework in the MVP so the sideload build remains simple and auditable.

## Layers

### Presentation

- SwiftUI views
- feature stores/view models
- navigation coordinator
- design system
- motion and haptic orchestration

### Domain

- entities
- use cases
- rule engine
- scheduler
- scoring
- program state machine
- safety policies

### Data

- SwiftData repositories
- Keychain service
- local content loader
- HealthKit adapter
- local notification adapter
- encrypted export service

## Dependency direction

```text
Presentation → Domain ← Data implementations
```

Domain protocols must not import SwiftUI, SwiftData, HealthKit, or UserNotifications.

## Suggested feature modules

- AppShell
- Onboarding
- Assessment
- Today
- UrgeMode
- GuidedSession
- Breathing
- Exercise
- Progress
- Learn
- HealthCheck
- Settings
- PrivacyLock

## Suggested core modules

- TempoDomain
- TempoRules
- TempoScheduling
- TempoPersistence
- TempoDesignSystem
- TempoHaptics
- TempoHealthKit
- TempoNotifications

## State management

Use `@Observable` feature models, value-type state where possible, and injected protocols for side effects. Long-running timers should use a monotonic clock abstraction so tests do not rely on real time.

## Minimum OS

Recommended baseline: iOS 17 for SwiftData and modern SwiftUI APIs. Add enhanced iOS 26 design effects behind availability checks rather than making them mandatory.

## Concurrency

- `@MainActor` for UI feature models.
- actors for repositories and session recorder.
- structured concurrency only.
- cancellation-aware timers.
- no detached tasks for core business logic.
