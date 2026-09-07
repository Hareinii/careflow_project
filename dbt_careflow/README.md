# CareFlow — Clinical Pathway Process Mining & Patient Flow Analytics

CareFlow is an end-to-end healthcare data engineering and process mining platform designed to analyze patient flow, clinical bottlenecks, transition delays, and pathway conformance across hospital departments.

The analytics warehouse is built entirely on **Google Cloud BigQuery** and transformed using **dbt (data build tool)** into production-grade analytical marts, standardized process mining event logs (for PM4Py and Celonis), and executive KPI models (for Power BI and Looker Studio).

---

## 1. Business Problem
Emergency department crowding, delayed clinician assessments, radiology turnaround lags, and repeated triage consultations inflate total patient cycle times and jeopardize clinical outcomes. Hospital operations leadership requires actionable intelligence to answer:
1. **Where do clinical delays accumulate?** Which specific activity-to-activity transition is the primary bottleneck?
2. **What is the typical patient journey vs. edge-case outliers?** How does pathway variation impact overall length of stay?
3. **Are patients following standard clinical pathways?** How many cases experience loopbacks or repeated activities?
4. **How do departments compare?** Where do transition handoffs break down?

---

## 2. CareFlow Architecture
The production architecture is structured as a five-tier pipeline:

```
┌──────────────────────────────────────────────────────────────┐
│                  Python EHR Data Ingestion                   │
│         (Simulates / extracts clinical event streams)        │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                     Google Cloud BigQuery                    │
│             careflow-507606.careflow.raw_ehr_events          │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│                    dbt Transformation Layer                  │
│  Staging (careflow_staging)                                  │
│    └─ stg_careflow__events (Deduplication & Type Safety)     │
│  Intermediate (careflow_intermediate)                        │
│    ├─ int_careflow__ordered_events (Sequencing & Lag/Lead)   │
│    └─ int_careflow__transition_metrics (Step Durations)      │
│  Marts (careflow_marts)                                      │
│    ├─ fct_careflow__cases (Case Journeys & Cycle Times)      │
│    ├─ mart_careflow__event_log (PM4Py / Process Mining Log)  │
│    ├─ mart_careflow__transitions (Aggregated Handoff Pairs)  │
│    ├─ mart_careflow__bottlenecks (Multi-Signal Scoring)      │
│    ├─ mart_careflow__conformance (Pathway Auditing)          │
│    ├─ mart_careflow__case_segments (P95 Outlier Slicing)     │
│    ├─ mart_careflow__departments (Department Volume & Time)  │
│    ├─ mart_careflow__process_paths (Path Frequencies)        │
│    └─ mart_careflow__kpis (Executive Summary Snapshot)       │
└──────────────────────────────┬───────────────────────────────┘
                               │
                ┌──────────────┴──────────────┐
                ▼                             ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│       PM4Py Process Mining   │ │     Power BI / Looker BI     │
│  (Process Discovery & DFG)   │ │  (Executive Ops Dashboards)  │
└──────────────────────────────┘ └──────────────────────────────┘
```

---

## 3. Warehouse Role: Google Cloud BigQuery
Google BigQuery (`careflow-507606`) serves as the central, authoritative cloud data warehouse:
- **Scalability & Security:** Serverless execution, OAuth / Service Account authentication, and strict dataset boundary separation.
- **Physical Datasets:**
  - `careflow`: Houses raw event ingestion tables (`raw_ehr_events`).
  - `careflow_staging`: Houses cleaned, deduplicated views (`stg_careflow__events`).
  - `careflow_intermediate`: Houses sequenced process metrics (`int_careflow__ordered_events`, `int_careflow__transition_metrics`).
  - `careflow_marts`: Houses analytical tables and reporting marts consumed by downstream applications.

---

## 4. Transformation Role: dbt (Data Build Tool)
dbt orchestrates the complete transformation, documentation, and data quality testing lifecycle:
- **Modularity & Lineage:** Strict separation of Staging → Intermediate → Marts layers.
- **Cross-Database Macros:** Custom macros (`macros/cross_db_percentile.sql`, `macros/generate_schema_name.sql`) handling BigQuery-specific dataset namespacing and quantile calculations.
- **Schema Control:** Custom schema prefixes (`careflow_staging`, `careflow_intermediate`, `careflow_marts`) enforced automatically via dbt configuration.

---

## 5. Pipeline Flow: Raw → Staging → Intermediate → Marts

| Layer | Model | Type | Grain | Purpose |
|---|---|---|---|---|
| **Source** | `careflow.raw_ehr_events` | Source Table | 1 row = 1 event record | Raw EHR log extracted from healthcare systems. |
| **Staging** | `stg_careflow__events` | View | 1 row = 1 valid event | Two-stage deduplication, schema casting, whitespace trimming. |
| **Intermediate** | `int_careflow__ordered_events` | View | 1 row = 1 sequenced event | Window functions (`LAG`, `LEAD`, `ROW_NUMBER`) per case. |
| **Intermediate** | `int_careflow__transition_metrics` | View | 1 row = 1 step transition | Measures step duration from activity A to B. |
| **Marts** | `fct_careflow__cases` | Table | 1 row = 1 patient case | Journey start/end, cycle time, full path string, repeat flag. |
| **Marts** | `mart_careflow__event_log` | Table | 1 row = 1 event | Normalized process mining log (`case_id`, `activity_name`, `timestamp`). |
| **Marts** | `mart_careflow__transitions` | Table | 1 row = 1 transition pair | Aggregates volume, duration, percentiles, and share of total process time. |
| **Marts** | `mart_careflow__bottlenecks` | Table | 1 row = 1 transition pair | Multi-signal bottleneck candidate ranking (1 to 5 signals). |
| **Marts** | `mart_careflow__conformance` | Table | 1 row = 1 case | Audits actual patient path against reference standard journey. |
| **Marts** | `mart_careflow__case_segments` | Table | 1 row = 1 case | Adds cycle time percentile ranks and flags P95+ long-duration cases. |
| **Marts** | `mart_careflow__departments` | Table | 1 row = 1 department | Department case volume, clinician counts, and cycle times. |
| **Marts** | `mart_careflow__process_paths` | Table | 1 row = 1 path variant | Frequencies and performance across distinct journey variants. |
| **Marts** | `mart_careflow__kpis` | Table | 1 row = 1 snapshot | Executive portfolio snapshot with built-in reconciliation audits. |

---

## 6. Process Mining Event Log (`mart_careflow__event_log`)
To interface seamlessly with PM4Py, Celonis, or Power BI Process Mining visuals, this mart provides the standardized three-column core specification:
- `case_id`: The process instance identifier (patient ID).
- `activity_name`: The standardized healthcare activity performed.
- `timestamp`: Chronologically ordered UTC event timestamp.
- *Operational context:* `event_id`, `event_sequence`, `department`, `doctor_id`.

---

## 7. Deduplication Logic
Raw ingestion streams frequently contain duplicate records from network retries or batch re-extractions. Deduplication is handled in `stg_careflow__events` through a deterministic two-stage windowing mechanism:
1. **Stage 1 (Technical Key Dedup):** Partitions by `event_id` ordering by `event_id`, keeping `row_number = 1`.
2. **Stage 2 (Business Key Dedup):** Partitions by `(case_id, activity_name, event_timestamp)` ordered by `event_id ASC`.
   - Resolves records identical in patient, activity, timestamp, department, and doctor but assigned differing IDs.
   - Example: `EVT019` vs. `EVT019_DUP` (both represent PAT003 Doctor Review at 2026-01-05 16:25:00). Deterministically keeps `EVT019` and drops `EVT019_DUP`.
   - **Legitimate clinical repetitions are strictly preserved:** For example, `PAT002` attends Triage at 12:10:00 (`EVT008`) and returns to Triage at 13:40:00 (`EVT012`). Because the timestamps differ, both are retained.

---

## 8. Event Sequencing
`int_careflow__ordered_events` establishes chronological order within each patient journey:
- `event_sequence`: Computed via `ROW_NUMBER() OVER (PARTITION BY case_id ORDER BY event_timestamp ASC, event_id ASC)`.
- `previous_activity` & `previous_event_timestamp`: Computed via `LAG(...)`.
- `next_activity` & `next_event_timestamp`: Computed via `LEAD(...)`.
- Boundary flags: `is_first_event` and `is_last_event` dynamically demarcate patient arrival and discharge.

---

## 9. Transition-Time Calculation
Transitions measure the handoff duration from the completion of one activity to the start of the subsequent activity:
- Duration in minutes: `TIMESTAMP_DIFF(next_event_timestamp, event_timestamp, MINUTE)` computed via `{{ dbt.datediff(...) }}`.
- Handled at the intermediate level (`int_careflow__transition_metrics`), filtering out terminal discharge events where `next_activity IS NULL`.
- Negative durations and NULL durations are tracked as explicit audit metrics.

---

## 10. Case-Level Wait & Cycle-Time Calculation
`fct_careflow__cases` aggregates event sequences into case-level journey facts:
- `cycle_time_minutes`: `TIMESTAMP_DIFF(last_event_timestamp, first_event_timestamp, MINUTE)`.
- `event_count`: Total events per case.
- `unique_activity_count`: Distinct activities performed.
- `has_repeated_activity`: Flagged `TRUE` if `unique_activity_count < event_count` (e.g. PAT002).
- `process_path`: Reconstructed journey string using `STRING_AGG(activity_name, ' → ' ORDER BY event_sequence)`.

---

## 11. Multi-Signal Bottleneck Detection Methodology
Rather than relying on a single metric (or arbitrary hard-coded thresholds), `mart_careflow__bottlenecks` evaluates transitions across **five data-driven signals** derived from dataset distributions:
1. **Signal 1 — High Typical Duration:** Median duration exceeds the median across all transitions.
2. **Signal 2 — High Tail Risk:** P95 duration exceeds the median P95 across all transitions.
3. **Signal 3 — High Volume:** Transition count exceeds median transition frequency.
4. **Signal 4 — High Process Time Share:** Share of total elapsed hospital transition time exceeds median share.
5. **Signal 5 — High Variability:** Standard deviation exceeds median duration variance.

### Bottleneck Classification:
- **Strong Candidate:** Triggers $\ge 3$ signals.
- **Moderate Candidate:** Triggers 2 signals.
- **Weak Candidate:** Triggers 1 signal.
- **No Signal:** Triggers 0 signals.

*Observed finding:* The transition `Doctor Assessment → X-Ray` represents the single largest consumer of total patient transition time (~28.8% of all transition duration).

---

## 12. Conformance Auditing & Non-Compliance Flagging
`mart_careflow__conformance` evaluates each journey against the documented standard linear pathway:
$$\text{Registration} \rightarrow \text{Triage} \rightarrow \text{Doctor Assessment} \rightarrow \text{X-Ray} \rightarrow \text{Doctor Review} \rightarrow \text{Discharge}$$

### Audit Checks:
- `is_path_compliant`: Flagged `TRUE` when the actual sequence matches the ideal reference pathway exactly.
- `missing_activities`: Detects omission of any mandatory step.
- `has_unexpected_activities`: Detects unapproved or anomalous clinical procedures.
- `has_ordering_violation`: Detects out-of-order execution (e.g., review before assessment).
- `conformance_status`: Categorizes cases into `Compliant` (e.g. PAT001, PAT003) vs. `Non-Compliant` (e.g. PAT002 due to loopback re-triage).
- *Clinical Disclaimer:* Clearly documents that the reference journey is an analytical baseline derived from standard EHR paths, not an official clinical practice guideline.

---

## 13. Data Quality & Integrity Testing
The test suite consists of **132 automated dbt tests**:
- **Generic Schema Tests:** `not_null`, `unique`, and `accepted_values` on all primary keys, foreign keys, timestamps, and categorical dimensions.
- **Custom Data Quality Tests (`tests/`):**
  - `test_ordered_events_chronological_order`: Guarantees timestamp monotonicity within cases.
  - `test_ordered_events_sequence_integrity`: Validates contiguous 1-to-N numbering without gaps.
  - `test_ordered_events_lag_lead_logic`: Verifies bidirectional consistency of window pointers.
  - `test_transition_metrics_reconciliation`: Enforces transition count = non-final event count.
  - `test_transition_metrics_negative_duration_audit`: Flags temporal anomalies.
  - `test_transition_metrics_null_duration_audit`: Ensures completeness of non-terminal durations.
  - `test_cases_activity_count_logic`: Verifies unique activity count $\le$ total event count.
  - `test_cases_repeat_activity_flag`: Confirms mathematical equivalence of repeat flag logic.
  - `test_transitions_transition_count_gte_case_count`: Validates occurrence count $\ge$ distinct cases.
  - `test_process_paths_case_totals`: Verifies path volume sums to total cohort.
  - `test_kpi_positive_totals`: Reconciles overall event and case metrics.
  - `test_bottlenecks_transition_names_not_null`: Ensures zero nulls in candidate bottleneck ranking.

---

## 14. BigQuery Datasets & Permissions
- **Warehouse:** `careflow-507606`
- **Region / Location:** `US`
- **Datasets:**
  - `careflow`: Ingestion source table `raw_ehr_events`
  - `careflow_staging`: Staging views
  - `careflow_intermediate`: Intermediate transformation views
  - `careflow_marts`: Analytical reporting tables

---

## 15. How to Run Against BigQuery

### Prerequisites
1. Google Cloud SDK installed and authenticated:
   ```bash
   gcloud auth application-default login
   ```
2. Python virtual environment active with `dbt-bigquery`:
   ```bash
   pip install dbt-bigquery
   ```

### Execution Commands
Navigate to the dbt project folder (`careflow_project/dbt_careflow`):

```bash
# 1. Verify credentials and BigQuery connectivity
dbt debug --profiles-dir .

# 2. Parse and validate YAML schema files
dbt parse --profiles-dir .

# 3. Compile Jinja/SQL models to BigQuery dialect
dbt compile --profiles-dir .

# 4. Build all models and execute the complete test suite
dbt build --profiles-dir .
```

---

## 16. Important Analytical Assumptions
1. **Grain Consistency:** The raw EHR event stream represents one event per row.
2. **Deduplication Priority:** Technical duplicates sharing `(case_id, activity_name, event_timestamp)` are resolved deterministically by choosing the lowest alphanumeric `event_id`.
3. **Percentile Estimation in BigQuery:** Percentile distributions (`P50`, `P75`, `P90`, `P95`) in BigQuery leverage `APPROX_QUANTILES(col, 100)[OFFSET(...)]`. While DuckDB uses `PERCENTILE_CONT`, BigQuery's approximation is stable, production-standard, and statistically robust for bottleneck thresholding.

---

## 17. Known Limitations
1. **Sample Extract Size:** The current demonstration EHR extract contains 21 raw events across 3 cases (`PAT001`, `PAT002`, `PAT003`). While the transformation pipeline is built and validated for production scale, percentile cutoffs in tiny sample sizes are sensitive to individual case durations.
2. **Monolithic Placeholder Dimensions:** In the current raw extract, `priority` and `journey_type` are populated with uniform placeholder values in staging. Once upstream EHR feeds provide dynamic triage priority scores, no pipeline code changes are required.
3. **Department Allocation:** Events are currently tagged under Emergency and Radiology; cross-hospital inpatient transfer modeling will require additional encounter identifiers.
