# Local Scheduler Engine

## Responsibilities

- Generate seven-day plans.
- Respect quiet hours and preferred activity windows.
- Avoid consecutive guided sessions.
- Rebalance missed tasks.
- Progress exercise gradually.
- Recalculate after symptoms, stress, or poor recovery.

## Scheduling algorithm

1. Reserve one weekly review slot.
2. Reserve at least one full recovery day.
3. Place guided sessions 48–72 hours apart by default.
4. Place strength sessions away from reported soreness/injury.
5. Place cardio on non-guided or light-training days.
6. Add breathing on high-stress or pre-session days.
7. Add one educational module where cognitive load is low.
8. Validate constraints.
9. Store plan and neutral notification requests locally.

## Conflict resolution

Priority order:

1. Safety recovery
2. User calendar constraints entered manually
3. Sleep/stress recovery
4. Guided training spacing
5. Exercise volume
6. Education

## Missed task behavior

Never show a backlog of punishment tasks. Choose one of:

- move task to the next suitable day;
- reduce the week’s volume;
- discard low-priority content;
- keep next week unchanged if the miss was isolated.

## Suggested data structure

```swift
struct PlannedActivity: Identifiable {
    let id: UUID
    let dateWindow: DateInterval
    let kind: ActivityKind
    let priority: Int
    let estimatedMinutes: Int
    let canReschedule: Bool
    let sourceRuleID: String
}
```
