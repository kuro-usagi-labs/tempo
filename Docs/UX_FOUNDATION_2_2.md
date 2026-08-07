# TEMPO 2.2 UX Foundation

Status: development branch only. This document does not authorize merging into `main`.

## Product constraints

TEMPO remains native SwiftUI, iOS 17+, deterministic, local-only, offline, account-free, analytics-free, cloud-free, and compatible with persisted 2.1.3 data. UI work must not weaken safety routing, session state machines, plan persistence, biometric privacy, encrypted export, or local notifications.

## Sitemap

- Onboarding
  - Introduction, privacy, adult confirmation
  - Goal and starting context
  - Baseline condition
  - Realistic movement
  - Habit context
  - Safety and reminders
  - Real weekly preview
- Hari Ini
  - Primary activity hero
  - Immediate action
  - Compact daily readiness
  - Additional agenda
  - Tomorrow preview
  - Deterministic insight
- Program
  - Week navigation
  - Calendar status
  - Weekly completion summary
  - Day detail
  - Plan adaptation actions
- Progres
  - Data sufficiency state
  - Real trends
  - Consistency
  - Technical score disclosure
- Pengaturan
  - Program baseline
  - Privacy
  - Session preferences
  - Reminders
  - Activity preference
  - Safety
  - Export and deletion

## Primary user flows

### Scheduled activity

Hari Ini → primary activity → compact readiness confirmation → activity → lightweight reflection → persisted completion summary → Hari Ini.

### Immediate private session

Hari Ini → immediate action sheet → private choice/intensity/safety confirmation → private ready state → active/recovery loop → progressive reflection → persisted completion summary.

### Guided session

Hari Ini or Program → readiness-aware precheck → preparation → active → warning/recovery loop → reflection → persisted completion summary.

### Safety

Any current symptom or unresolved safety hold → contextual recovery block or health check. No alternative session shortcut may bypass the block.

## Hierarchy rules

- One visual hero per screen.
- Critical and caution colors are reserved for genuine warning, safety, persistence failure, threshold, and emergency states.
- Normal high arousal is not presented as danger.
- Supporting information should use plain sections and separators before tinted cards.
- A scheduled activity must not be duplicated in the same screen unless another representation adds information.
- Session controls must remain visible without scrolling on supported compact iPhone layouts.

## Component inventory

The shared foundation is implemented in `App/TempoUXFoundation.swift`.

- `TempoScreenState`
- `TempoUserFacingError`
- `TempoScreenContainer`
- `TempoStickyActionBar`
- `TempoHeroCard`
- `TempoCompactStatusRow`
- `TempoSessionHeader`
- `TempoSessionControlBar`
- `TempoCompletionSummary`
- `TempoEmptyState`
- `TempoInlineError`
- `TempoSelectionCard`
- `TempoSegmentedChoice`
- `TempoIntensityZoneControl`
- `TempoCalendarDayCell`
- `TempoTrendCard`
- `TempoDisclosureSection`
- `TempoMotionPolicy`

Components must be driven by real state and actions. No component owns persistence or domain decisions.

## State ownership

- Domain and persisted records: `LocalHistory` and existing domain engines.
- Navigation: `TempoCoordinator`.
- Screen presentation state: screen-local SwiftUI state or small presentation models.
- Transient animation state: component-local and never persisted.
- Onboarding draft: protected local persistence, deleted only after baseline and first plan save successfully.
- Session state: existing private and guided state machines remain authoritative.

## Data-source rules

- Today hero: `todayPrimaryPlan` / persisted plan.
- Readiness: `todayReadiness` only for today's exact condition.
- Session completion: newly persisted session/private-session record, not unsaved view state.
- Program calendar: derived from persisted `plannedDays`.
- Weekly summary: existing consistency eligibility semantics.
- Progress trends: actual session, pause, recovery, readiness, and plan records; minimum three samples for directional language.
- Preview: real `WeeklyPlanGenerator`, never fixtures in production UI.

## Navigation rules

- Immediate action is presented as a single compact sheet.
- No default reset choice.
- The normal private path should require at most three interactions after the sheet appears.
- Completion screens remain visible until the user explicitly returns.
- Changing a plan requires a confirmation surface and persisted success before navigation updates.
- Draft pull requests remain unmerged until manual review.

## Motion rules

- Motion communicates selection, transition, warning, recovery, and successful persistence.
- Motion never changes timer truth or delays safety actions.
- Repeating animation pauses when the scene is inactive.
- Reduce Motion removes scale/travel effects and keeps opacity/content transitions.
- Warning and completion also use VoiceOver announcements and haptics where enabled.

## Accessibility rules

- Dynamic Type through accessibility sizes.
- Minimum control target 44 pt; active session controls 52 pt.
- Color is never the only state cue.
- Sticky controls respect safe area and keyboard.
- VoiceOver labels, values, hints, and identifiers are required for new controls.
- Compact iPhone layouts must not require scrolling to reach active session controls.

## Migration from 2.1.3

Preserve baseline, readiness, safety holds, guided sessions, private sessions, plan history, replacement linkage, exercise history, activity preference, reminder settings, biometric setting, discreet terminology, notes, and export compatibility. Numeric intensity events remain valid. New zone controls map to numeric values without rewriting historical data.

## Test plan

- Unit tests: intensity mapping, old numeric compatibility, calendar visual resolver, weekly summary, progress trends and sample thresholds, completion summary source, onboarding draft lifecycle, no default reset.
- UI tests: seven-stage onboarding and draft relaunch, quick private path, private/guided compact controls, warning/recovery/completion, Program status/actions, insufficient and real trend states, Pengaturan persistence.
- CI: domain tests, iOS unit/UI tests, compact simulator smoke launch, Release build, archive, local-only scan.

## Branch safety

Development branch: `review/tempo-v2.2.0-ux-foundation`.

Do not merge, tag, publish a release, or update `main` until the branch has been manually reviewed and explicitly approved.