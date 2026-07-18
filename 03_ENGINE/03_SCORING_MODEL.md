# Scoring Model

Scores are private coaching indicators, not medical measurements.

## Awareness Score — 0 to 100

Inputs:

- proportion of pauses initiated before “almost too late”;
- consistency of arousal-level logging;
- ability to identify tension;
- reduction in unexpected escalation.

Suggested calculation:

```text
awareness =
  earlyPauseRate * 50
  + loggingCompleteness * 20
  + tensionRecognitionRate * 15
  + escalationPredictionRate * 15
```

Use an exponentially weighted moving average so one bad session does not collapse the score.

## Control Score — 0 to 100

```text
control =
  successfulCycleRatio * 45
  + controlledCompletionRatio * 20
  + thresholdCompliance * 20
  + recoveryCompletionRatio * 15
```

Do not include raw ejaculation duration as more than an optional secondary trend.

## Recovery Score — 0 to 100

Based on the ability to reduce reported arousal after a pause. Normalize by the user’s own baseline, not population norms.

## Calm Score — 0 to 100

Derived from pre-session anxiety, post-session tension, breath completion, and trend stability.

## Consistency Score — 0 to 100

Reward following the plan, including rest. A completed recovery day counts as adherence.

## Independence Level

- 0: Full visual and audio guidance
- 1: Reduced text prompts
- 2: Haptic-first mode
- 3: Timer hidden
- 4: Self-directed session with post-check only

## Anti-gaming rules

- Additional unscheduled sessions do not increase score.
- Longer sessions do not automatically increase score.
- Repeating sessions after an early completion does not restore points.
- Rest adherence is positively scored.
