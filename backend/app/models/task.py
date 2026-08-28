import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel
from app.models.inspection import Severity

class TaskCreate(BaseModel):
    inspection_id: Optional[uuid.UUID] = None
    title: str
    machine_id: Optional[str] = None
    priority: Severity = Severity.MEDIUM
    notes: Optional[str] = None

class TaskUpdate(BaseModel):
    status: str

class TaskResponse(BaseModel):
    id: uuid.UUID
    task_number: int
    inspection_id: Optional[uuid.UUID]
    title: str
    machine_id: Optional[str]
    priority: Severity
    status: str
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime
