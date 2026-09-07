# CareFlow

## Project Overview

CareFlow is an end-to-end healthcare data engineering and process mining analytics platform designed to analyze patient journeys, clinical bottlenecks, transition wait times, and pathway conformance across hospital departments.

Emergency department crowding, delayed clinician assessments, radiology turnaround lags, and repeated triage consultations inflate total patient cycle times and jeopardize operational efficiency. CareFlow provides a standardized, reliable data engineering foundation to convert raw Electronic Health Record (EHR) event streams into structured event logs and analytical marts for process discovery and executive decision support.

---

## Project Architecture

The CareFlow production pipeline is built exclusively on **Google Cloud BigQuery** and **dbt (data build tool)**:

```
Python simulated EHR / event data
        ↓
Google BigQuery raw layer (careflow.raw_ehr_events)
        ↓
dbt staging (careflow_staging.stg_careflow__events)
        ↓
dbt intermediate transformations (careflow_intermediate)
        ↓
dbt marts / analytical layer (careflow_marts)
        ↓
Event_Log + process/conformance metrics
        ↓
PM4Py process mining + Power BI analytics/dashboard
```

### Production Warehouse
* **Authoritative Warehouse**: Google BigQuery (`careflow-507606`, region `US`).
* **Production Transformation Engine**: dbt running against BigQuery using OAuth/Service Account authentication.
* **Historical Development Note**: DuckDB was utilized during early exploratory local development as a local baseline. DuckDB is **no longer part of the production transformation path**, and all models, macros, and tests execute directly against BigQuery.

---

## Person 2 — dbt / SQL Transformation Layer

**Role**: Person 2 — Transformation Lead: dbt, SQL & Event Log Normalization

Person 2 owns the entire transformation and analytics engineering layer that bridges raw BigQuery EHR event ingestion and downstream consumption by PM4Py process mining (Person 3) and Power BI dashboards (Person 4).

### Core Responsibilities
1. **BigQuery source integration**: Connecting dbt to Google BigQuery datasets and source tables.
2. **dbt project structure and configuration**: Defining project models, custom schemas, materialization strategies, and macro libraries.
3. **Source definitions**: Specifying YAML schema sources, descriptions, and data types for raw tables.
4. **Staging and timestamp cleaning**: Parsing, standardizing, and casting UTC timestamps with type safety.
5. **Event Log normalization**: Formatting event logs to the canonical schema required by process mining engines.
6. **Deduplication**: Designing deterministic deduplication logic to eliminate technical duplicate events while strictly protecting valid medical events.
7. **Chronological event ordering**: Establishing chronological sequencing, arrival/discharge boundaries, and lag/lead window pointers.
8. **Transition/wait-time calculations**: Computing handoff durations between consecutive clinical activities in seconds, minutes, and hours.
9. **Case-level metrics**: Deriving patient cycle times, total event counts, unique activity counts, and full journey path strings.
10. **Bottleneck analysis**: Developing multi-signal statistical heuristic scoring to flag and classify operational delays.
11. **Data-quality testing**: Implementing an automated testing suite comprising generic tests and custom SQL business assertions.
12. **Activity-name standardization**: Normalizing activity naming conventions across disparate clinical departments.
13. **Event_Log mart creation**: Materializing the dedicated `mart_careflow__event_log` table for PM4Py consumption.
14. **Journey conformance/non-compliance detection**: Auditing individual case paths against the project-defined reference baseline.
15. **Transformation documentation**: Authoring comprehensive model documentation, column descriptions, and lineage tracking.

---

## BigQuery Data Architecture

The project is deployed in Google Cloud project `careflow-507606` across four structured dataset layers:

| Layer | Dataset Name | Materialization | Purpose |
|---|---|---|---|
| **Raw Ingestion** | `careflow` | Table | Houses raw EHR event ingestion (`raw_ehr_events`). |
| **Staging** | `careflow_staging` | View | Houses cleaned, deduplicated, standardized views (`stg_careflow__events`). |
| **Intermediate** | `careflow_intermediate` | View | Houses sequenced events and transition duration metrics. |
| **Marts** | `careflow_marts` | Table | Houses dimensional models, event logs, KPIs, and conformance marts. |

* **Authoritative Raw Source**: `careflow-507606.careflow.raw_ehr_events` (contains 21 raw EHR records).
* dbt queries `raw_ehr_events` and compiles the staging, intermediate, and mart layers natively in BigQuery.

---

## Event Log Standardization

Process mining algorithms (e.g., Alpha Miner, Inductive Miner, Directly-Follows Graphs) require a canonical three-column core event log format:
* **`case_id`**: Identifies the unique process instance (the patient journey).
* **`activity_name`**: Identifies the clinical action or operational step performed.
* **`timestamp`**: Identifies precisely when the activity took place in chronological order.

### Transformation Operations
The transformation layer standardizes raw event data through the following operations:
* **Timestamp Normalization**: Enforces ISO-8601 UTC timestamp format via `SAFE_CAST(event_timestamp AS TIMESTAMP)`.
* **Activity Standardization**: Standardizes capitalization, trims whitespace, and validates values against an approved clinical activity list.
* **Deterministic Deduplication**: Eliminates technical duplicate events via `ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY source_row ASC) = 1`.
* **Protection of Legitimate Loopbacks**: Preserves valid clinical rework and repeated activities (e.g., repeated triage consultations) where timestamps and sequence numbers differ.
* **Chronological Sequencing**: Enforces order via `ROW_NUMBER() OVER (PARTITION BY case_id ORDER BY event_timestamp ASC, source_row ASC)`.

### Current Dataset Execution Facts
* **Raw Events Ingested**: 21 rows in `careflow.raw_ehr_events`.
* **Staging Events**: 20 rows in `careflow_staging.stg_careflow__events`.
* **Final Event Log Events**: 20 rows in `careflow_marts.mart_careflow__event_log`.
* **Technical Duplicate Dropped**: Exactly 1 record (`EVT019_DUP`), which was an identical duplicate of `EVT019` for patient `PAT003` at 16:25:00 UTC. `EVT019` was retained and `EVT019_DUP` was safely dropped.
* **Legitimate Clinical Repetitions Preserved**: Patient `PAT002` attends Triage at 10:45:00 (`EVT008`) and returns to Triage at 12:45:00 (`EVT012`), followed by a repeat Doctor Review at 13:10:00 (`EVT013`). These represent genuine clinical re-evaluations and are preserved with distinct sequence numbers.

---

## dbt Transformation Layers

```
careflow.raw_ehr_events
  │
  ▼
careflow_staging.stg_careflow__events (View)
  │
  ├─────────────────────────────────────────┐
  ▼                                         ▼
careflow_intermediate.                  careflow_intermediate.
int_careflow__ordered_events (View)     int_careflow__transition_metrics (View)
  │                                         │
  ├─────────────────────────────────────────┴─────────────────────────────────────────┐
  ▼                                                                                   ▼
careflow_marts (Tables)                                                             careflow_marts (Tables)
  ├─ mart_careflow__event_log (Normalized Event Log)                                  ├─ mart_careflow__transitions (Aggregated Steps)
  ├─ fct_careflow__cases (Case Facts & Cycle Times)                                   ├─ mart_careflow__bottlenecks (Multi-Signal Scoring)
  ├─ mart_careflow__process_paths (Path Frequencies)                                  ├─ mart_careflow__departments (Department Volumes)
  ├─ mart_careflow__conformance (Pathway Audit)                                       ├─ mart_careflow__case_segments (Outlier Tiers)
  └─ mart_careflow__kpis (Executive Summary & Reconciliations)
```

### Staging Layer
* **`stg_careflow__events`** (View): Ingests `careflow.raw_ehr_events`. Trims whitespace, cleans strings, validates timestamps, and performs primary key deduplication.

### Intermediate Layer
* **`int_careflow__ordered_events`** (View): Adds `event_sequence` within each case, assigns `previous_activity`, `next_activity`, and timestamp pointers using `LAG` and `LEAD`, and flags repeated activities and case boundaries (`is_first_event`, `is_last_event`).
* **`int_careflow__transition_metrics`** (View): Computes handoff durations (`duration_seconds`, `transition_duration_minutes`, `duration_hours`) between activity pairs. Filters out terminal discharge events where `next_activity IS NULL`.

### Marts Layer
* **`mart_careflow__event_log`** (Table): Canonical normalized event log prepared for PM4Py (`case_id`, `activity_name`, `timestamp`, `lifecycle_status`, `event_id`, `department`, `doctor_id`).
* **`fct_careflow__cases`** (Table): Case-level grain containing journey start/end times, total cycle time in minutes, event counts, repeated activity flags, and reconstructed pathway strings (`process_path`).
* **`mart_careflow__process_paths`** (Table): Aggregates patient path variants, frequency shares, and min/avg/max cycle times per path.
* **`mart_careflow__transitions`** (Table): Aggregates transition-level statistics including mean duration, quantile distribution (P50, P75, P90, P95), total duration sum, and share of total hospital transition time.
* **`mart_careflow__bottlenecks`** (Table): Evaluates transition performance against multi-signal criteria to classify operational delay points.
* **`mart_careflow__conformance`** (Table): Compares each patient's actual pathway against the analytical reference baseline, auditing missing steps, unexpected steps, ordering violations, and repeat loops.
* **`mart_careflow__departments`** (Table): Analyzes event counts, unique patient volumes, clinician headcounts, and transition performance by department.
* **`mart_careflow__case_segments`** (Table): Segments patient journeys into performance quartiles and flags P95+ long-stay outliers.
* **`mart_careflow__kpis`** (Table): Consolidated single-row executive summary table containing high-level operational KPIs and internal reconciliation audits.

---

## Analytical Metrics

The transformation layer calculates and models the following operational metrics:

1. **Event Ordering & Boundaries**: Sequential order (1 to N), arrival event demarcation, and discharge event demarcation.
2. **Transition Duration**: Precise elapsed time between the completion of activity $A$ and the start of activity $B$ computed via `TIMESTAMP_DIFF`.
3. **Case Wait Time & Cycle Time**:
   * Total Case Cycle Time: Elapsed time from initial Registration to final Discharge.
   * Total Case Wait Time: Sum of transition durations across non-final activities.
4. **Transition Aggregations**:
   * Average duration (minutes).
   * Percentile distributions: Median (P50), 75th percentile (P75), 90th percentile (P90), and 95th percentile (P95).
   * Total transition time sum and percentage share of overall system transition duration.
5. **Quantile Calculation Semantics**:
   * In BigQuery, percentile metrics are computed using `APPROX_QUANTILES(column, 100)[OFFSET(p*100)]` via the macro `macros/cross_db_percentile.sql`.
   * **Important**: These metrics represent **approximate percentiles** over the distribution, standard for large-scale BigQuery analytics, and must **not** be characterized as continuous exact percentiles.
6. **Reconciliation Audits**:
   * Built-in sanity checks reconciling total transitions against `total_events - total_cases`.
   * Monotonicity checks ensuring zero negative transition durations.

---

## Bottleneck Analysis

Bottlenecks are evaluated in `mart_careflow__bottlenecks` using a data-driven heuristic based on four statistical signals:
1. **Signal 1 — High Typical Duration**: Median duration $\ge$ median of all transitions.
2. **Signal 2 — High Tail Delay**: P95 duration $\ge$ median P95 of all transitions.
3. **Signal 3 — High Process Time Share**: Share of total system transition time $\ge 15\%$.
4. **Signal 4 — High Transition Volume**: Transition frequency $\ge$ median transition count.

### Candidate Categories
* **Strong Candidate**: 3 or 4 signals triggered.
* **Moderate Candidate**: 2 signals triggered.
* **Weak Candidate**: 1 signal triggered.
* **No Signal**: 0 signals triggered.

### Observed Bottleneck Candidates (Current Sample Dataset)
1. **`Triage → Doctor Assessment`**:
   * **Category**: **Strong Candidate** (4 signals triggered).
   * **Observations**: Highest total transition wait time in current sample (~30.0 minutes total across cases; average ~15.0 minutes). Represents a primary front-door delay point.
2. **`X-Ray → Doctor Review`**:
   * **Category**: **Strong Candidate** (3 signals triggered).
   * **Observations**: High average transition delay (~16.67 minutes); substantial tail delay awaiting clinician re-evaluation.
3. **`Registration → Triage`**:
   * **Category**: **Weak Candidate** (1 signal triggered).
   * **Observations**: Average delay ~11.67 minutes with low variance.

*Disclaimer*: These represent data-driven analytical candidates derived from the current simulated demonstration dataset, not definitive clinical or organizational conclusions.

---

## Journey Conformance

### Project-Defined Analytical Reference Baseline
The project defines a baseline linear clinical pathway for conformance auditing:
$$\text{Registration} \longrightarrow \text{Triage} \longrightarrow \text{Doctor Assessment} \longrightarrow \text{X-Ray} \longrightarrow \text{Doctor Review} \longrightarrow \text{Discharge}$$

> [!IMPORTANT]
> **Clinical Disclaimer**: This pathway is a **project-defined analytical reference baseline** established for demonstration and process mining conformance auditing. It is **not** an official clinical practice guideline or authoritative medical mandate.

### Conformance Analysis Results (Current 3-Case Demonstration Dataset)
* **Compliant Cases (2 / 3, 66.67%)**:
  * **`PAT001`**: Exactly matches the 6-step reference sequence. Total cycle time: 65.0 minutes.
  * **`PAT003`**: Exactly matches the 6-step reference sequence. Total cycle time: 100.0 minutes.
* **Non-Compliant Cases (1 / 3, 33.33%)**:
  * **`PAT002`**: Exhibits a clinical loopback/rework pattern:
    $$\text{Registration} \to \text{Triage} \to \text{Doctor Assessment} \to \text{X-Ray} \to \text{Doctor Review} \to \mathbf{Triage} \to \mathbf{Doctor\ Review} \to \text{Discharge}$$
  * **Reason for Non-Compliance**: Contains 8 events and 2 repeated activity instances (return to Triage and secondary Doctor Review), resulting in an elevated cycle time of 190.0 minutes.
* **Observed Non-Compliance Rate**: **33.33%** (1 out of 3 cases).

### Note on Loopback Rate
The broader project specification outlines a simulated 40% return-to-Triage pattern across larger patient cohorts. In the current 3-case demonstration dataset, exactly 1 case exhibits the loopback, which mathematically yields **33.33%**. In accordance with data integrity principles, the KPI mart and documentation report the actual observed rate of 33.33% rather than forcing an unobserved 40% figure.

---

## Data Quality & Testing

The repository features an automated testing framework comprising **132 data quality tests** across all staging, intermediate, and mart models.

### Final Runtime Test Validation Results
```text
PASS = 144
WARN = 0
ERROR = 0
SKIP = 0
NO-OP = 0
REUSED = 0
TOTAL = 144
```
*(Comprising 12 dbt models and 132 automated data tests executed against BigQuery).*

### Test Suite Coverage
* **Nullability Validation**: 66 `not_null` assertions verifying essential keys, timestamps, and activity dimensions.
* **Uniqueness Constraints**: 14 `unique` assertions ensuring primary key integrity (`event_id`, `case_id`, `transition_name`, etc.).
* **Value Set Membership**: `accepted_values` tests confirming valid activity names, priority categories, and bottleneck classifications.
* **Chronological Monotonicity**: `test_ordered_events_chronological_order` guarantees non-decreasing timestamps within every patient journey.
* **Sequence Integrity**: `test_ordered_events_sequence_integrity` confirms contiguous sequence numbering without gaps.
* **Window Logic Consistency**: `test_ordered_events_lag_lead_logic` confirms bidirectional accuracy between `previous_activity` and `next_activity`.
* **Duration Sanity**: `test_transition_metrics_negative_duration_audit` asserts zero negative transition durations.
* **Completeness Validation**: `test_transition_metrics_null_duration_audit` ensures durations exist for all non-terminal events.
* **Mathematical Identity Tests**:
  * `test_cases_activity_count_logic`: Asserts `unique_activity_count <= event_count`.
  * `test_cases_repeat_activity_flag`: Confirms `has_repeated_activity = (unique_activity_count < event_count)`.
  * `test_transition_metrics_reconciliation`: Verifies `total_transitions = non_final_events`.
  * `test_process_paths_case_totals`: Verifies path variant case counts sum exactly to cohort size.
  * `test_kpi_positive_totals`: Reconciles overall event, case, and duration metrics.

---

## Current Validation Results

The transformation layer has been verified end-to-end via:
1. `dbt debug --target prod`: Confirmed BigQuery project connectivity and IAM privileges.
2. `dbt parse --target prod`: Validated schema YAML definitions and macro syntax.
3. `dbt compile --target prod`: Compiled SQL queries to BigQuery-compliant SQL dialect.
4. `dbt build --target prod`: Successfully materialized all views/tables and passed 100% of data tests.
5. BigQuery Table Query Audits: Confirmed record counts and field schemas directly in BigQuery.

### Current Object Counts in BigQuery
| BigQuery Object | Object Type | Verified Row Count |
|---|:---:|:---:|
| `careflow.raw_ehr_events` | Table (Raw Source) | **21** |
| `careflow_staging.stg_careflow__events` | View (Staging) | **20** |
| `careflow_intermediate.int_careflow__ordered_events` | View (Intermediate) | **20** |
| `careflow_intermediate.int_careflow__transition_metrics` | View (Intermediate) | **17** |
| `careflow_marts.fct_careflow__cases` | Table (Mart) | **3** |
| `careflow_marts.mart_careflow__event_log` | Table (Mart) | **20** |
| `careflow_marts.mart_careflow__process_paths` | Table (Mart) | **2** |
| `careflow_marts.mart_careflow__transitions` | Table (Mart) | **7** |
| `careflow_marts.mart_careflow__bottlenecks` | Table (Mart) | **7** |
| `careflow_marts.mart_careflow__departments` | Table (Mart) | **2** |
| `careflow_marts.mart_careflow__case_segments` | Table (Mart) | **3** |
| `careflow_marts.mart_careflow__kpis` | Table (Mart) | **1** |
| `careflow_marts.mart_careflow__conformance` | Table (Mart) | **3** |

*(Note: These figures reflect the current simulated demonstration dataset).*

---

## Downstream Integration

Person 2's transformation layer establishes clean, standardized, analytics-ready models for downstream team members:

* **Person 3 — PM4Py Process Mining**:
  * Consumes `careflow_marts.mart_careflow__event_log`.
  * Executes process discovery (Directly-Follows Graphs, Heuristic Miner, Petri Nets), variant analysis, and token-based replay conformance checking.
* **Person 4 — Power BI / Dashboard Analytics**:
  * Consumes `careflow_marts.fct_careflow__cases`, `mart_careflow__bottlenecks`, `mart_careflow__transitions`, `mart_careflow__conformance`, and `mart_careflow__kpis`.
  * Visualizes clinical cycle times, bottleneck candidate rankings, pathway conformance compliance rates, and department workload distributions.

*(Note: Person 2 is strictly responsible for the transformation and data modeling layer; Person 3 and Person 4 own their respective process mining and visualization components).*

---

## Business Value

The transformation models enable hospital administration and clinical operations leads to answer critical workflow questions:
1. **Where do patients wait the longest?** Identifies that `Triage → Doctor Assessment` consumes the highest cumulative waiting time (~30 minutes).
2. **Which transitions are candidate bottlenecks?** Flags `Triage → Doctor Assessment` (4 signals) and `X-Ray → Doctor Review` (3 signals) as primary targets for operational intervention.
3. **What is total patient cycle time?** Quantifies that compliant patient journeys average 82.5 minutes, whereas loopback re-triage journeys extend to 190.0 minutes (+130% duration).
4. **Are patients following standard pathways?** Directly segments compliant pathways (66.67%) from rework loops (33.33%).
5. **Is the data reliable?** Guarantees zero negative wait times, zero duplicate events, monotonic timestamps, and full transition reconciliation through 132 automated tests.

---

## Assumptions & Analytical Limitations

1. **Simulated Demonstration Data**: The current dataset contains simulated healthcare event records created for project demonstration purposes.
2. **Project-Defined Baseline**: The reference clinical pathway is an analytical baseline defined for demonstration and process mining conformance auditing, not an official clinical guideline.
3. **Cohort Sample Size**: The active extract contains 3 patient cases and 21 raw events. Percentages and durations reflect this demonstration sample and should not be extrapolated to real hospital populations.
4. **BigQuery Quantiles**: Percentile metrics are calculated using BigQuery `APPROX_QUANTILES` semantics and represent statistical approximations rather than continuous exact percentiles.
5. **Selective Deduplication**: Deduplication drops only verified technical duplicate records (`EVT019_DUP`); medically valid repeat visits and clinical loopbacks are strictly retained.
6. **BigQuery Production Warehouse**: All models, schemas, and tests execute natively in Google Cloud BigQuery. DuckDB was an earlier local development baseline and is not part of the production pipeline.

---

## Repository Structure

```
dbt_careflow/
├── README.md                                 # Technical architecture & project documentation
├── dbt_project.yml                           # dbt project configurations and schema settings
├── macros/
│   ├── cross_db_percentile.sql               # BigQuery APPROX_QUANTILES percentile macro
│   └── generate_schema_name.sql              # Schema namespacing macro (staging, intermediate, marts)
├── models/
│   ├── staging/
│   │   ├── _stg_careflow__sources.yml        # BigQuery raw source definitions and column types
│   │   ├── _stg_careflow__models.yml         # Staging schema tests and documentation
│   │   └── stg_careflow__events.sql          # Staging view with deduplication and timestamp parsing
│   ├── intermediate/
│   │   ├── _int_careflow__models.yml         # Intermediate schema tests and documentation
│   │   ├── int_careflow__ordered_events.sql  # Event sequencing, lag/lead pointers, repeat flags
│   │   └── int_careflow__transition_metrics.sql # Activity-pair transition duration metrics
│   └── marts/
│       ├── fct_careflow__cases.sql           # Case-level journey facts and cycle times
│       ├── fct_careflow__cases.yml           # Case mart schema tests
│       ├── mart_careflow__event_log.sql      # Canonical normalized PM4Py event log
│       ├── mart_careflow__event_log.yml      # Event log schema tests
│       ├── mart_careflow__process_paths.sql  # Process path variant aggregation
│       ├── mart_careflow__transitions.sql    # Transition duration metrics and quantiles
│       ├── mart_careflow__bottlenecks.sql    # Multi-signal bottleneck candidate ranking
│       ├── mart_careflow__departments.sql    # Department-level volumes and clinician counts
│       ├── mart_careflow__case_segments.sql  # Case duration segmentation and outlier tiers
│       ├── mart_careflow__kpis.sql           # Executive KPI snapshot and audit reconciliation
│       ├── mart_careflow__conformance.sql    # Step-by-step pathway conformance auditing
│       ├── mart_careflow__conformance.yml    # Conformance schema tests
│       └── mart_careflow__day4.yml           # Transition, bottleneck, and KPI schema tests
└── tests/                                    # Custom data quality assertion tests (12 custom tests)
    ├── test_bottlenecks_transition_names_not_null.sql
    ├── test_cases_activity_count_logic.sql
    ├── test_cases_repeat_activity_flag.sql
    ├── test_kpi_positive_totals.sql
    ├── test_ordered_events_chronological_order.sql
    ├── test_ordered_events_lag_lead_logic.sql
    ├── test_ordered_events_sequence_integrity.sql
    ├── test_process_paths_case_totals.sql
    ├── test_transition_metrics_negative_duration_audit.sql
    ├── test_transition_metrics_null_duration_audit.sql
    ├── test_transition_metrics_reconciliation.sql
    └── test_transitions_transition_count_gte_case_count.sql
```

---

## Running the dbt Transformation Layer

### Prerequisites
* Google Cloud SDK installed and authenticated (`gcloud auth application-default login`).
* Python environment with `dbt-bigquery` installed.
* BigQuery project `careflow-507606` accessible with data viewer/editor permissions.

### Execution Commands
Run the following commands from the `careflow_project/dbt_careflow` directory:

```bash
# 1. Test BigQuery connectivity and profile configuration
dbt debug --profiles-dir . --target prod

# 2. Parse and validate project YAML configuration
dbt parse --profiles-dir . --target prod

# 3. Compile Jinja templating and verify BigQuery SQL generation
dbt compile --profiles-dir . --target prod

# 4. Execute all models and run the complete test suite
dbt build --profiles-dir . --target prod
```
