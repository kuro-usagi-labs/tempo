# TEMPO 2.2 UX Foundation

This document defines the implementation contract for the review-only `2.2.0` UX branch. The branch must not be merged until the screenshots, accessibility pass, migration checks, and device review are accepted.

## Sitemap

- Onboarding
- Hari Ini
  - Aktivitas utama
  - Keputusan cepat
  - Readiness confirmation
- Program
  - Navigasi minggu
  - Detail aktivitas
  - Ganti dengan pemulihan
  - Pindahkan ke hari lain
- Progres
  - Tren berbasis data lokal
  - Konsistensi
  - Skor teknis sebagai disclosure
- Pengaturan
  - Program dan baseline
  - Privasi
  - Preferensi sesi
  - Pengingat
  - Preferensi aktivitas
  - Keselamatan
  - Data dan export
- Session flows
  - Private session
  - Guided session
  - Breathing/recovery
  - Cardio
  - Strength
  - Education
  - Weekly review
  - Health check

## Primary user flows

### Scheduled activity

Hari Ini → Mulai → compact readiness confirmation → session → reflection → persisted completion summary → Hari Ini.

### Quick private action

Hari Ini → Keputusan cepat → private preselected → intensity zone → no-new-symptom confirmation → start private session.

### Guided action unavailable

Keputusan cepat → guided → deterministic eligibility result → explanation → private/reset/recheck according to safety state.

### Safety

Any symptom entry → persisted safety hold → health/recovery flow → atomic recheck resolution → normal routing restored only after storage succeeds.

## Tab hierarchy

### Hari Ini

1. Compact date/program header
2. Safety notice only when active
3. Primary activity hero
4. Quick action
5. Compact readiness
6. Additional agenda only when more than one meaningful item exists
7. Tomorrow preview
8. Deterministic insight

### Program

1. Week navigation
2. Weekly adherence summary
3. Calendar cells with non-color status symbols
4. Selected-day plan
5. Weekly review

### Progres

1. Data sufficiency state
2. Trend cards from persisted records
3. Consistency
4. Optional technical score disclosure

### Pengaturan

Use disclosure sections instead of a long stack of equally weighted cards.

## Component inventory

The branch introduces or standardizes:

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

## State ownership

- Domain and scheduling state: `LocalHistory` and existing deterministic engines.
- Navigation: `TempoCoordinator`.
- Daily transient UI: screen-local `@State`.
- Persisted onboarding draft: `TempoOnboardingDraftStore`.
- Visual animation state: never persisted.
- Safety state: existing protected stores and transaction journal only.

## Data sources

- Hero activity: `LocalHistory.todayPrimaryPlan`.
- Readiness: `LocalHistory.todayReadiness`.
- Calendar: `LocalHistory.plannedDays`.
- Completion summary: the persisted `LocalSession` or `LocalPrivateSession` record, not pre-save view state.
- Trends: persisted sessions, private sessions, pause cycles, recovery seconds, readiness, and plan history.
- No trend is directional below the minimum sample count.

## Navigation rules

- `main` remains untouched during development.
- Session screens use deterministic routes already defined in `TempoRoute`.
- Plan navigation never mutates the plan merely by viewing a date.
- A replacement cannot produce another replacement.
- Safety destinations replace unsafe action destinations.

## Motion rules

- Motion communicates selection, warning, recovery, and completion only.
- Timers remain the source of truth; animation never drives elapsed time.
- All repeating motion stops when scene phase is inactive.
- Reduce Motion removes scale/pulse travel while preserving state and copy.
- Warning and success feedback use the existing haptics preference.

## Accessibility rules

- Minimum 44 pt targets; session controls target 52 pt.
- Dynamic Type through accessibility sizes.
- Status never relies on color alone.
- VoiceOver announces warning, recovery readiness, and persisted completion.
- Sticky action bars honor keyboard and safe area.
- iPhone SE layouts must not require scrolling during active private/guided controls.

## Migration from 2.1.3

No existing persisted domain record is rewritten solely for UI changes. Numeric intensity history remains valid. Five-zone controls map to existing numeric values. Onboarding draft uses a new isolated key and is removed after baseline persistence succeeds.

## Test plan

- Unit: zone mapping, calendar visual state, weekly summary, progress trend minimum samples, onboarding draft round trip, completion summary adapters.
- UI: seven-step onboarding, quick private flow, active session controls, warning/recovery, persisted completion summary, Program status cells, trend empty/content states, Pengaturan label.
- Regression: safety routing, date-aware scheduling, plan replacement, notifications, encrypted export, biometric cover, local-only scan.
