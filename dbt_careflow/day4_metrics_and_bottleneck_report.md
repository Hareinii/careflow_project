# Day 4 Metrics and Bottleneck Report — CareFlow Data Analyst Portfolio Project

**Date:** 2026-08-19 | **Database:** DuckDB | **dbt:** 1.12.2 | **Build:** 107 PASS 0 ERROR

---

## 1. Metric Definitions

### 1.1 Transition Duration Semantics

`transition_duration_minutes` = elapsed time in minutes between two recorded events.

> This does NOT automatically mean "waiting time". Business meaning must be confirmed
> separately for each transition pair.

All percentiles use DuckDB PERCENTILE_CONT — which computes EXACT percentiles.

### 1.2 transition_count vs case_count

- `transition_count` = COUNT(*) — total transition occurrences
- `case_count` = COUNT(DISTINCT case_id) — distinct cases containing the transition

These are DIFFERENT. A loopback case contributes more than one occurrence.
Invariant: transition_count >= case_count always. This is tested and passes.

---

## 2. Transition Logic

### 2.1 Model Grain
int_careflow__transition_metrics: One row = one forward-facing transition per case.
Final events are excluded (no next event). They remain in int_careflow__ordered_events.

### 2.2 Column Mapping
| Source Column | Destination Column |
|---|---|
| activity_name | from_activity |
| next_activity | to_activity |
| event_timestamp | from_timestamp |
| next_event_timestamp | to_timestamp |
| (computed forward duration) | transition_duration_minutes |

### 2.3 Transition Name (Dynamic)
Generated as: from_activity || ' → ' || to_activity
No activity names are hard-coded.

### 2.4 Why Average Alone Is Insufficient
Example: 5, 6, 7, 8, 100 minutes
- Average = 25.2 (distorted by outlier)
- Median = 7 (typical experience)
- P95 = ~95 (long-tail risk)
Day 4 uses Average + Median + P90 + P95 together.

---

## 3. KPI Definitions and Actual Values

| KPI | Value | Definition |
|-----|-------|-----------|
| Total Cases | 3 | COUNT(DISTINCT case_id) |
| Total Events | 21 | COUNT(*) from int_careflow__ordered_events |
| Avg Events per Case | 7.0 | 21 / 3 |
| Average Cycle Time | 115.0 min | AVG(last_ts - first_ts) per case |
| Median Cycle Time | 105.0 min | PERCENTILE_CONT(0.50) — exact |
| P90 Cycle Time | 133.0 min | PERCENTILE_CONT(0.90) |
| P95 Cycle Time | 136.5 min | PERCENTILE_CONT(0.95) |
| Min Cycle Time | 100 min | PAT001 (shortest case) |
| Max Cycle Time | 140 min | PAT002 (loopback case) |
| Repeat Activity Cases | 2 | Cases where has_repeated_activity = true |
| Repeat Activity % | 66.67% | 2 / 3 * 100 |
| Unique Process Paths | 3 | One distinct path per case |

NOTE: Total Events = 21 because EVT019 and EVT019_DUP (PAT003) both survive
deduplication — they have different event_id values but identical content.
See Section 5 for data quality details.

---

## 4. Bottleneck Methodology

Five signals, each using data-driven thresholds (median of that metric across all transitions):

| Signal | Metric Used | Threshold |
|--------|------------|-----------|
| High Duration | median_duration_minutes | > median of all medians |
| High Tail Risk | p95_duration_minutes | > median of all P95s |
| High Volume | transition_count | > median of all counts |
| High Time Share | share_of_total_transition_time_pct | > median of all shares |
| High Variability | stddev_duration_minutes | > median of all stddevs |

Classification:
- 3+ signals = Strong Candidate
- 2 signals = Moderate Candidate
- 1 signal = Weak Candidate
- 0 signals = No Signal

IMPORTANT: "Strong Candidate" ≠ confirmed bottleneck. Business confirmation required.

---

## 5. Data Quality Findings

### 5.1 Null Durations: 0 (PASS)
### 5.2 Negative Durations: 0 (PASS)
### 5.3 Duplicate Event: EVT019 / EVT019_DUP

PAT003 has two events with:
- Different event_ids (EVT019 and EVT019_DUP)
- Identical: activity_name, timestamp, department, doctor_id

Current dedup logic partitions on event_id only → both survive.
Effect: "Doctor Review → Doctor Review" self-transition with 0-minute duration appears.

RECOMMENDATION: Add business-key dedup on (case_id, activity_name, event_timestamp)
in Day 5. Do NOT delete without source-system confirmation.

### 5.4 Priority / Journey Type
All cases are 'High' / 'Normal' (staging hard-codes). Segmentation meaningless until
real values are available from source.

---

## 6. Schedule Variance Interpretation

"Scheduled → Arrival" transition does NOT exist in current dataset.
If added in future:
- Negative value = arrived before scheduled time
- Positive value = arrived after scheduled time
Label: "Schedule Variance Candidate" — not a confirmed KPI until documented.

---

## 7. Candidate Waiting-Time Transitions

### 7.1 Arrival → Exam Started
Status: NOT PRESENT in current dataset. Returns NULL. Columns preserved for future.
Label: "Arrival-to-Exam Transition Duration" (NOT "Waiting Time" — not confirmed).

### 7.2 Registration → Triage (Closest Operational Equivalent)
| Metric | Value |
|--------|-------|
| Count | 3 |
| Average | 10.67 min |
| Median | 10.0 min |
| P90 | 11.6 min |
| P95 | 11.8 min |
Label: "Registration-to-Triage Transition Duration" — candidate only.

### 7.3 Doctor Assessment → X-Ray
| Metric | Value |
|--------|-------|
| Count | 3 |
| Average | 20.0 min |
| Median | 20.0 min |
| StdDev | 0.0 |
Perfectly consistent. Zero variability (see bottleneck investigation).
Label: "Assessment-to-X-Ray Transition Duration" — candidate only.

---

## 8. Reconciliation Results

| Check | Result |
|-------|--------|
| fct_careflow__cases case count = ordered_events case count | PASS (3 = 3) |
| Transition records = non-final event count | PASS (18 = 18) |

Calculation: 21 events - 3 final events (one per case) = 18 transition records.

---

## 9. Actual Results

### 9.1 Transition Summary Table

| Transition | Count | Cases | Avg (min) | Median | P90 | P95 | StdDev | Share% |
|-----------|-------|-------|-----------|--------|-----|-----|--------|--------|
| X-Ray → Doctor Review | 3 | 3 | 30.0 | 30.0 | 30.0 | 30.0 | 0.0 | 26.09% |
| Triage → Doctor Assessment | 3 | 3 | 22.67 | 23.0 | 24.6 | 24.8 | 2.52 | 19.71% |
| Doctor Review → Discharge | 3 | 3 | 20.0 | 20.0 | 20.0 | 20.0 | 0.0 | 17.39% |
| Doctor Assessment → X-Ray | 3 | 3 | 20.0 | 20.0 | 20.0 | 20.0 | 0.0 | 17.39% |
| Triage → Doctor Review | 1 | 1 | 20.0 | 20.0 | 20.0 | 20.0 | — | 5.80% |
| Registration → Triage | 3 | 3 | 10.67 | 10.0 | 11.6 | 11.8 | 1.15 | 9.28% |
| Doctor Review → Triage | 1 | 1 | 15.0 | 15.0 | 15.0 | 15.0 | — | 4.35% |
| Doctor Review → Doctor Review | 1 | 1 | 0.0 | 0.0 | 0.0 | 0.0 | — | 0.00% |

NOTE: "Doctor Review → Doctor Review" (0 min) is the EVT019/EVT019_DUP artifact. Not an operational loop.

---

## 10. Potential Bottleneck Findings

### STRONG CANDIDATES (requiring investigation)

#### Triage → Doctor Assessment — Score: 4/5 signals
Signals: High Duration | High Tail Risk | High Time Share | High Variability
Avg: 22.67 min | Median: 23.0 min | P95: 24.8 min | Share: 19.71%
StdDev: 2.52 — highest variability of all core transitions.
Duration range: 20 min (PAT001) to 25 min (PAT002) — 25% variation.
Business question: What drives the 5-minute difference between fastest and slowest?
Is it physician queue, case severity, or staffing?

#### X-Ray → Doctor Review — Score: 3/5 signals
Signals: High Duration | High Tail Risk | High Time Share
Avg: 30.0 min | Median: 30.0 min | P95: 30.0 min | Share: 26.09%
Zero variability (StdDev = 0) across all 3 cases.
This transition consumes the largest share of total process time (26%).
Zero stddev suggests a structural/systematic constraint, not random variation.
Business question: Is 30 minutes a designed X-Ray processing window, or a constraint?
Is this benchmarked against comparable facilities?

### WEAK CANDIDATES
- Doctor Review → Discharge: High time share (17.39%), no other signals
- Doctor Assessment → X-Ray: High time share (17.39%), zero variability, no concern
- Registration → Triage: Slightly high variability (StdDev 1.15), low absolute duration

---

## 11. Outlier Investigation

With only 3 cases, every value is min, median, or max. Full outlier analysis requires 50+ cases.

Known extreme values:
- Triage → Doctor Assessment max: 25 min (PAT002) — 25% above minimum
- Registration → Triage max: 12 min (PAT003) — 20% above minimum
- No extreme concentration found in a particular department or doctor

Framework for Day 5+: Apply P99 / Z-score outlier identification once richer data is loaded.

---

## 12. Open Business Questions

1. What is the clinical definition of "waiting time" in CareFlow? Is it Triage → Doctor Assessment?
2. Is the 30-minute X-Ray → Doctor Review duration a designed target or a persistent delay?
3. Should EVT019_DUP be deleted, corrected, or preserved? Source system confirmation needed.
4. Will production data include real priority and journey_type values?
5. Will future data include "Scheduled" events to enable schedule variance analysis?
6. What is the acceptable cycle time target? (Benchmark needed before performance claims.)
7. Is PAT002's Triage loopback a standard re-assessment protocol or an anomaly?

---

## 13. What Day 5 Should Address

1. Resolve EVT019_DUP — add business-key deduplication to staging
2. Department segmentation mart (using department_kpis CTE from kpis model)
3. Investigate X-Ray → Doctor Review 30-minute consistency (schedule constraint?)
4. Enrich source data with real priority / journey_type / Scheduled events
5. Outlier framework (P99, Z-score) with larger dataset
6. Doctor-level metrics (with appropriate confounding factor controls)
7. Schedule adherence analysis (if Scheduled events become available)
