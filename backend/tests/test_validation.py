import pytest
from app.models.inspection import InspectionExtraction, Reading, Parameter, Status, ExtractionMetadata, DetectedIssue, RecommendedAction

from app.services.validation_service import validation_service

def test_validation_engine():
    # Setup dummy extraction
    r1 = Reading(
        parameter=Parameter.TEMPERATURE,
        value=150.0,
        status=Status.HIGH,
        confidence=0.9,
        raw_fragment="temp 150"
    )
    r2 = Reading(
        parameter=Parameter.VIBRATION,
        value=None,
        status=Status.CRITICAL,
        confidence=0.8,
        raw_fragment="shaking a lot"
    )
    
    metadata = ExtractionMetadata(
        overall_confidence=0.85,
        field_count=2,
        uncertain_field_count=0
    )

    extraction = InspectionExtraction(
        machine_id="M1",
        readings=[r1, r2],
        metadata=metadata
    )

    validated, warnings, priority = validation_service.validate_and_assess(extraction)
    
    # 150 is above warn_high (100) for temperature, should have a warning
    assert any(w.field == "temperature" for w in warnings)
    
    # Priority should be CRITICAL since vibration CRITICAL has weight 2 and temp HIGH has weight 2 (sum 4 - wait, temp is HIGH, vib is CRITICAL, total 4, so HIGH)
    # Wait, risk_score for temp=HIGH is 2. vib=CRITICAL is 2. Total = 4. 4 >= 3 -> HIGH
    assert priority == "HIGH"
