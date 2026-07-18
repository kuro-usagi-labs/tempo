# Executive Summary

TEMPO is an offline iOS wellness coach for structured arousal-control practice and general health habits. Its strongest differentiator is not a timer. It is the combination of:

- a deterministic adaptive plan;
- guided start–stop sessions;
- an immediate “I’m aroused now” decision flow;
- exercise and recovery scheduling;
- private on-device storage;
- modern dark UI, precise motion, and haptics;
- strong medical safety boundaries.

## Why no AI is the correct choice

This product does not need a language model. The important decisions are limited, auditable, and safety-sensitive. A local rule engine is preferable because it is:

- deterministic;
- testable;
- explainable;
- fast;
- private;
- functional without internet;
- less likely to invent unsafe guidance.

The “intelligence” comes from state, history, thresholds, decision tables, and progression rules.

## Product outcome hierarchy

TEMPO should optimize, in this order:

1. **Safety** — detect reasons to stop and seek care.
2. **Reduced anxiety** — avoid performance pressure and shame.
3. **Awareness** — recognize arousal escalation earlier.
4. **Control behavior** — pause before the point of no return.
5. **Recovery skill** — return from high arousal to a manageable level.
6. **Healthy routine** — sleep, exercise, recovery, and fewer rushed habits.
7. **Independence** — gradually rely less on the app.

Duration is a secondary metric. The app must not become a stopwatch-based masculinity test.

## MVP recommendation

Build a four-week program first, with architecture ready for twelve weeks. The MVP includes:

- onboarding and adult confirmation;
- baseline assessment;
- red-flag screening;
- local schedule generator;
- urge mode;
- guided start–stop mode;
- breathing/recovery mode;
- exercise plan;
- local progress dashboard;
- neutral notifications;
- biometric lock;
- data export and deletion;
- full offline operation.
