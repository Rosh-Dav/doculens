from fastapi.testclient import TestClient
from app.main import app
from app.models.inspection import InspectionExtraction, Reading, Parameter, Status, ExtractionMetadata

client = TestClient(app)

def test_submit_extraction():
    # Setup dummy extraction as if coming from local phone model
    r1 = Reading(
        parameter=Parameter.TEMPERATURE,
        value=85.0,
        status=Status.NORMAL,
        confidence=0.9,
        raw_fragment="temp 85"
    )
    
    metadata = ExtractionMetadata(
        overall_confidence=0.9,
        field_count=1,
        uncertain_field_count=0
    )

    extraction = InspectionExtraction(
        machine_id="M104",
        readings=[r1],
        metadata=metadata
    )

    response = client.post("/api/submit_extraction", json=extraction.model_dump(mode="json"))
    
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["machine_id"] == "M104"
    assert data["risk_priority"] == "LOW"
    assert len(data["readings"]) == 1
    assert data["readings"][0]["value"] == 85.0
