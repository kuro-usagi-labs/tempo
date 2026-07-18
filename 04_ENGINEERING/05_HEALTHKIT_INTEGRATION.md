# Optional HealthKit Integration

HealthKit is optional and must never be required for the core app.

## Read-only data candidates

- step count;
- walking/running distance;
- workouts;
- sleep duration, where available;
- active energy, optionally.

## Uses

- verify completion of walking/jogging goals;
- reduce manual logging;
- avoid assigning intense exercise after unusually low sleep;
- show general weekly activity progress.

## Forbidden uses

- infer sexual activity;
- infer diagnosis;
- upload HealthKit data;
- use data for advertising;
- deny core functionality when permission is refused.

## Permission strategy

Ask only after the user enables fitness automation. Explain each data type before the system sheet appears.

## Local processing

- Query the minimum date range needed.
- Convert to daily aggregates.
- Avoid storing raw samples.
- Revoke local cache when the user disables integration.

## Fallback

Manual completion always exists. The scheduler must operate fully without HealthKit.
