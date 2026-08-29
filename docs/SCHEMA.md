# DocuLens — Canonical Inspection Data Schema

> **Current MVP schema**
>
> This document defines the structured inspection data used by the DocuLens backend and UI. It is intentionally focused on the fields demonstrated by the current prototype.

## 1. Pipeline

```text
Image / Manual Text
        ↓
Gemini extraction
        ↓
Structured inspection data
        ↓
Deterministic validation + risk rules
        ↓
Supabase persistence
        ↓
Flutter result/history UI
```

## 2. Core Inspection Object

Conceptual JSON:

```json
{
  "machine_id": "pump-03",
  "inspection_date": null,
  "worker_name": null,
  "readings": [],
  "detected_issues": [],
  "recommended_actions": [],
  "next_inspection": null,
  "raw_observation": "machine: pump-03\ntemperature: 820 C\nVibration: High\noil: Unknown",
  "risk_priority": "HIGH",
  "created_at": "..."
}
```

The exact JSON returned by the running backend is the implementation authority. This document describes the intended/current data contract and should be updated when the backend model changes.

## 3. Reading

A reading represents one extracted operational observation.

```json
{
  "parameter": "temperature",
  "value": 820,
  "unit": "°C",
  "status": "CRITICAL"
}
```

### Supported parameters

The current schema can represent:

```text
temperature
vibration
oil_level
filter
pressure
noise
wear
leak
humidity
rpm
flow_rate
voltage
current
other
```

### Supported status values

```text
NORMAL
LOW
HIGH
CRITICAL
REPLACEMENT_REQUIRED
LEAK_DETECTED
WORN
UNKNOWN
```

### Optional extraction metadata

When available in the backend, a reading may also contain:

```json
{
  "confidence": 0.92,
  "is_uncertain": false,
  "uncertainty_reason": null,
  "raw_fragment": "temp 82"
}
```

These fields are useful for traceability, but the Flutter UI does not need to display every internal extraction field.

## 4. Detected Issue

```json
{
  "description": "High vibration detected",
  "severity": "HIGH",
  "source_readings": ["vibration"]
}
```

Severity:

```text
LOW
MEDIUM
HIGH
CRITICAL
```

An issue should be supported by information present in the observation/extracted readings.

## 5. Recommended Action

```json
{
  "action": "Inspect machine immediately and re-verify temperature with calibrated thermometer",
  "priority": "HIGH",
  "related_issues": [
    "Extremely high or abnormal temperature reading"
  ]
}
```

The recommendation should be traceable to the detected condition rather than invented independently of the observation.

## 6. Risk Priority

The inspection receives an overall priority:

```text
LOW
MEDIUM
HIGH
CRITICAL
```

The priority is determined by deterministic backend rules using extracted conditions.

Example:

```text
temperature = CRITICAL
vibration = HIGH
        ↓
overall risk = HIGH / CRITICAL
```

The exact threshold/weight values are implementation details and should match the active validation service.

## 7. Maintenance Task

A maintenance task is created from an inspection recommendation.

Conceptual object:

```json
{
  "task_number": 14,
  "inspection_id": "uuid",
  "machine_id": "pump-03",
  "priority": "HIGH",
  "status": "OPEN",
  "action": "Inspect machine immediately and re-verify temperature with calibrated thermometer",
  "created_at": "..."
}
```

### Task status

The demonstrated prototype uses:

```text
OPEN
```

The backend may support additional lifecycle states if they are implemented. Do not claim CLOSED or IN_PROGRESS support unless those states exist in the active code.

## 8. Inspection History

History records allow the app to display previously processed inspections.

A history entry needs enough information to show:

```text
machine
risk priority
date/time
```

The current UI demonstrates entries such as:

```text
pump-03 · HIGH
29/8/2026 · 09:58
```

and:

```text
M104 · CRITICAL
29/8/2026 · 09:57
```

## 9. Task History

Task history displays:

```text
Task #14 · pump-03
HIGH · OPEN
Inspect machine immediately and re-verify temperature...
```

and similar previously generated tasks.

## 10. Data Integrity Rules

### Rule 1 — Do not invent missing values

If the observation does not provide a value:

```json
"value": null
```

or the corresponding status should be:

```text
UNKNOWN
```

where appropriate.

### Rule 2 — Preserve suspicious values

If the source says:

```text
820 C
```

the extraction should preserve `820`, not silently convert it to `82`.

Validation can then flag it as abnormal.

### Rule 3 — Separate extraction from validation

```text
Gemini
  → extraction / normalization

Python rules
  → validation / risk / priority
```

### Rule 4 — Recommendations must be grounded

A maintenance action should be connected to the extracted issue/readings.

## 11. Current Demonstrated Data

### Pump-03 risky observation

```text
machine: pump-03
temperature: 820 C
Vibration: High
oil: Unknown
```

Displayed structured result:

```text
Machine       pump-03
Temperature   820.0 °C · CRITICAL
Vibration     HIGH
Oil           UNKNOWN
Filter        Not recorded
Next inspect  Not scheduled
Worker        Not identified
```

Risk/result:

```text
HIGH PRIORITY

- Extremely high or abnormal temperature reading
- High vibration level detected

Recommended action:
Inspect machine immediately and re-verify
temperature with calibrated thermometer
```

### M104 maintenance observation

The prototype also demonstrates an M104 inspection with a normal temperature reading, high vibration, normal oil, and a filter replacement requirement, followed by creation of a maintenance task.

## 12. Database Mapping

The logical data model is:

```text
inspections
    │
    ├── readings
    │
    └── tasks
```

A relational implementation may use:

### inspections

```text
id
machine_id
inspection_date
worker_name
raw_observation
next_inspection
risk_priority
detected_issues
recommended_actions
created_at
```

### readings

```text
id
inspection_id
parameter
parameter_label
value
unit
status
confidence
is_uncertain
uncertainty_reason
raw_fragment
```

### tasks

```text
id
task_number
inspection_id
machine_id
priority
status
action/title
created_at
updated_at
```

The exact column names must match the active Supabase migration/schema.

## 13. Schema Maintenance Rule

This document must remain synchronized with:

1. the actual FastAPI/Pydantic models,
2. the active Supabase schema/migrations, and
3. the Flutter models/API parsing.

If any of those change, update this document.

**Do not document planned fields, endpoints, or behaviors as implemented features.**
