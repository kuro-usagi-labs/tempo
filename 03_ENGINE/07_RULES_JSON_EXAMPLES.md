# Rules JSON Examples

These examples describe configuration. Production code should compile typed rules and validate any JSON fixture during tests.

```json
{
  "schemaVersion": 1,
  "rulesetVersion": "1.0.0",
  "rules": [
    {
      "id": "safety.block.unusual_discharge",
      "priority": 1000,
      "all": [
        { "field": "unusualDischarge", "operator": "equals", "value": true }
      ],
      "actions": [
        { "type": "blockGuidedTraining" },
        { "type": "recommend", "value": "healthCheck" },
        { "type": "message", "value": "health.stopTraining.discharge" }
      ]
    },
    {
      "id": "urge.high.training_due",
      "priority": 500,
      "all": [
        { "field": "urgeIntensity", "operator": "gte", "value": 7 },
        { "field": "hoursSinceLastSession", "operator": "gte", "value": 24 },
        { "field": "guidedSessionsLast7Days", "operator": "lt", "value": 3 },
        { "field": "safetyClear", "operator": "equals", "value": true }
      ],
      "actions": [
        { "type": "recommend", "value": "guidedSession" },
        { "type": "setPauseThreshold", "valueFrom": "adaptivePauseThreshold" }
      ]
    },
    {
      "id": "adapt.lower_threshold_after_late_stops",
      "priority": 400,
      "all": [
        { "field": "consecutiveLateStops", "operator": "gte", "value": 2 }
      ],
      "actions": [
        { "type": "changePauseThreshold", "delta": -1, "minimum": 5 },
        { "type": "setTargetCycles", "value": 2 }
      ]
    }
  ]
}
```

## Validation requirements

- Unknown fields fail the build.
- Unknown action types fail the build.
- Priorities must be unique within a safety category.
- Safety rules must be evaluated first.
- No rule may recommend medication.
- No rule may schedule more than three guided sessions in seven days.
