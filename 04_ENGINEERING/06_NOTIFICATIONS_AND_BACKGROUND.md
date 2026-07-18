# Local Notifications and Background Behavior

## Notification principles

Notifications are neutral and generated locally.

Allowed examples:

- “Your plan is ready.”
- “A short session is available.”
- “Time for today’s movement.”
- “Weekly review is ready.”

Forbidden examples:

- “Time to masturbate.”
- “Practice lasting longer now.”
- explicit symptom or sexual details.

## Notification categories

- DAILY_PLAN
- MOVEMENT_REMINDER
- GUIDED_SESSION_AVAILABLE
- RECOVERY_CHECK
- WEEKLY_REVIEW

## Actions

- Open
- Remind in 1 hour
- Skip today

No explicit action labels on the lock screen.

## Scheduling

Use `UNUserNotificationCenter` calendar triggers. Generate one week ahead and regenerate whenever the plan changes.

## Background work

Do not depend on precise background execution. Recalculate immediately on app launch and when the app returns to foreground. BackgroundTasks may perform opportunistic maintenance, but the plan must remain correct without it.

## Quiet hours

Default suggestion: 22:00–08:00 local time. User controls it. Critical health guidance is shown in-app, not sent as an alarming notification.
