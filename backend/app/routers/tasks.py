from fastapi import APIRouter
from app.services.supabase_service import supabase_service
from app.models.task import TaskCreate, TaskResponse

router = APIRouter(prefix="/api")

@router.post("/tasks")
def create_task(task: TaskCreate):
    data = task.model_dump(mode="json")
    saved = supabase_service.create_task(data)
    return saved

@router.get("/tasks")
def list_tasks():
    return {"tasks": supabase_service.get_tasks()}
