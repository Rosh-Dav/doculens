# DocuLens Backend MVP

This is the FastAPI backend for the DocuLens MVP. It processes field inspection notes (text or image) using the Gemini API, validates the extracted data deterministically, assigns risk scores, and stores results in Supabase.

## Tech Stack
* Python 3.11+
* FastAPI
* Pydantic
* google-genai (Gemini API)
* Supabase (supabase-py)
* Pytest

## Setup Instructions

1. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

2. **Environment Variables**
   Create a `.env` file in the `backend` directory (you can copy `.env.example`):
   ```env
   GEMINI_API_KEY=your-gemini-api-key
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_KEY=your-supabase-anon-key
   SUPABASE_SERVICE_KEY=your-supabase-service-role-key
   HOST=0.0.0.0
   PORT=8000
   ```

3. **Run the Server**
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

4. **API Documentation**
   Once running, you can interact with the auto-generated Swagger UI at:
   `http://127.0.0.1:8000/docs`

## Endpoints

* `GET /api/health` - Check backend status
* `POST /api/analyze` - Submit an inspection (text or image) for Gemini extraction + validation
* `GET /api/inspections` - List recent inspections
* `POST /api/tasks` - Create a maintenance task manually
* `GET /api/tasks` - List maintenance tasks

## Testing

Run tests with Pytest:
```bash
pytest tests/ -v
```

## Limitations & Future Work

* **Mock DB Mode**: If Supabase credentials are missing from `.env`, the endpoints will log a warning and return mock UUIDs to allow local API and Gemini testing without a database setup.
* **Authentication**: All endpoints are currently public for the MVP.
* **Rate Limiting**: No rate limits are currently implemented; rely on Gemini's API quota directly.
