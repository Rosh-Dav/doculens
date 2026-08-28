# DocuLens — Product Specification

## Product

DocuLens is an intelligent field-data assistant for industrial maintenance and field inspection.

### Core Problem

Industrial field workers often record observations using messy handwriting, abbreviations, casual language, incomplete sentences, or inconsistent formats. Even when workers use phones/tablets, the information may still be unstructured.

DocuLens converts this messy field input into structured, validated maintenance information and actionable maintenance tasks.

## Core Workflow

Capture → Understand → Normalize → Validate → Detect Issues → Recommend Action → Create Maintenance Task

## Primary Demo Scenario

A maintenance worker records:

> "M104 checked today. temp 82, vib high. oil ok. filter needs changing. check again next week."

DocuLens should convert this into:

| Field            | Value                  |
|------------------|------------------------|
| Machine          | M104                   |
| Temperature      | 82°C                   |
| Vibration        | HIGH                   |
| Oil              | NORMAL                 |
| Filter           | REPLACEMENT REQUIRED   |
| Next Inspection  | next week              |

Then identify:

> **HIGH PRIORITY**
> Reason: High vibration detected and filter replacement required.

Then recommend:

> Inspect Machine M104 and replace the filter.

Then allow the user to create:

> **Maintenance Task #001**
> Machine: M104 | Priority: HIGH | Status: OPEN

## Important Product Differentiation

DocuLens is **NOT** simply an OCR/document scanning application.

It must handle:

- Messy handwriting
- Abbreviations
- Casual language
- Incomplete observations
- Inconsistent terminology
- Measurements
- Potentially ambiguous values

It should normalize different expressions into the same operational meaning.

Example:

- "vib high"
- "machine shaking"
- "excessive vibration"
- "vibration ↑"

→ All interpreted as: **Vibration = HIGH**

## Confidence and Uncertainty

DocuLens must **never** silently invent missing information.

If information is uncertain, mark it as uncertain and ask the user to confirm it.

Example:

| Field       | Value |
|-------------|-------|
| Temperature | 820°C |
| Confidence  | LOW   |
| Message     | "This value appears unusual. Please verify." |

## MVP Scope

### In Scope

1. Capture/upload a field observation image
2. Optional manual text input
3. AI extraction and normalization
4. Structured inspection result
5. Validation
6. Risk/issue detection
7. Recommended action
8. Maintenance task creation
9. Inspection history
10. Clean mobile UI

### Out of Scope

- Authentication
- Enterprise ERP integration
- IoT sensors
- Real-time industrial hardware
- Complex analytics
- Multi-industry support
- Custom ML model
- Advanced admin dashboard

The product must be optimized for a **hackathon demo** and reliability.
