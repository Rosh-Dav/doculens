import uuid
from datetime import datetime
from enum import Enum
from typing import Optional, List

from pydantic import BaseModel, Field, field_validator, model_validator


class Parameter(str, Enum):
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
    NORMAL = "NORMAL"
    LOW = "LOW"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"
    REPLACEMENT_REQUIRED = "REPLACEMENT_REQUIRED"
    LEAK_DETECTED = "LEAK_DETECTED"
    WORN = "WORN"
    UNKNOWN = "UNKNOWN"


class Severity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class Unit(str, Enum):
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


class Reading(BaseModel):
    parameter: Parameter
    parameter_label: Optional[str] = None
    value: Optional[float] = None
    unit: Optional[Unit] = None
    status: Status
    confidence: float = Field(ge=0.0, le=1.0)
    is_uncertain: bool = False
    uncertainty_reason: Optional[str] = None
    raw_fragment: str

    @model_validator(mode="after")
    def check_uncertainty_consistency(self) -> "Reading":
        if self.confidence < 0.7 and not self.is_uncertain:
            self.is_uncertain = True
        if self.is_uncertain and not self.uncertainty_reason:
            self.uncertainty_reason = "Low confidence extraction. Please verify."
        return self

    @field_validator("parameter_label")
    @classmethod
    def label_required_for_other(cls, v: Optional[str], info) -> Optional[str]:
        if info.data.get("parameter") == Parameter.OTHER and not v:
            raise ValueError("parameter_label is required when parameter is 'other'")
        return v


class DetectedIssue(BaseModel):
    description: str
    severity: Severity
    source_readings: List[str]
    confidence: float = Field(ge=0.0, le=1.0)


class RecommendedAction(BaseModel):
    action: str
    priority: Severity
    related_issues: List[str]


class ExtractionMetadata(BaseModel):
    overall_confidence: float = Field(ge=0.0, le=1.0)
    field_count: int
    uncertain_field_count: int
    extraction_notes: Optional[str] = None


class InspectionExtraction(BaseModel):
    machine_id: Optional[str] = None
    inspection_date: Optional[str] = None
    worker_name: Optional[str] = None
    readings: List[Reading]
    detected_issues: List[DetectedIssue] = Field(default_factory=list)
    recommended_actions: List[RecommendedAction] = Field(default_factory=list)
    next_inspection: Optional[str] = None
    raw_observation: Optional[str] = None
    metadata: ExtractionMetadata


class ValidationWarning(BaseModel):
    field: str
    message: str
    severity: Severity = Severity.MEDIUM


class ReadingResponse(Reading):
    id: uuid.UUID
    confirmed: bool = False


class InspectionResponse(BaseModel):
    inspection_id: uuid.UUID
    machine_id: Optional[str]
    inspection_date: Optional[str]
    worker_name: Optional[str]
    readings: List[ReadingResponse]
    detected_issues: List[DetectedIssue]
    recommended_actions: List[RecommendedAction]
    risk_priority: Severity
    next_inspection: Optional[str]
    raw_observation: Optional[str]
    metadata: ExtractionMetadata
    warnings: List[ValidationWarning] = Field(default_factory=list)
    created_at: datetime
