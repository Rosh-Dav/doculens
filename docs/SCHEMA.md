# DocuLens — Canonical Inspection Extraction Schema

This document defines the **single source of truth** for the structured data format that flows through the entire DocuLens pipeline:

```
Gemini API output → Pydantic validation → Risk engine → Supabase → Flutter UI
```

> [!IMPORTANT]
> **Core invariant**: The extraction model must **never invent information** not present in the source input. Missing fields must be `null`, not guessed. Uncertain values must be flagged with low confidence and a warning.

---

## 1. JSON Schema

This schema is used in two places:
- **Gemini API**: passed as `response_schema` for structured output
- **Pydantic**: mirrored as Python models for server-side validation

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "DocuLensInspectionExtraction",
  "description": "Structured extraction result from a field observation image or text.",
  "type": "object",
  "required": ["readings", "metadata"],
  "properties": {

    "machine_id": {
      "type": ["string", "null"],
      "description": "Identified machine or equipment ID (e.g., M104, PUMP-3, Unit 7). Null if not identifiable from the input."
    },

    "inspection_date": {
      "type": ["string", "null"],
      "description": "Inspection date extracted from the observation in ISO 8601 format (YYYY-MM-DD). Null if not mentioned. Use relative terms literally if no absolute date (e.g., 'today' → null, let backend resolve)."
    },

    "worker_name": {
      "type": ["string", "null"],
      "description": "Name of the worker/inspector if mentioned. Null if not identifiable."
    },

    "readings": {
      "type": "array",
      "description": "All extracted measurements and condition observations.",
      "items": {
        "$ref": "#/$defs/Reading"
      }
    },

    "detected_issues": {
      "type": "array",
      "description": "Specific problems, faults, or anomalies identified in the observation.",
      "items": {
        "$ref": "#/$defs/DetectedIssue"
      }
    },

    "recommended_actions": {
      "type": "array",
      "description": "Actions the AI recommends based on the extracted data. Must be directly supported by the readings and issues — never speculative.",
      "items": {
        "$ref": "#/$defs/RecommendedAction"
      }
    },

    "next_inspection": {
      "type": ["string", "null"],
      "description": "Next inspection schedule as mentioned in the observation. Preserved as free text (e.g., 'next week', '2026-09-03', 'after filter change'). Null if not mentioned."
    },

    "raw_observation": {
      "type": ["string", "null"],
      "description": "The full original text as read from the image or as provided by the user. For image inputs, this is the OCR transcription."
    },

    "metadata": {
      "$ref": "#/$defs/ExtractionMetadata"
    }
  },

  "$defs": {

    "Reading": {
      "type": "object",
      "required": ["parameter", "status", "confidence", "raw_fragment"],
      "properties": {
        "parameter": {
          "type": "string",
          "enum": [
            "temperature",
            "vibration",
            "oil_level",
            "filter",
            "pressure",
            "noise",
            "wear",
            "leak",
            "humidity",
            "rpm",
            "flow_rate",
            "voltage",
            "current",
            "other"
          ],
          "description": "Standardized parameter name."
        },
        "parameter_label": {
          "type": ["string", "null"],
          "description": "Human-readable label when parameter is 'other' (e.g., 'coolant_level'). Null for standard parameters."
        },
        "value": {
          "type": ["number", "null"],
          "description": "Numeric measurement value. Null if the observation is qualitative only (e.g., 'oil ok')."
        },
        "unit": {
          "type": ["string", "null"],
          "enum": ["°C", "°F", "bar", "psi", "mm", "RPM", "V", "A", "L/min", "%", null],
          "description": "Unit of measurement. Null if not applicable or not specified."
        },
        "status": {
          "type": "string",
          "enum": [
            "NORMAL",
            "LOW",
            "HIGH",
            "CRITICAL",
            "REPLACEMENT_REQUIRED",
            "LEAK_DETECTED",
            "WORN",
            "UNKNOWN"
          ],
          "description": "Normalized condition status."
        },
        "confidence": {
          "type": "number",
          "minimum": 0.0,
          "maximum": 1.0,
          "description": "Extraction confidence. 1.0 = certain, 0.0 = pure guess. Values below 0.7 trigger user confirmation."
        },
        "is_uncertain": {
          "type": "boolean",
          "description": "True if the AI is not confident in this extraction and the user should verify it."
        },
        "uncertainty_reason": {
          "type": ["string", "null"],
          "description": "Human-readable explanation of why this value is uncertain (e.g., 'Handwriting illegible', 'Value seems unusually high'). Null if is_uncertain is false."
        },
        "raw_fragment": {
          "type": "string",
          "description": "The exact text fragment this reading was extracted from."
        }
      }
    },

    "DetectedIssue": {
      "type": "object",
      "required": ["description", "severity", "source_readings", "confidence"],
      "properties": {
        "description": {
          "type": "string",
          "description": "Concise description of the detected issue."
        },
        "severity": {
          "type": "string",
          "enum": ["LOW", "MEDIUM", "HIGH", "CRITICAL"],
          "description": "Severity level of the issue."
        },
        "source_readings": {
          "type": "array",
          "items": { "type": "string" },
          "description": "List of parameter names that contribute to this issue (e.g., ['vibration', 'filter'])."
        },
        "confidence": {
          "type": "number",
          "minimum": 0.0,
          "maximum": 1.0,
          "description": "Confidence that this issue genuinely exists based on the input data."
        }
      }
    },

    "RecommendedAction": {
      "type": "object",
      "required": ["action", "priority", "related_issues"],
      "properties": {
        "action": {
          "type": "string",
          "description": "Specific, actionable recommendation."
        },
        "priority": {
          "type": "string",
          "enum": ["LOW", "MEDIUM", "HIGH", "CRITICAL"],
          "description": "Priority level for this action."
        },
        "related_issues": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Issue descriptions this action addresses."
        }
      }
    },

    "ExtractionMetadata": {
      "type": "object",
      "required": ["overall_confidence", "field_count", "uncertain_field_count"],
      "properties": {
        "overall_confidence": {
          "type": "number",
          "minimum": 0.0,
          "maximum": 1.0,
          "description": "Weighted average confidence across all extracted fields."
        },
        "field_count": {
          "type": "integer",
          "description": "Total number of readings extracted."
        },
        "uncertain_field_count": {
          "type": "integer",
          "description": "Number of readings flagged as uncertain."
        },
        "extraction_notes": {
          "type": ["string", "null"],
          "description": "Any additional notes about the extraction process (e.g., 'Image was partially obscured', 'Multiple machines mentioned — extracted first only')."
        }
      }
    }
  }
}
```

---

## 2. Example: Valid JSON (Primary Demo Scenario)

**Input text**:
> "M104 checked today. temp 82, vib high. oil ok. filter needs changing. check again next week."

**Expected output**:

```json
{
  "machine_id": "M104",
  "inspection_date": null,
  "worker_name": null,
  "readings": [
    {
      "parameter": "temperature",
      "parameter_label": null,
      "value": 82,
      "unit": "°C",
      "status": "NORMAL",
      "confidence": 0.92,
      "is_uncertain": false,
      "uncertainty_reason": null,
      "raw_fragment": "temp 82"
    },
    {
      "parameter": "vibration",
      "parameter_label": null,
      "value": null,
      "unit": null,
      "status": "HIGH",
      "confidence": 0.94,
      "is_uncertain": false,
      "uncertainty_reason": null,
      "raw_fragment": "vib high"
    },
    {
      "parameter": "oil_level",
      "parameter_label": null,
      "value": null,
      "unit": null,
      "status": "NORMAL",
      "confidence": 0.91,
      "is_uncertain": false,
      "uncertainty_reason": null,
      "raw_fragment": "oil ok"
    },
    {
      "parameter": "filter",
      "parameter_label": null,
      "value": null,
      "unit": null,
      "status": "REPLACEMENT_REQUIRED",
      "confidence": 0.93,
      "is_uncertain": false,
      "uncertainty_reason": null,
      "raw_fragment": "filter needs changing"
    }
  ],
  "detected_issues": [
    {
      "description": "High vibration detected on M104",
      "severity": "HIGH",
      "source_readings": ["vibration"],
      "confidence": 0.94
    },
    {
      "description": "Filter requires replacement on M104",
      "severity": "MEDIUM",
      "source_readings": ["filter"],
      "confidence": 0.93
    }
  ],
  "recommended_actions": [
    {
      "action": "Inspect M104 for vibration source — check mounting bolts, alignment, and bearings.",
      "priority": "HIGH",
      "related_issues": ["High vibration detected on M104"]
    },
    {
      "action": "Replace filter on M104.",
      "priority": "MEDIUM",
      "related_issues": ["Filter requires replacement on M104"]
    }
  ],
  "next_inspection": "next week",
  "raw_observation": "M104 checked today. temp 82, vib high. oil ok. filter needs changing. check again next week.",
  "metadata": {
    "overall_confidence": 0.925,
    "field_count": 4,
    "uncertain_field_count": 0,
    "extraction_notes": null
  }
}
```

---

## 3. Example: Ambiguous Input → Expected JSON

**Input text**:
> "Chkd pump 3 — temp 820, shaking bad, oil ??, fltr ok maybe. — R. Singh"

This input has several ambiguities:
- **820°C temperature** — likely a misread of 82.0°C (physically implausible for most equipment)
- **"shaking bad"** — informal language for vibration
- **"oil ??"** — worker themselves was uncertain
- **"fltr ok maybe"** — uncertain filter condition
- **"R. Singh"** — worker name

**Expected output**:

```json
{
  "machine_id": "PUMP-3",
  "inspection_date": null,
  "worker_name": "R. Singh",
  "readings": [
    {
      "parameter": "temperature",
      "parameter_label": null,
      "value": 820,
      "unit": "°C",
      "status": "CRITICAL",
      "confidence": 0.35,
      "is_uncertain": true,
      "uncertainty_reason": "820°C is unusually high for standard equipment. Possible misread — did you mean 82.0°C?",
      "raw_fragment": "temp 820"
    },
    {
      "parameter": "vibration",
      "parameter_label": null,
      "value": null,
      "unit": null,
      "status": "HIGH",
      "confidence": 0.88,
      "is_uncertain": false,
      "uncertainty_reason": null,
      "raw_fragment": "shaking bad"
    },
    {
      "parameter": "oil_level",
      "parameter_label": null,
      "value": null,
      "unit": null,
      "status": "UNKNOWN",
      "confidence": 0.30,
      "is_uncertain": true,
      "uncertainty_reason": "Worker indicated uncertainty about oil level ('??'). Manual verification required.",
      "raw_fragment": "oil ??"
    },
    {
      "parameter": "filter",
      "parameter_label": null,
      "value": null,
      "unit": null,
      "status": "NORMAL",
      "confidence": 0.45,
      "is_uncertain": true,
      "uncertainty_reason": "Worker expressed doubt about filter condition ('ok maybe'). Recommend physical inspection.",
      "raw_fragment": "fltr ok maybe"
    }
  ],
  "detected_issues": [
    {
      "description": "Temperature reading of 820°C appears anomalous — possible data entry error",
      "severity": "CRITICAL",
      "source_readings": ["temperature"],
      "confidence": 0.35
    },
    {
      "description": "High vibration (shaking) detected on PUMP-3",
      "severity": "HIGH",
      "source_readings": ["vibration"],
      "confidence": 0.88
    },
    {
      "description": "Oil level could not be determined — worker was uncertain",
      "severity": "MEDIUM",
      "source_readings": ["oil_level"],
      "confidence": 0.30
    }
  ],
  "recommended_actions": [
    {
      "action": "Verify temperature reading on PUMP-3 — 820°C is likely a data entry error. Re-measure manually.",
      "priority": "CRITICAL",
      "related_issues": ["Temperature reading of 820°C appears anomalous — possible data entry error"]
    },
    {
      "action": "Inspect PUMP-3 for vibration source. Check mounting, alignment, and bearings.",
      "priority": "HIGH",
      "related_issues": ["High vibration (shaking) detected on PUMP-3"]
    },
    {
      "action": "Check oil level on PUMP-3 manually and top up if necessary.",
      "priority": "MEDIUM",
      "related_issues": ["Oil level could not be determined — worker was uncertain"]
    }
  ],
  "next_inspection": null,
  "raw_observation": "Chkd pump 3 — temp 820, shaking bad, oil ??, fltr ok maybe. — R. Singh",
  "metadata": {
    "overall_confidence": 0.495,
    "field_count": 4,
    "uncertain_field_count": 3,
    "extraction_notes": "Multiple uncertain readings detected. 3 of 4 fields require user verification."
  }
}
```

> [!NOTE]
> Key behaviors demonstrated:
> - Temperature 820°C is **preserved as-is** (not corrected to 82.0) but flagged with low confidence and a clear warning
> - Oil `"??"` maps to `UNKNOWN` status, not guessed
> - Filter `"ok maybe"` maps to `NORMAL` but with low confidence and `is_uncertain: true`
> - Worker name `"R. Singh"` extracted correctly
> - Informal `"pump 3"` normalized to `"PUMP-3"`
> - `"shaking bad"` correctly mapped to vibration HIGH

---

## 4. Pydantic Models

These models are the Python-side mirror of the JSON Schema. They will live in `backend/app/models/inspection.py`.

```python
"""
DocuLens canonical inspection extraction models.

These Pydantic models define the structured output from the Gemini extraction
layer and are used throughout the backend pipeline:
  Gemini response → Pydantic parsing → validation engine → Supabase → API response
"""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator, model_validator


# ──────────────────────────────────────────────
#  Enums
# ──────────────────────────────────────────────

class Parameter(str, Enum):
    """Standardized measurement/condition parameter names."""
    TEMPERATURE = "temperature"
    VIBRATION = "vibration"
    OIL_LEVEL = "oil_level"
    FILTER = "filter"
    PRESSURE = "pressure"
    NOISE = "noise"
    WEAR = "wear"
    LEAK = "leak"
    HUMIDITY = "humidity"
    RPM = "rpm"
    FLOW_RATE = "flow_rate"
    VOLTAGE = "voltage"
    CURRENT = "current"
    OTHER = "other"


class Status(str, Enum):
    """Normalized condition status values."""
    NORMAL = "NORMAL"
    LOW = "LOW"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"
    REPLACEMENT_REQUIRED = "REPLACEMENT_REQUIRED"
    LEAK_DETECTED = "LEAK_DETECTED"
    WORN = "WORN"
    UNKNOWN = "UNKNOWN"


class Severity(str, Enum):
    """Issue and action severity/priority levels."""
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class Unit(str, Enum):
    """Supported measurement units."""
    CELSIUS = "°C"
    FAHRENHEIT = "°F"
    BAR = "bar"
    PSI = "psi"
    MM = "mm"
    RPM = "RPM"
    VOLT = "V"
    AMP = "A"
    LITERS_PER_MIN = "L/min"
    PERCENT = "%"


# ──────────────────────────────────────────────
#  Core extraction models (Gemini output)
# ──────────────────────────────────────────────

class Reading(BaseModel):
    """A single measurement or condition observation."""

    parameter: Parameter
    parameter_label: Optional[str] = Field(
        default=None,
        description="Human-readable label when parameter is 'other'.",
    )
    value: Optional[float] = Field(
        default=None,
        description="Numeric measurement value. None if qualitative only.",
    )
    unit: Optional[Unit] = Field(
        default=None,
        description="Unit of measurement. None if not applicable.",
    )
    status: Status
    confidence: float = Field(
        ge=0.0, le=1.0,
        description="Extraction confidence. Below 0.7 triggers user confirmation.",
    )
    is_uncertain: bool = Field(
        default=False,
        description="True if the user should verify this extraction.",
    )
    uncertainty_reason: Optional[str] = Field(
        default=None,
        description="Why this value is uncertain. Required when is_uncertain is True.",
    )
    raw_fragment: str = Field(
        description="Exact source text this reading was extracted from.",
    )

    @model_validator(mode="after")
    def check_uncertainty_consistency(self) -> "Reading":
        """If confidence < 0.7, auto-flag as uncertain."""
        if self.confidence < 0.7 and not self.is_uncertain:
            self.is_uncertain = True
        if self.is_uncertain and not self.uncertainty_reason:
            self.uncertainty_reason = "Low confidence extraction. Please verify."
        return self

    @field_validator("parameter_label")
    @classmethod
    def label_required_for_other(cls, v: Optional[str], info) -> Optional[str]:
        """parameter_label is required when parameter is 'other'."""
        if info.data.get("parameter") == Parameter.OTHER and not v:
            raise ValueError("parameter_label is required when parameter is 'other'")
        return v


class DetectedIssue(BaseModel):
    """A specific problem or anomaly identified from the readings."""

    description: str = Field(
        description="Concise description of the detected issue.",
    )
    severity: Severity
    source_readings: list[str] = Field(
        description="Parameter names that contribute to this issue.",
    )
    confidence: float = Field(
        ge=0.0, le=1.0,
        description="Confidence that this issue genuinely exists.",
    )


class RecommendedAction(BaseModel):
    """An actionable recommendation based on detected issues."""

    action: str = Field(
        description="Specific, actionable recommendation.",
    )
    priority: Severity
    related_issues: list[str] = Field(
        description="Issue descriptions this action addresses.",
    )


class ExtractionMetadata(BaseModel):
    """Metadata about the extraction process."""

    overall_confidence: float = Field(
        ge=0.0, le=1.0,
        description="Weighted average confidence across all readings.",
    )
    field_count: int = Field(
        ge=0,
        description="Total number of readings extracted.",
    )
    uncertain_field_count: int = Field(
        ge=0,
        description="Number of readings flagged as uncertain.",
    )
    extraction_notes: Optional[str] = Field(
        default=None,
        description="Additional notes about the extraction process.",
    )


class InspectionExtraction(BaseModel):
    """
    Root model: the complete structured extraction from a field observation.

    This is the canonical schema returned by the Gemini extraction service
    and consumed by the validation engine.
    """

    machine_id: Optional[str] = Field(
        default=None,
        description="Machine or equipment identifier. None if not identifiable.",
    )
    inspection_date: Optional[str] = Field(
        default=None,
        description="Inspection date in ISO 8601 (YYYY-MM-DD). None if not mentioned.",
    )
    worker_name: Optional[str] = Field(
        default=None,
        description="Inspector name if mentioned.",
    )
    readings: list[Reading] = Field(
        description="All extracted measurements and conditions.",
    )
    detected_issues: list[DetectedIssue] = Field(
        default_factory=list,
        description="Problems and anomalies identified.",
    )
    recommended_actions: list[RecommendedAction] = Field(
        default_factory=list,
        description="Recommended actions based on detected issues.",
    )
    next_inspection: Optional[str] = Field(
        default=None,
        description="Next inspection schedule as free text.",
    )
    raw_observation: Optional[str] = Field(
        default=None,
        description="Full original text / OCR transcription.",
    )
    metadata: ExtractionMetadata


# ──────────────────────────────────────────────
#  Validation warning (generated by validation engine, not Gemini)
# ──────────────────────────────────────────────

class ValidationWarning(BaseModel):
    """A warning generated by the deterministic validation engine."""
    field: str
    message: str
    severity: Severity = Severity.MEDIUM


# ──────────────────────────────────────────────
#  API response models (extends extraction with server-side fields)
# ──────────────────────────────────────────────

class ReadingResponse(Reading):
    """Reading with server-side fields added after persistence."""
    id: uuid.UUID
    confirmed: bool = False


class InspectionResponse(BaseModel):
    """Full API response for a processed inspection."""
    inspection_id: uuid.UUID
    machine_id: Optional[str]
    inspection_date: Optional[str]
    worker_name: Optional[str]
    readings: list[ReadingResponse]
    detected_issues: list[DetectedIssue]
    recommended_actions: list[RecommendedAction]
    risk_priority: Severity
    next_inspection: Optional[str]
    raw_observation: Optional[str]
    metadata: ExtractionMetadata
    warnings: list[ValidationWarning] = Field(default_factory=list)
    created_at: datetime


class ReadingConfirmation(BaseModel):
    """User confirmation/correction of a single reading."""
    parameter: Parameter
    value: Optional[float] = None
    unit: Optional[Unit] = None
    status: Status
    confirmed: bool = True
```

---

## 5. Validation Rules

The validation engine runs **after** Gemini extraction and **before** persistence. It is purely deterministic — no LLM calls.

### 5.1 Range Validation

Physical plausibility checks on numeric values:

| Parameter     | Min   | Max    | Warn Low | Warn High | Unit |
|---------------|-------|--------|----------|-----------|------|
| `temperature` | -50   | 500    | -10      | 100       | °C   |
| `pressure`    | 0     | 1000   | —        | 300       | bar  |
| `humidity`    | 0     | 100    | 10       | 95        | %    |
| `rpm`         | 0     | 50000  | —        | 10000     | RPM  |
| `voltage`     | 0     | 100000 | —        | 480       | V    |
| `current`     | 0     | 10000  | —        | 100       | A    |
| `flow_rate`   | 0     | 10000  | —        | 1000      | L/min|

```python
RANGE_RULES: dict[str, dict] = {
    "temperature": {"min": -50, "max": 500, "warn_low": -10, "warn_high": 100},
    "pressure":    {"min": 0,   "max": 1000, "warn_high": 300},
    "humidity":    {"min": 0,   "max": 100,  "warn_low": 10, "warn_high": 95},
    "rpm":         {"min": 0,   "max": 50000, "warn_high": 10000},
    "voltage":     {"min": 0,   "max": 100000, "warn_high": 480},
    "current":     {"min": 0,   "max": 10000, "warn_high": 100},
    "flow_rate":   {"min": 0,   "max": 10000, "warn_high": 1000},
}
```

**Logic**:
```
for each reading with a numeric value:
  rule = RANGE_RULES.get(reading.parameter)
  if rule:
    if value < rule.min or value > rule.max:
      → override confidence to min(confidence, 0.3)
      → set is_uncertain = True
      → add warning: "Value {value} is outside plausible range [{min}, {max}]"
    elif value >= rule.warn_high:
      → add warning: "Value {value} is above warning threshold ({warn_high})"
    elif value <= rule.warn_low:
      → add warning: "Value {value} is below warning threshold ({warn_low})"
```

### 5.2 Status-Based Risk Rules

Which statuses are considered critical for risk scoring:

| Parameter   | Risk Statuses                           | Weight |
|-------------|------------------------------------------|--------|
| `vibration` | HIGH, CRITICAL                          | 2      |
| `temperature` | HIGH, CRITICAL                        | 2      |
| `oil_level` | LOW, CRITICAL                           | 2      |
| `filter`    | REPLACEMENT_REQUIRED                    | 1      |
| `leak`      | LEAK_DETECTED                           | 3      |
| `pressure`  | HIGH, CRITICAL, LOW                     | 2      |
| `noise`     | HIGH, CRITICAL                          | 1      |
| `wear`      | WORN, CRITICAL                          | 1      |
| *any*       | UNKNOWN (if uncertain)                  | 0.5    |

```python
RISK_WEIGHTS: dict[str, dict] = {
    "vibration":   {"risk_statuses": ["HIGH", "CRITICAL"], "weight": 2},
    "temperature": {"risk_statuses": ["HIGH", "CRITICAL"], "weight": 2},
    "oil_level":   {"risk_statuses": ["LOW", "CRITICAL"], "weight": 2},
    "filter":      {"risk_statuses": ["REPLACEMENT_REQUIRED"], "weight": 1},
    "leak":        {"risk_statuses": ["LEAK_DETECTED"], "weight": 3},
    "pressure":    {"risk_statuses": ["HIGH", "CRITICAL", "LOW"], "weight": 2},
    "noise":       {"risk_statuses": ["HIGH", "CRITICAL"], "weight": 1},
    "wear":        {"risk_statuses": ["WORN", "CRITICAL"], "weight": 1},
}
```

### 5.3 Risk Priority Calculation

```python
def calculate_risk_priority(readings: list[Reading]) -> tuple[Severity, list[str]]:
    risk_score = 0.0
    reasons = []

    for reading in readings:
        rule = RISK_WEIGHTS.get(reading.parameter)
        if rule and reading.status in rule["risk_statuses"]:
            risk_score += rule["weight"]
            reasons.append(
                f"{reading.parameter.replace('_', ' ').title()}: "
                f"{reading.status} detected"
            )
        if reading.status == "UNKNOWN" and reading.is_uncertain:
            risk_score += 0.5
            reasons.append(
                f"{reading.parameter.replace('_', ' ').title()}: "
                f"Unknown — requires verification"
            )

    if risk_score >= 5:
        return Severity.CRITICAL, reasons
    elif risk_score >= 3:
        return Severity.HIGH, reasons
    elif risk_score >= 1:
        return Severity.MEDIUM, reasons
    else:
        return Severity.LOW, reasons
```

### 5.4 Confidence Threshold Rules

| Condition                         | Action                                               |
|-----------------------------------|------------------------------------------------------|
| `confidence < 0.7`               | Set `is_uncertain = True`, flag for user confirmation |
| `confidence < 0.4`               | Add `WARNING` severity validation warning             |
| All readings `confidence < 0.5`  | Add extraction-level note: "Low quality extraction"   |
| `uncertain_field_count > field_count / 2` | Add note: "Majority of fields require verification" |

### 5.5 Cross-Field Consistency Checks

```python
CROSS_FIELD_CHECKS = [
    {
        "name": "high_temp_with_normal_vibration",
        "condition": lambda readings: (
            any(r.parameter == "temperature" and r.status in ("HIGH", "CRITICAL") for r in readings)
            and any(r.parameter == "vibration" and r.status == "NORMAL" for r in readings)
        ),
        "warning": "High temperature with normal vibration is unusual. Verify both readings.",
        "severity": "MEDIUM",
    },
    {
        "name": "critical_with_no_next_inspection",
        # This check needs next_inspection passed separately
        "warning": "Critical reading detected but no follow-up inspection scheduled.",
        "severity": "HIGH",
    },
]
```

### 5.6 Complete Validation Pipeline

```
validate(extraction: InspectionExtraction) → (validated_extraction, warnings[])

  1. Range validation     → adjust confidence, add warnings
  2. Confidence thresholds → flag uncertain fields
  3. Cross-field checks   → add advisory warnings
  4. Risk calculation     → compute priority + reasons
  5. Metadata update      → recalculate overall_confidence, uncertain_field_count
```

---

## Schema Versioning

The schema includes a version marker for forward compatibility:

| Version | Status  | Description         |
|---------|---------|---------------------|
| `1.0`   | Current | MVP hackathon schema |

Future versions may add fields but will not remove or rename existing fields.
