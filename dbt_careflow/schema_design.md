# CareFlow Schema Design

## Grain
One row = one event or activity for one patient case.

## Source
- Platform: BigQuery
- Dataset: careflow_raw
- Table: event_log

## Architecture
Raw -> Staging -> Marts

## Proposed production schema
The following fields represent the expected business schema for the final patient-flow event log. These are the logical fields we want to standardize before downstream analysis.

- case_id: STRING — Unique patient/case journey identifier.
- activity_name: STRING — Process activity or event label.
- timestamp: TIMESTAMP — Event timestamp in UTC or normalized local time.
- patient_age: INT64 — Patient age.
- gender: STRING — Patient gender or category.
- doctor_id: STRING — Assigned doctor or clinician.
- priority: STRING — Case priority category.
- journey_type: STRING — Type of patient journey.

## Actual temporary dataset schema
The current temporary CSV is a working/raw extraction and is not yet the final governed schema. It contains provisional fields that require business validation before being promoted into the core model.

- event_id: STRING — Temporary source identifier.
- case_id: STRING — Case identifier in the source extract.
- activity_name: STRING — Event label in the source extract.
- timestamp: TIMESTAMP — Event timestamp.
- source_row: STRING — Source row reference from the file.
- source_sheet: STRING — Source tab or sheet reference.
- source_system: STRING — System of origin for the row.
- wait: FLOAT64 — Waiting metric; may be negative and requires business interpretation.
- sum_waits: FLOAT64 — Aggregated waiting values from the source extract.
- avg_how_early_waiting: FLOAT64 — Early waiting metric from the source extract.
- flow_count_2: INT64 — Temporary flow metric.
- flow_count_4: INT64 — Temporary flow metric.
- delay_count: INT64 — Temporary delay metric.

Important:
- These temporary columns must not be silently renamed or treated as the final business schema.
- Negative waiting values should not be removed automatically without confirming whether they represent early arrival, early processing, schedule variance, or a real data-quality issue.
- The final model should only promote validated fields into the production event-log schema.

## Planned data-quality checks
The following checks are planned for the staging and validation layer once the final business schema is confirmed:

- Case_ID cannot be NULL
- Activity_Name cannot be NULL
- Timestamp cannot be NULL
- Patient_Age should have a valid range
- Priority should contain accepted categories
- Journey_Type should contain accepted categories
- Duplicate event records should be investigated
- Event chronology within each case should be validated

## Data-flow intent
The model architecture is intentionally simple for Day 1:

Raw event log -> BigQuery -> dbt staging -> dbt marts

This keeps the project clean while ensuring the team can add standardization, validation, and downstream metrics in later phases.
