# DocuLens — Product Specification

## 1. Product

**DocuLens** is an intelligent field-observation assistant for industrial maintenance.

It converts handwritten or manually entered field observations into structured inspection information, identifies operational risk, recommends a maintenance action, and lets the user create a trackable maintenance task.

## 2. Core Problem

Field workers may record observations as:

- handwriting
- abbreviations
- short notes
- incomplete sentences
- inconsistent terminology
- measurements mixed with qualitative conditions

The information may be understandable to the person who wrote it but difficult to process consistently.

DocuLens turns that observation into an operational workflow:

```text
Observation
   ↓
Structured inspection
   ↓
Risk identification
   ↓
Maintenance recommendation
   ↓
Maintenance task
   ↓
History
```

## 3. Current Product Workflow

### Step 1 — Capture an observation

The user can:

- take a photo with the camera
- choose an existing image
- enter observation text manually

### Step 2 — Analyze

The observation is sent to the backend, where Gemini extracts structured information.

### Step 3 — Inspect the result

The app presents:

- machine
- temperature
- vibration
- oil
- filter
- next inspection
- worker, when available

It also shows:

- detected issues
- risk priority
- recommended action

### Step 4 — Create a maintenance task

The user can convert the recommendation into a maintenance task.

The demonstrated task screen includes:

- task number
- machine
- priority
- status
- action
- creation time

### Step 5 — Review history

The History screen contains separate views for:

- inspections
- maintenance tasks

## 4. Demonstrated Examples

### Example A — Manual observation

The current demo uses input similar to:

```text
machine: pump-03
temperature: 820 C
Vibration: High
oil: Unknown
```

DocuLens produces a structured result such as:

```text
Machine: pump-03
Temperature: 820.0 °C — CRITICAL
Vibration: HIGH
Oil: UNKNOWN
```

It identifies the abnormal temperature and high vibration and recommends:

```text
Inspect machine immediately and re-verify
temperature with calibrated thermometer
```

The user can then create a HIGH-priority maintenance task.

### Example B — Maintenance note

The prototype also demonstrates a maintenance note containing information such as:

```text
M104
temperature around 82 °C
vibration high
oil OK
filter needs changing
check again next week
```

The resulting workflow can identify the filter replacement requirement and create a maintenance task.

## 5. Product Differentiation

DocuLens should not be described as an OCR-only or document-scanning application.

The important transformation is:

```text
Unstructured field observation
              ↓
      Operational meaning
              ↓
      Maintenance action
```

For example, different expressions may refer to the same operational condition:

```text
"vib high"
"machine shaking"
"excessive vibration"
```

→ **Vibration = HIGH**

The system is valuable because the extracted information is then used for validation, risk assessment, and maintenance workflow.

## 6. AI and Validation Responsibilities

### Gemini

Used for:

- understanding the observation
- extracting relevant fields
- normalizing field terminology
- producing structured data

### Backend validation/risk logic

Used for:

- checking extracted values
- identifying abnormal conditions
- assigning risk priority
- generating the maintenance recommendation

This separation is important because risk prioritization is not presented as an unconstrained LLM decision.

## 7. Handling Uncertain Information

DocuLens should not silently invent missing information.

Examples:

```text
oil: Unknown
```

should remain unknown rather than being converted to NORMAL.

Similarly, an unusual value such as:

```text
temperature: 820 °C
```

should be preserved as observed and flagged as abnormal rather than silently changed to `82 °C`.

The demonstrated prototype uses this behavior to show how suspicious field data can trigger verification.

## 8. MVP Scope

### In scope — current prototype

- Camera input
- Gallery/image input
- Manual observation text
- AI-based extraction
- Structured inspection result
- Validation/risk assessment
- Detected issues
- Recommended maintenance action
- Maintenance task creation
- Inspection history
- Task history
- Supabase persistence
- Mobile-first Flutter UI

### Not currently implemented / not part of the demonstrated MVP

- On-device/local LLM inference
- Offline AI processing
- IoT sensor feeds
- Real-time industrial hardware
- ERP integration
- Authentication
- Advanced analytics
- Admin dashboard
- Custom trained ML model

## 9. Target User

The primary user is a field worker or maintenance/inspection worker who needs to quickly convert field observations into actionable maintenance information.

## 10. Hackathon Positioning

The strongest demo message is:

> **DocuLens turns messy field observations into structured maintenance actions.**

The demo should emphasize the complete loop:

```text
Capture
  ↓
Understand
  ↓
Validate
  ↓
Identify risk
  ↓
Recommend action
  ↓
Create task
  ↓
Track in history
```

## 11. Product Boundary

DocuLens is currently a focused industrial field-inspection prototype.

It is not an ERP, CMMS replacement, IoT monitoring platform, or general-purpose document management system.
