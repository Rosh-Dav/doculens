"""Development-only extraction fallback for rehearsing the prototype offline.

It is deliberately opt-in via DEMO_MODE and does not replace Gemini in normal
operation. It recognizes the published hackathon demo observation only.
"""

from app.models.inspection import (
    ExtractionMetadata,
    InspectionExtraction,
    Parameter,
    Reading,
    Status,
)


class DemoService:
    def extract_inspection(self, text: str | None = None, **_: object) -> InspectionExtraction:
        observation = text or ""
        normalized = observation.lower()

        if "m104" not in normalized:
            raise ValueError(
                "DEMO_MODE only supports the documented M104 maintenance observation. "
                "Configure GEMINI_API_KEY for real extraction."
            )

        readings = [
            Reading(
                parameter=Parameter.TEMPERATURE,
                value=82,
                status=Status.NORMAL,
                confidence=0.98,
                raw_fragment="Temp: 82 C",
            ),
            Reading(
                parameter=Parameter.VIBRATION,
                status=Status.HIGH,
                confidence=0.98,
                raw_fragment="Vib: HIGH",
            ),
            Reading(
                parameter=Parameter.OIL_LEVEL,
                status=Status.NORMAL,
                confidence=0.98,
                raw_fragment="Oil: OK",
            ),
            Reading(
                parameter=Parameter.FILTER,
                status=Status.REPLACEMENT_REQUIRED,
                confidence=0.98,
                raw_fragment="Filter needs changing",
            ),
        ]
        return InspectionExtraction(
            machine_id="M104",
            worker_name="Amit" if "amit" in normalized else None,
            readings=readings,
            next_inspection="next week" if "next week" in normalized else None,
            raw_observation=observation,
            metadata=ExtractionMetadata(
                overall_confidence=0.98,
                field_count=len(readings),
                uncertain_field_count=0,
                extraction_notes="Development demo fallback (DEMO_MODE).",
            ),
        )


demo_service = DemoService()
