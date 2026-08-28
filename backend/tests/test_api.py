from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "version": "0.1.0"}

def test_tasks_endpoints():
    task_data = {
        "title": "Test Task",
        "machine_id": "M104",
        "priority": "HIGH"
    }
    # Create task
    response = client.post("/api/tasks", json=task_data)
    assert response.status_code == 200
    res_data = response.json()
    assert res_data["title"] == "Test Task"
    
    # List tasks
    response = client.get("/api/tasks")
    assert response.status_code == 200
    assert "tasks" in response.json()
