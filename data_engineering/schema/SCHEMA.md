# CareFlow — Mock EHR Event Schema (Day 1)

## What this defines

Before generating any data, this document fixes the shape of a single
EHR event so every later step (data generator, BigQuery, dbt, PM4Py,
dashboard) reads the same structure.

An **event** = one thing that happened to one patient at one moment.
A patient's full ER visit is a *sequence* of events.

## Fields

| Field | Type | Description |
|---|---|---|
| `Patient` | string | Unique identifier for one patient's ER visit (acts as the "Case ID" in process mining terms) |
| `Activity` | string (enum) | Which clinical step occurred — see fixed activity list below |
| `Timestamp` | ISO 8601 datetime | When the activity occurred |

## Fixed activity list

Process mining tools need a **closed set** of activity names, not free
text, or the discovered process model becomes noisy and unreliable.
This is the full list for CareFlow v1:

1. `Registration`
2. `Triage`
3. `X-Ray`
4. `Triage (Rebounce - Missing Form)` — the deliberately injected bottleneck (Day 3)
5. `Doctor Consultation`
6. `Discharge`

## Example patient journey

```
Patient        Activity                          Timestamp
PATIENT_0001   Registration                       2026-08-13T10:00:00
PATIENT_0001   Triage                              2026-08-13T10:10:00
PATIENT_0001   X-Ray                               2026-08-13T10:25:00
PATIENT_0001   Doctor Consultation                 2026-08-13T11:05:00
PATIENT_0001   Discharge                           2026-08-13T11:30:00
```

A patient who hits the rebounce bottleneck instead looks like:

```
PATIENT_0002   Registration                        2026-08-13T14:00:00
PATIENT_0002   Triage                               2026-08-13T14:12:00
PATIENT_0002   X-Ray                                2026-08-13T14:30:00
PATIENT_0002   Triage (Rebounce - Missing Form)      2026-08-13T15:05:00
PATIENT_0002   Doctor Consultation                  2026-08-13T15:35:00
PATIENT_0002   Discharge                            2026-08-13T16:00:00
```

## Why this matters downstream

- **Day 2** (event generator) will produce rows matching this exact shape.
- **Day 5** (BigQuery raw table) will map `Patient -> case_id`, `Activity -> activity_name`, `Timestamp -> event_timestamp`.
- **PM4Py** (Week 3+) requires exactly `case_id` / `activity_name` / `timestamp` semantics to discover a process model — this schema is designed so no rework is needed later.

## Folder structure created today

```
careflow/
└── data_engineering/
    └── schema/
        ├── ehr_event_schema.py   # Python schema definition (dataclass + enum)
        └── SCHEMA.md              # this file
```
