# DocuLens — Technical Architecture

> **Current implementation document — aligned with the working hackathon prototype**

## 1. System Overview

DocuLens is a Flutter Android application backed by a Python/FastAPI service. The current working prototype accepts either an image or manually entered text, sends the observation to Gemini for structured extraction, applies deterministic validation/risk rules, stores the inspection/task data in Supabase, and returns the result to the Flutter app.

### Current architecture

```text
┌───────────────────────┐
│     Flutter Android   │
│                       │
│ Camera / Gallery      │
│ Manual observation    │
│ Results UI            │
│ Task + History UI     │
└──────────┬────────────┘
           │ HTTP
           ▼
┌───────────────────────┐
│       FastAPI         │
│                       │
│ Input handling        │
│ Gemini integration    │
│ Structured parsing    │
│ Validation / Risk     │
│ Task / History APIs   │
└───────┬────────┬──────┘
        │        │
        │        ▼
        │   ┌───────────────┐
        │   │    Gemini     │
        │   │   extraction  │
        │   └───────────────┘
        │
        ▼
┌───────────────────────┐
│       Supabase        │
│   PostgreSQL / data   │
└───────────────────────┘
```

### End-to-end flow

```text
Image or Manual Text
        │
        ▼
     FastAPI
        │
        ▼
 Gemini extraction
        │
        ▼
Structured inspection
        │
        ▼
Deterministic validation
        │
        ▼
Risk / issue detection
        │
        ▼
Recommended maintenance action
        │
        ├──────────────► Supabase persistence
        │
        ▼
     Flutter UI
        │
        ▼
Create Maintenance Task
        │
        ▼
       History
```

## 2. Important Current-State Note: AI Architecture

**The current demo uses Gemini for AI extraction. An on-device/local LLM is not currently running in the demonstrated prototype.**

A local/on-device inference path may be a future enhancement or a hackathon-specific deployment direction, but it should **not** be described as an implemented feature unless it is actually enabled in the code and used by the running app.

Therefore:

- Do not describe DocuLens as currently running a local LLM.
- Do not claim offline AI inference is implemented.
- Gemini is the current extraction provider.
- Validation and risk assessment after extraction are deterministic backend logic, not LLM reasoning.

## 3. Technology Stack

| Layer | Current technology | Role |
|---|---|---|
| Mobile frontend | Flutter / Dart | Android application and UI |
| Backend | Python / FastAPI | REST API and application logic |
| AI extraction | Google Gemini API | Image/text understanding and structured extraction |
| Validation | Python rules | Deterministic validation and risk calculation |
| Database | Supabase PostgreSQL | Persist inspections and maintenance tasks |
| Image input | Flutter camera/gallery flow | Capture or select observation image |
| API communication | Flutter HTTP client | Frontend ↔ backend communication |

Avoid putting exact package/model versions in this document unless they match the versions actually pinned in the repository.

## 4. Current User Workflow

The implemented UI demonstrates these screens/steps:

1. **Home**
   - Scan Observation
   - Enter Manually
   - Inspection History

2. **Capture Field Observation**
   - Camera
   - Gallery/image selection
   - Manual observation text
   - Analyze Observation

3. **Inspection Result**
   - Structured inspection fields
   - Detected issues
   - Risk priority
   - Recommended action
   - Create Maintenance Task

4. **Maintenance Task Created**
   - Task number
   - Machine
   - Priority
   - Status
   - Action
   - Created timestamp

5. **History**
   - Inspections
   - Maintenance tasks

## 5. API Layer

The backend exposes REST endpoints for the inspection, task, history, and health workflows.

The exact route names should be taken from the current FastAPI router files. Do not document an endpoint as implemented until it exists in the repository.

The conceptual API surface is:

```text
POST   /inspect
GET    /inspections
GET    /inspections/{id}

POST   /tasks
GET    /tasks
PATCH  /tasks/{id}

GET    /health
```

If the deployed application uses an `/api/v1` prefix, it should be applied consistently to all routes in the implementation and documentation.

## 6. AI Extraction

Gemini receives either:

- an observation image, or
- manually entered observation text.

The extraction goal is to convert unstructured field information into structured inspection data such as:

- machine
- temperature
- vibration
- oil
- filter
- next inspection
- worker, when available

The extraction must preserve information from the source rather than silently inventing missing values.

Example manual input:

```text
machine: pump-03
temperature: 820 C
Vibration: High
oil: Unknown
```

The current prototype demonstrates this being transformed into structured inspection information and then evaluated for risk.

## 7. Validation and Risk Engine

After Gemini extraction, the backend applies deterministic rules.

The important separation is:

```text
Gemini
  → understands / extracts

Python validation + risk rules
  → checks / evaluates / prioritizes
```

The risk engine can use extracted conditions such as:

- high vibration
- high/critical temperature
- unknown oil state
- filter replacement requirement

The final priority is then shown to the user as part of the inspection result.

For example, the demonstrated `pump-03` flow identifies:

- temperature: 820.0 °C — CRITICAL
- vibration: HIGH
- oil: UNKNOWN

and recommends immediate inspection and temperature re-verification.

## 8. Persistence

Supabase PostgreSQL is used to persist the operational history.

The current product flow requires persistence for:

- inspections
- extracted readings/inspection fields
- maintenance tasks

The Flutter history screen then presents previously created inspections and tasks.

## 9. Current Data Relationships

Conceptually:

```text
Inspection
   │
   ├── extracted readings / fields
   │
   └── can generate
          │
          ▼
     Maintenance Task
```

Multiple inspections and tasks can appear in the history view.

## 10. Error Handling

The backend should return clear errors for:

- missing image/text input
- invalid image
- AI extraction failure
- unavailable backend/database
- missing inspection/task

The frontend should present a user-readable failure state and allow retry where appropriate.

Do not document retry counts, timeout values, or error codes as fixed product behavior unless those values are present in the current implementation.

## 11. Security

Secrets such as:

```text
GEMINI_API_KEY
SUPABASE credentials
```

must remain in environment configuration and must not be committed to Git.

The frontend should not contain server-side secrets such as a Gemini API key or Supabase service-role key.

## 12. Current Prototype Boundary

### Implemented / demonstrated

- Image input
- Camera/gallery flow
- Manual text input
- Gemini-based extraction
- Structured inspection result
- Deterministic risk/validation flow
- Maintenance recommendation
- Maintenance task creation
- Inspection history
- Task history
- Supabase persistence

### Not currently demonstrated as implemented

- On-device/local LLM inference
- Offline AI inference
- IoT sensor integration
- Real-time industrial hardware
- ERP integration
- Authentication
- Advanced analytics/dashboard
- Custom trained ML model

These may be future scope, but should not be presented as current capabilities.

## 13. Architecture Principle

DocuLens is not positioned as "just OCR".

Its pipeline is:

```text
Messy field observation
        ↓
AI understanding
        ↓
Structured operational data
        ↓
Deterministic validation
        ↓
Risk identification
        ↓
Maintenance action
        ↓
Trackable maintenance task
```

This distinction is central to the product.
