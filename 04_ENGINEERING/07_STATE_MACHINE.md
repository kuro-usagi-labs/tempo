# Program and Session State Machines

## Program state

```text
UNINITIALIZED
→ ASSESSMENT_REQUIRED
→ SAFETY_HOLD | AWARENESS
AWARENESS → BASIC_CONTROL
BASIC_CONTROL → STABILITY
STABILITY → TRANSFER
TRANSFER → INDEPENDENCE
INDEPENDENCE → MAINTENANCE
```

### Backward transitions

- Any state → SAFETY_HOLD on a red flag.
- STABILITY/TRANSFER → BASIC_CONTROL after a sustained decline.
- Any active state → RECOVERY_MICROCYCLE after irritation or high stress.

## Urge flow state

```text
IDLE
→ CHECK_INTENSITY
→ CHECK_TRIGGER
→ CHECK_INTENT
→ CHECK_SAFETY
→ RECOMMENDATION
→ ACTION_STARTED | DISMISSED
```

## Guided session state

See `03_ENGINE/06_GUIDED_SESSION_SPEC.md`.

## Transition requirements

- State changes are pure domain functions.
- Save transition reason and ruleset version.
- Invalid transitions throw domain errors in debug and become safe no-ops in release.
- Unit tests cover every allowed and forbidden transition.
