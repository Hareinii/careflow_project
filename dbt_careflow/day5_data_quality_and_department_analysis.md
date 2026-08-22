# Day 5: Data Quality and Department Analysis
## CareFlow Data Analyst Portfolio Project

**Date:** 2026-08-19  
**Stage:** Day 5 — Data-quality remediation, Department KPI mart, Pattern investigation  
**Build Result:** ✅ 114 PASS | 0 WARN | 0 ERROR

---

## 1. Duplicate Investigation: EVT019 vs EVT019_DUP

### Findings
- Both records belong to `case_id` PAT003 for `activity_name` "Doctor Review".
- They share the exact same `timestamp` (2026-01-05 16:25:00), `department`, `doctor_id`, and `source_system`.
- The only difference is the `event_id` (`EVT019` vs `EVT019_DUP`).

### Classification
**A. Exact technical duplicate.** All meaningful event attributes are identical.

### Handling Decision
- **Raw Data:** Left completely untouched to preserve data provenance.
- **Staging (`stg_careflow__events`):** Implemented a two-stage deduplication process. Stage 1 deduplicates identical `event_id` values (handles ETL reloads). Stage 2 uses a business key (`case_id`, `activity_name`, `event_timestamp`) and retains the record with the lexicographically lowest `event_id`. This effectively excludes `EVT019_DUP` deterministically while maintaining pipeline integrity.

---

## 2. Department Analysis

### Methodology
A new permanent department KPI mart (`mart_careflow__departments`) was constructed with a strict grain of **one row per department**. It synthesizes event volumes, cycle times, and transition metrics without modifying the underlying raw models.

### Actual Results
| Department | Cases | Events | Unique Doctors | Avg Cycle Time (min) | Median Cycle Time (min) | Repeat Activity % |
|------------|-------|--------|----------------|----------------------|-------------------------|-------------------|
| Emergency  | 3     | 18     | 6              | 115.0                | 105.0                   | 66.67%            |
| Radiology  | 3     | 3      | 3              | 115.0                | 105.0                   | 66.67%            |

### Observations & Caveats
- **Cycle Time:** The cycle time shown (115 avg / 105 median) represents the *full case duration* for any case touching that department, not the time spent exclusively within the department.
- **Comparison Caution:** Both departments show identical cycle times because all 3 cases in the dataset passed through both Emergency and Radiology. Do not rank one department as "better" or "worse" based on these numbers; differences here reflect case mix rather than isolated department performance.

---

## 3. X-Ray → Doctor Review Investigation

### Actual Results
- **Transition Count:** 3
- **Case Count:** 3
- **Average Duration:** 30.0 min
- **Median Duration:** 30.0 min
- **P90 / P95 Duration:** 30.0 min
- **Exactly 30 Minutes:** 100% (3 of 3)
- **Within 29-31 Minutes:** 100% (3 of 3)

### Interpretation
The data confirms a strict 30-minute duration for the `X-Ray → Doctor Review` transition across all observed cases, involving 3 different doctors in the Radiology department. 

### Conclusion
This is an **observed structural timing pattern requiring business validation**. Given the zero variance (stddev = 0), this is highly likely a scheduled workflow, appointment slot length, or system-generated timestamp rule rather than organic human processing time. 
**Note:** This transition was NOT incorrectly labeled as a bottleneck. While it consumes a high share of total time, its perfect consistency suggests it is an operational design or constraint, not a variable queueing bottleneck.

---

## 4. Priority Validation

### Values & Profile
- **High:** 3 cases (100%), 21 events

### Provenance Assessment
**B. Generated/test data (Staging fabrication)**
The `priority` field is NOT present in the raw source CSV (`careflow_raw_event_log.csv`). It was hard-coded as 'High' in the staging layer during an earlier phase.

### Analytical Decision
`priority` will NOT be treated as a production analytical dimension. It will remain in the models as an exploratory placeholder attribute, but it cannot be used for any actual business KPI segmentation until real operational data is sourced.

---

## 5. Journey Type Validation

### Values & Profile
- **Normal:** 3 cases (100%), 21 events

### Provenance Assessment
**B. Generated/test data (Staging fabrication)**
Like priority, `journey_type` is NOT present in the raw source CSV and was hard-coded in staging.

### Analytical Decision
`journey_type` will NOT be treated as a production analytical dimension. It remains an exploratory attribute only. It should not be used to explain cycle time variances or process paths until genuine process categorizations are provided by the EHR system.

---

## 6. Open Business Questions
1. Can the EHR system configuration be checked to confirm if the 30-minute X-Ray turnaround is an enforced schedule slot?
2. When will the source system feed be updated to include real `priority` and `journey_type` classifications?
3. Can the upstream data engineering team investigate why `EVT019_DUP` was generated, to prevent similar technical duplicates from appearing in future extracts?
