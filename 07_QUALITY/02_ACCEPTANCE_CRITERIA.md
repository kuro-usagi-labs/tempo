# Acceptance Criteria

## Urge mode

- Completes in four questions or fewer.
- Produces one recommendation in under 100 ms after final input.
- Any safety flag blocks guided mode.
- Recommendation includes a reason.
- Non-safety recommendation can be overridden.

## Guided session

- Timer remains accurate after temporary interruption.
- Level threshold produces visual and haptic warning once.
- Pause begins immediately after warning or manual action.
- User cannot accidentally resume during minimum recovery interval.
- Session stops at maximum duration.
- Early ejaculation is recorded without failure copy.

## Scheduler

- Generates seven valid days.
- Never exceeds configured session maximum.
- Maintains at least one recovery day.
- Does not stack missed tasks.
- Respects quiet hours.

## Privacy

- No core feature requires internet.
- App content is hidden in app switcher.
- Notification previews are neutral.
- Data deletion is complete and verified.
- No third-party analytics package exists in dependency graph.

## Accessibility

- All primary flows work with VoiceOver.
- All primary controls support accessibility sizes.
- Reduce Motion removes nonessential movement.
- Warning meaning remains clear without color.
