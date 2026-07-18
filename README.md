# TEMPO — iOS Offline Sexual-Wellness Training Blueprint

**Status:** Product & engineering blueprint 1.0  
**Platform:** iPhone, native SwiftUI  
**Operating model:** fully local, no AI, no account, no internet required  
**Working title:** TEMPO  
**Audience:** adults 18+

TEMPO is a private, structured training application for people who want to improve arousal awareness, reduce rushed sexual habits, build healthier routines, and practice start–stop control. The app is not pornography, is not a diagnostic device, and must not promise a cure.

The product feels “smart” through a deterministic expert system:

1. It collects a short baseline assessment.
2. It calculates readiness, safety, consistency, awareness, control, and recovery metrics.
3. It selects the next activity from a curated program.
4. It adapts thresholds and schedules according to previous sessions.
5. It stays completely on-device.

## Core product promise

> Open the app, answer honestly, and TEMPO decides the safest useful next step.

## Main user actions

- **I’m aroused now** — immediate urge check-in and routing.
- **Start guided training** — start–stop session with haptics, timers, breathing, and recovery pauses.
- **Today’s plan** — automatically selected exercise, recovery, education, or training.
- **Health check** — symptom screening and referral guidance.

## Recommended implementation

- SwiftUI
- Swift Concurrency
- Observation
- SwiftData with explicit local-only configuration
- CryptoKit + Keychain for protected secrets and export encryption
- UserNotifications for neutral local reminders
- Core Haptics for satisfying feedback
- HealthKit as an optional, permission-based fitness input
- XCTest and XCUITest
- No analytics SDK, ad SDK, cloud sync, remote config, or generative AI

## Document map

Start with:

1. `01_PRODUCT/01_PRODUCT_VISION.md`
2. `01_PRODUCT/02_PRD.md`
3. `02_PROGRAM/01_PROGRAM_12_WEEKS.md`
4. `03_ENGINE/01_RULE_ENGINE_SPEC.md`
5. `05_DESIGN/01_UI_DESIGN_SYSTEM.md`
6. `04_ENGINEERING/01_IOS_ARCHITECTURE.md`
7. `08_DELIVERY/01_IMPLEMENTATION_ROADMAP.md`

## Non-negotiable safety constraints

- Never diagnose premature ejaculation.
- Never guarantee that a user will “last longer.”
- Never treat pre-ejaculate as failure.
- Never recommend unsafe numbing products, prescription medication, or extreme edging.
- Never lock users into sexual activity to preserve a streak.
- Stop training when pain, unusual discharge, blood, fever, urinary burning, testicular pain, pelvic pain, or injury is reported.
- All explicit training content is 18+ and hidden behind discreet UI.
