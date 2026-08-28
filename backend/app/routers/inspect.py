import uuid
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from app.services.gemini_service import gemini_service
from app.services.demo_service import demo_service
from app.services.validation_service import validation_service
from app.services.supabase_service import supabase_service
from app.models.inspection import InspectionResponse, InspectionExtraction
from app.config import settings

router = APIRouter(prefix="/api")

@router.post("/analyze", response_model=InspectionResponse)
async def analyze_inspection(
    image: Optional[UploadFile] = File(None),
    text: Optional[str] = Form(None)
):
    if not image and not text:
        raise HTTPException(status_code=400, detail="Either image or text must be provided")

    image_bytes = None
    mime_type = None
    if image:
        image_bytes = await image.read()
        mime_type = image.content_type

    try:
        if settings.demo_mode:
            if image_bytes:
                raise ValueError("DEMO_MODE accepts the documented text scenario only; disable it to analyze images with Gemini.")
            extraction = demo_service.extract_inspection(text=text)
        else:
            extraction = gemini_service.extract_inspection(text=text, image_bytes=image_bytes, mime_type=mime_type)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"AI_EXTRACTION_FAILED: {str(e)}")

    validated_extraction, warnings, priority = validation_service.validate_and_assess(extraction)
    
    # Save to Supabase (Mocked if Supabase not fully set up)
    inspection_record = {
        "machine_id": validated_extraction.machine_id,
        "inspection_date": validated_extraction.inspection_date,
        "worker_name": validated_extraction.worker_name,
        "raw_observation": validated_extraction.raw_observation,
        "next_inspection": validated_extraction.next_inspection,
        "risk_priority": priority,
        "detected_issues": [i.model_dump(mode="json") for i in validated_extraction.detected_issues],
        "recommended_actions": [a.model_dump(mode="json") for a in validated_extraction.recommended_actions],
        "warnings": [w.model_dump(mode="json") for w in warnings],
        "overall_confidence": validated_extraction.metadata.overall_confidence,
        "uncertain_field_count": validated_extraction.metadata.uncertain_field_count,
        "extraction_notes": validated_extraction.metadata.extraction_notes
    }
    
    saved_inspection = supabase_service.create_inspection(inspection_record)
    inspection_id = saved_inspection.get("id", uuid.uuid4())
    
    readings_to_save = []
    reading_responses = []
    
    for r in validated_extraction.readings:
        reading_id = uuid.uuid4()
        r_dict = r.model_dump(mode="json")
        readings_to_save.append({
            "id": str(reading_id),
            "inspection_id": str(inspection_id),
            **r_dict
        })
        reading_responses.append({
            "id": reading_id,
            "confirmed": False,
            **r_dict
        })
    
    supabase_service.create_readings(readings_to_save)
    
    return {
        "inspection_id": inspection_id,
        **inspection_record,
        "readings": reading_responses,
        "metadata": validated_extraction.metadata.model_dump(mode="json"),
        "created_at": saved_inspection.get("created_at", "2026-08-27T12:00:00Z")
    }

@router.post("/submit_extraction", response_model=InspectionResponse)
def submit_extraction(extraction: InspectionExtraction):
    """
    Accepts a pre-extracted JSON schema from a local on-device AI model.
    Runs the deterministic validation/risk engine and saves the result.
    """
    validated_extraction, warnings, priority = validation_service.validate_and_assess(extraction)
    
    # Save to Supabase (Mocked if Supabase not fully set up)
    inspection_record = {
        "machine_id": validated_extraction.machine_id,
        "inspection_date": validated_extraction.inspection_date,
        "worker_name": validated_extraction.worker_name,
        "raw_observation": validated_extraction.raw_observation,
        "next_inspection": validated_extraction.next_inspection,
        "risk_priority": priority,
        "detected_issues": [i.model_dump(mode="json") for i in validated_extraction.detected_issues],
        "recommended_actions": [a.model_dump(mode="json") for a in validated_extraction.recommended_actions],
        "warnings": [w.model_dump(mode="json") for w in warnings],
        "overall_confidence": validated_extraction.metadata.overall_confidence,
        "uncertain_field_count": validated_extraction.metadata.uncertain_field_count,
        "extraction_notes": validated_extraction.metadata.extraction_notes
    }
    
    saved_inspection = supabase_service.create_inspection(inspection_record)
    inspection_id = saved_inspection.get("id", uuid.uuid4())
    
    readings_to_save = []
    reading_responses = []
    
    for r in validated_extraction.readings:
        reading_id = uuid.uuid4()
        r_dict = r.model_dump(mode="json")
        readings_to_save.append({
            "id": str(reading_id),
            "inspection_id": str(inspection_id),
            **r_dict
        })
        reading_responses.append({
            "id": reading_id,
            "confirmed": False,
            **r_dict
        })
    
    supabase_service.create_readings(readings_to_save)
    
    return {
        "inspection_id": inspection_id,
        **inspection_record,
        "readings": reading_responses,
        "metadata": validated_extraction.metadata.model_dump(mode="json"),
        "created_at": saved_inspection.get("created_at", "2026-08-27T12:00:00Z")
    }

@router.get("/inspections")
def list_inspections():
    return {"inspections": supabase_service.get_inspections()}

@router.post("/inspections")
def create_inspection_direct(data: dict):
    # This is a fallback/mock endpoint
    return supabase_service.create_inspection(data)
