import json
import logging
from typing import Optional
from google import genai
from google.genai import types

from app.config import settings
from app.prompts.extraction_prompt import SYSTEM_PROMPT
from app.models.inspection import InspectionExtraction

from app.services.ai_provider import AIProvider

logger = logging.getLogger(__name__)

class GeminiService(AIProvider):
    def __init__(self):
        self.client = None
        if settings.gemini_api_key:
            self.client = genai.Client(api_key=settings.gemini_api_key)
        else:
            logger.warning("Gemini API key missing. AI extraction will fail.")

    def extract_inspection(self, text: Optional[str] = None, image_bytes: Optional[bytes] = None, mime_type: Optional[str] = None) -> InspectionExtraction:
        if not self.client:
            raise ValueError("Gemini API key not configured")

        contents = []
        if image_bytes and mime_type:
            contents.append(
                types.Part.from_bytes(
                    data=image_bytes,
                    mime_type=mime_type,
                )
            )
        if text:
            contents.append(text)
            
        if not contents:
            raise ValueError("Either text or image_bytes must be provided")

        config = types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            response_mime_type="application/json",
            response_schema=InspectionExtraction.model_json_schema()
        )

        try:
            response = self.client.models.generate_content(
                model='gemini-3.6-flash',
                contents=contents,
                config=config
            )
            
            result_json = response.text
            data = json.loads(result_json)
            return InspectionExtraction(**data)
            
        except Exception as e:
            logger.error(f"Gemini API error: {e}")
            raise e

gemini_service = GeminiService()
