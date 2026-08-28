import logging
import uuid
from datetime import datetime, timezone
from supabase import create_client, Client
from app.config import settings

logger = logging.getLogger(__name__)

class SupabaseService:
    def __init__(self):
        self.client: Client | None = None
        self._mock_inspections: list[dict] = []
        self._mock_readings: list[dict] = []
        self._mock_tasks: list[dict] = []
        if settings.supabase_url and settings.supabase_service_key:
            try:
                self.client = create_client(settings.supabase_url, settings.supabase_service_key)
                logger.info("Supabase client initialized.")
            except Exception as e:
                logger.error(f"Failed to initialize Supabase client: {e}")
        else:
            logger.warning("Supabase URL or Key is missing. Database operations will fail.")

    def create_inspection(self, data: dict) -> dict:
        if not self.client:
            logger.warning("Mock saving inspection (Supabase not configured)")
            record = {
                "id": str(uuid.uuid4()),
                "created_at": datetime.now(timezone.utc).isoformat(),
                **data,
            }
            self._mock_inspections.append(record)
            return record
            
        res = self.client.table("inspections").insert(data).execute()
        return res.data[0] if res.data else {}

    def create_readings(self, readings_data: list[dict]):
        if not readings_data:
            return
        if not self.client:
            self._mock_readings.extend(readings_data)
            return
        self.client.table("readings").insert(readings_data).execute()
        
    def get_inspections(self):
        if not self.client:
            return list(reversed(self._mock_inspections))
        res = self.client.table("inspections").select("*").order("created_at", desc=True).execute()
        return res.data
        
    def get_tasks(self):
        if not self.client:
            return list(reversed(self._mock_tasks))
        res = self.client.table("tasks").select("*").order("created_at", desc=True).execute()
        return res.data
        
    def create_task(self, data: dict) -> dict:
        if not self.client:
            now = datetime.now(timezone.utc).isoformat()
            record = {
                "id": str(uuid.uuid4()),
                "task_number": len(self._mock_tasks) + 1,
                "status": "OPEN",
                "created_at": now,
                "updated_at": now,
                **data,
            }
            self._mock_tasks.append(record)
            return record
        res = self.client.table("tasks").insert(data).execute()
        return res.data[0] if res.data else {}

supabase_service = SupabaseService()
