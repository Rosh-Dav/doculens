from abc import ABC, abstractmethod
from typing import Optional
from app.models.inspection import InspectionExtraction

class AIProvider(ABC):
    """
    Abstract interface for AI inference engines.
    """
    @abstractmethod
    def extract_inspection(
        self, 
        text: Optional[str] = None, 
        image_bytes: Optional[bytes] = None, 
        mime_type: Optional[str] = None
    ) -> InspectionExtraction:
        """
        Extracts an inspection observation into a structured JSON schema.
        Must return a valid InspectionExtraction Pydantic model.
        """
        pass
