from typing import List, Tuple
from app.models.inspection import (
    DetectedIssue,
    InspectionExtraction,
    RecommendedAction,
    Severity,
    ValidationWarning,
)

RANGE_RULES = {
    "temperature": {"min": -50, "max": 500, "warn_low": -10, "warn_high": 100},
    "pressure":    {"min": 0,   "max": 1000, "warn_high": 300},
    "humidity":    {"min": 0,   "max": 100,  "warn_low": 10, "warn_high": 95},
    "rpm":         {"min": 0,   "max": 50000, "warn_high": 10000},
    "voltage":     {"min": 0,   "max": 100000, "warn_high": 480},
    "current":     {"min": 0,   "max": 10000, "warn_high": 100},
    "flow_rate":   {"min": 0,   "max": 10000, "warn_high": 1000},
}

RISK_WEIGHTS = {
    "vibration":   {"risk_statuses": ["HIGH", "CRITICAL"], "weight": 2},
    "temperature": {"risk_statuses": ["HIGH", "CRITICAL"], "weight": 2},
    "oil_level":   {"risk_statuses": ["LOW", "CRITICAL"], "weight": 2},
    "filter":      {"risk_statuses": ["REPLACEMENT_REQUIRED"], "weight": 1},
    "leak":        {"risk_statuses": ["LEAK_DETECTED"], "weight": 3},
    "pressure":    {"risk_statuses": ["HIGH", "CRITICAL", "LOW"], "weight": 2},
    "noise":       {"risk_statuses": ["HIGH", "CRITICAL"], "weight": 1},
    "wear":        {"risk_statuses": ["WORN", "CRITICAL"], "weight": 1},
}

class ValidationService:
    
    def validate_and_assess(self, extraction: InspectionExtraction) -> Tuple[InspectionExtraction, List[ValidationWarning], Severity]:
        warnings = []
        
        # 1. Range validation
        for r in extraction.readings:
            if r.value is not None and r.parameter in RANGE_RULES:
                rule = RANGE_RULES[r.parameter]
                
                # Check min/max bounds
                if "min" in rule and "max" in rule:
                    if r.value < rule["min"] or r.value > rule["max"]:
                        r.confidence = min(r.confidence, 0.3)
                        r.is_uncertain = True
                        r.uncertainty_reason = f"Value {r.value} is outside plausible range [{rule['min']}, {rule['max']}]"
                        warnings.append(ValidationWarning(
                            field=r.parameter, 
                            message=r.uncertainty_reason, 
                            severity=Severity.HIGH
                        ))
                
                # Check soft warnings
                if "warn_high" in rule and r.value >= rule["warn_high"]:
                    warnings.append(ValidationWarning(
                        field=r.parameter,
                        message=f"Value {r.value} is above warning threshold ({rule['warn_high']})",
                        severity=Severity.MEDIUM
                    ))
                if "warn_low" in rule and r.value <= rule["warn_low"]:
                    warnings.append(ValidationWarning(
                        field=r.parameter,
                        message=f"Value {r.value} is below warning threshold ({rule['warn_low']})",
                        severity=Severity.MEDIUM
                    ))

        # 2. Re-evaluate metadata
        total = len(extraction.readings)
        uncertain = sum(1 for r in extraction.readings if r.is_uncertain)
        overall_conf = sum(r.confidence for r in extraction.readings) / total if total > 0 else 0.0
        
        extraction.metadata.field_count = total
        extraction.metadata.uncertain_field_count = uncertain
        extraction.metadata.overall_confidence = overall_conf

        # 3. Risk calculation
        risk_score = 0.0
        for r in extraction.readings:
            rule = RISK_WEIGHTS.get(r.parameter)
            if rule and r.status in rule["risk_statuses"]:
                risk_score += rule["weight"]
            if r.status == "UNKNOWN" and r.is_uncertain:
                risk_score += 0.5

        if risk_score >= 5:
            priority = Severity.CRITICAL
        elif risk_score >= 3:
            priority = Severity.HIGH
        elif risk_score >= 1:
            priority = Severity.MEDIUM
        else:
            priority = Severity.LOW

        # Gemini may provide richer prose, but the prototype must still produce
        # operationally useful output when an extractor returns readings only.
        if not extraction.detected_issues:
            issues = []
            for r in extraction.readings:
                rule = RISK_WEIGHTS.get(r.parameter)
                if rule and r.status in rule["risk_statuses"]:
                    issues.append(DetectedIssue(
                        description=f"{r.parameter.replace('_', ' ').title()} is {r.status.lower().replace('_', ' ')}",
                        severity=priority if priority != Severity.LOW else Severity.MEDIUM,
                        source_readings=[r.parameter.value],
                        confidence=r.confidence,
                    ))
            extraction.detected_issues = issues

        if not extraction.recommended_actions and extraction.detected_issues:
            has_vibration = any(r.parameter == "vibration" and r.status in ("HIGH", "CRITICAL") for r in extraction.readings)
            has_filter = any(r.parameter == "filter" and r.status == "REPLACEMENT_REQUIRED" for r in extraction.readings)
            if has_vibration and has_filter:
                action = f"Inspect Machine {extraction.machine_id or 'equipment'} and replace the filter."
            else:
                action = f"Inspect {extraction.machine_id or 'the equipment'} and address the detected issue."
            extraction.recommended_actions = [RecommendedAction(
                action=action,
                priority=priority,
                related_issues=[issue.description for issue in extraction.detected_issues],
            )]

        return extraction, warnings, priority

validation_service = ValidationService()
