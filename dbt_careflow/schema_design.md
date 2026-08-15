# CareFlow Schema Design

## Grain
One row = one event or activity for one patient case.

## Source
- Platform: BigQuery
- Dataset: careflow_raw
- Table: event_log
- Records: 6,800 (after deduplication from 6,868 raw events)
- Cases: 1,000 unique patient journeys
- Date Range: 2022-10-31 to 2025-08-02

## Architecture
Raw -> Staging -> Marts

## Raw BigQuery Schema (careflow_raw.event_log)

The actual dataset contains the following fields:

- event_id: STRING — Unique event identifier within a case (e.g., CF00228_E05)
- case_id: STRING — Unique patient/case journey identifier (e.g., CF00228)
- activity_name: STRING — Healthcare activity type (Doctor Review, Triage, Registration, Doctor Consultation, Discharge, X-Ray)
- timestamp: TIMESTAMP — Event timestamp
- department: STRING — Department where event occurred (currently all Emergency)
- doctor_id: STRING — Healthcare provider identifier (DR001-DR020)
- priority: STRING — Case priority (High, Medium, Low)
- journey_type: STRING — Patient journey classification (Normal, Loopback, Delayed)
- source_row: INT64 — Row number from source extraction
- source_system: STRING — Source system identifier (WaitData.Published_F1)

## Staging Layer (stg_careflow__events)

The staging model applies the following transformations:

- Deduplicate: Remove 68 full-row duplicates (keep first by source_row)
- Cast: Explicitly cast all columns to intended data types
- Trim: Remove leading/trailing whitespace from string fields
- Rename: timestamp → event_timestamp (for clarity)

Output row count: 6,800 events (unique by event_id)

## Planned data-quality checks

The following tests are implemented in the staging layer:

### Critical field validation
- event_id: NOT NULL, UNIQUE
- case_id: NOT NULL
- activity_name: NOT NULL, IN (valid activity types)
- event_timestamp: NOT NULL
- department: NOT NULL
- doctor_id: NOT NULL
- priority: NOT NULL, IN (High, Medium, Low)
- journey_type: NOT NULL, IN (Normal, Loopback, Delayed)
- source_row: NOT NULL
- source_system: NOT NULL, IN (WaitData.Published_F1)

## Data Quality Summary

| Issue | Status | Action |
|-------|--------|--------|
| Null values | ✅ None | No treatment needed |
| Duplicates | ⚠️ 68 found | Deduplicated in staging |
| Invalid timestamps | ✅ None | None found |
| Future timestamps | ✅ None | None found |
| Category inconsistencies | ✅ None | No variations detected |

## Known Data Characteristics

- **Single department**: All records from Emergency department
- **Loopback cases**: Average 8.07 events per case (vs 6.07 for Normal)
- **Journey types**: Normal (52.3%), Loopback (40%), Delayed (7.7%)
- **Event distribution**: 6-10 events per case, mean 6.87
- **Priorities**: Balanced distribution (High 32.2%, Medium 33.9%, Low 33.8%)
- **Doctors**: 20 clinicians with relatively even workload distribution

## Future Analytics

Day 3+ will add:

- Case-level metrics (start time, end time, duration)
- Activity timing metrics (duration between activities)
- Process path analysis (sequence of activities per case)
- Waiting time metrics (derived from timestamps)
- Department and doctor performance metrics
- Journey type analysis (Normal vs Loopback vs Delayed)

