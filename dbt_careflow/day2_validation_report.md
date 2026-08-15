# CareFlow Day 2 Validation Report

Date: 2026-08-15
Dataset: careflow_raw_event_log.csv
Source: c:\Users\LENOVO\Downloads\careflow_raw_event_log.csv

---

## 1. Dataset Overview

### Dimensions
- **Total Rows**: 6,868 event records
- **Total Columns**: 10
- **Unique Cases**: 1,000
- **Unique Events**: 6,800 (68 duplicates)
- **Timestamp Range**: 2022-10-31 14:29:47 to 2025-08-02 17:43:06 (2.8 years)

### Column Structure
| Column | Data Type | Description |
|--------|-----------|-------------|
| event_id | STRING | Unique event identifier within case (e.g., CF00228_E05) |
| case_id | STRING | Unique patient/case journey identifier (e.g., CF00228) |
| activity_name | STRING | Healthcare activity type |
| timestamp | TIMESTAMP | Event timestamp |
| department | STRING | Department location |
| doctor_id | STRING | Clinician identifier |
| priority | STRING | Case priority level |
| journey_type | STRING | Patient journey classification |
| source_row | INTEGER | Row number from source extraction |
| source_system | STRING | Source system identifier |

---

## 2. Data Grain

**Grain Definition:** One row represents one healthcare activity or event within a patient case journey.

**Grain Verification:**
- ✅ **case_id uniqueness**: Not unique (expected — multiple events per case)
- ✅ **activity_name distribution**: 6 unique activity types across 1,000 cases
- ✅ **Events per case**: Min 6, Max 10, Mean 6.87
- ⚠️ **event_id uniqueness**: 68 duplicates identified (see section 4)

**Grain Status**: VERIFIED — One row = one event/activity for one case

---

## 3. Null / Missing Value Analysis

### Summary
**No NULL values detected in any column.**

| Column | Null Count | Null % |
|--------|-----------|--------|
| event_id | 0 | 0.0% |
| case_id | 0 | 0.0% |
| activity_name | 0 | 0.0% |
| timestamp | 0 | 0.0% |
| department | 0 | 0.0% |
| doctor_id | 0 | 0.0% |
| priority | 0 | 0.0% |
| journey_type | 0 | 0.0% |
| source_row | 0 | 0.0% |
| source_system | 0 | 0.0% |

**Assessment**: Data completeness is excellent. No missing value treatment required at source.

---

## 4. Duplicate Analysis

### Full Row Duplicates
- **Count**: 68 full-row duplicates
- **Impact**: Reduces unique events from 6,868 to 6,800
- **Pattern**: Exact duplicates (all columns identical, including source_row)

### event_id Duplicates
- **Count**: 68 event_ids appearing twice
- **Observation**: Each duplicate event_id has identical values across all columns
- **Example Duplicate**:
  - event_id: `CF00015_E06`
  - case_id: `CF00015`
  - activity_name: `Discharge`
  - timestamp: `2025-06-27 13:23:09`
  - doctor_id: `DR010`
  - Both rows have identical source_row value (16)

### case_id + activity_name + timestamp Duplicates
- **Count**: 68 natural-key duplicates
- **Interpretation**: Same case, same activity, same timestamp appearing twice

### Root Cause Assessment
The duplicates appear to be **data-loading errors** rather than genuine repeated events because:
1. All columns are identical including source_row
2. The same event_id appears multiple times with the same full context
3. Duplicate timestamps suggest no actual time-spaced repetition

### Transformation Decision
**Action**: Deduplicate by keeping only the first occurrence of each event_id.
**Rationale**: Preserves the event sequence and timeline while removing corrupt records.
**SQL Implementation**: `row_number() over (partition by event_id order by source_row) = 1`

---

## 5. Timestamp Analysis

### Timestamp Validation
| Check | Result |
|-------|--------|
| Null timestamps | 0 |
| Future timestamps | 0 |
| Duplicate timestamps | 70 |
| Invalid format | None detected |

### Timestamp Range
- **Minimum**: 2022-10-31 14:29:47
- **Maximum**: 2025-08-02 17:43:06
- **Span**: 2 years, 276 days
- **Distribution**: Events distributed across 2+ year period

### Duplicate Timestamps
- **Count**: 70 timestamp duplicates
- **Interpretation**: Multiple events can occur at the same timestamp (expected behavior)
- **Business Logic**: Different activities may be recorded simultaneously or events may not have minute-level precision

**Assessment**: PASS — All timestamps are valid and within expected range.

---

## 6. Category Analysis

### activity_name
| Activity | Count | % of Total |
|----------|-------|-----------|
| Doctor Review | 1,417 | 20.6% |
| Triage | 1,409 | 20.5% |
| Registration | 1,015 | 14.8% |
| Doctor Consultation | 1,011 | 14.7% |
| Discharge | 1,009 | 14.7% |
| X-Ray | 1,007 | 14.7% |

**Quality Check**: 
- ✅ No spelling variations detected
- ✅ No trailing spaces or case inconsistencies
- ✅ No blank strings or unknown values
- ✅ All values are clean and consistent

### priority
| Priority | Count | % of Total | Cases |
|----------|-------|-----------|-------|
| Medium | 2,329 | 33.9% | 928 |
| Low | 2,326 | 33.8% | 940 |
| High | 2,213 | 32.2% | 917 |

**Quality Check**:
- ✅ Well-balanced distribution
- ✅ No spelling variations
- ✅ No unexpected values
- ⚠️ Priority distribution is fairly uniform (note: different cases may have different priorities)

### journey_type
| Journey Type | Cases | Events | Avg Events/Case | % of Events |
|-------------|-------|--------|-----------------|------------|
| Loopback | 400 | 3,229 | 8.07 | 47.0% |
| Normal | 523 | 3,173 | 6.07 | 46.2% |
| Delayed | 77 | 466 | 6.05 | 6.8% |

**Quality Check**:
- ✅ No spelling variations
- ✅ Consistent values
- ⚠️ Loopback cases have more events per case (8.07) than Normal (6.07), suggesting Loopback cases revisit activities

### department
| Department | Cases | Events | Doctors |
|-----------|-------|--------|---------|
| Emergency | 1,000 | 6,868 | 20 |

**Quality Check**:
- ⚠️ All records are from Emergency department
- ⚠️ Dataset is department-specific, not a multi-department dataset
- Note: This may be a data extract limitation or the actual scope

### source_system
| Source System | Events |
|---------------|--------|
| WaitData.Published_F1 | 6,868 |

**Quality Check**:
- ✅ Single consistent source
- ✅ No system variation

---

## 7. Event Sequence Analysis

### Events per Case Distribution
| Metric | Value |
|--------|-------|
| Minimum events per case | 6 |
| Maximum events per case | 10 |
| Mean events per case | 6.87 |
| Median events per case | 7 |

### Activity Sequence Patterns
All cases follow a process flow involving 6 activities:
1. Registration
2. Triage
3. Doctor Consultation or Doctor Review
4. X-Ray (conditional or parallel)
5. Doctor Review (revisit)
6. Discharge

### Loopback vs Normal vs Delayed
- **Loopback cases** (n=400): Average 8.07 events per case
  - Indicates patients return to earlier process steps
  - Suggests activities are repeated or revisited
  - Potentially indicates complications or secondary processing
  
- **Normal cases** (n=523): Average 6.07 events per case
  - Closer to minimum event count
  - Suggests streamlined process flow
  - No revisits or loopbacks

- **Delayed cases** (n=77): Average 6.05 events per case
  - Comparable to Normal cases
  - Timing classification, not activity classification
  - May indicate cases that took longer from start to finish

**Assessment**: Event sequences vary by journey type, suggesting different patient pathways based on case complexity.

---

## 8. Journey Type Analysis

### Detailed Journey Type Breakdown
| Journey Type | Cases | Events | Avg Events/Case | Interpretation |
|-------------|-------|--------|-----------------|-----------------|
| Normal | 523 | 3,173 | 6.07 | Streamlined patient flow without complications |
| Loopback | 400 | 3,229 | 8.07 | Patient returned for additional/repeat activities |
| Delayed | 77 | 466 | 6.05 | Case took longer than expected (timing-based) |

**Key Insight**: Loopback cases have significantly more events (8.07 vs 6.07), suggesting operational complexity or patient complications requiring additional processing.

---

## 9. Department Analysis

### Department Distribution
- **Single Department**: Emergency
- **All 6,868 events** originate from Emergency department
- **All 1,000 cases** processed through Emergency

### Doctor Distribution within Department
| Metric | Value |
|--------|-------|
| Unique doctors in Emergency | 20 |
| Average events per doctor | 343 |
| Busiest doctor (DR009) | 383 events |
| Least busy doctor | ~300 events |

**Assessment**: Doctor workload is relatively balanced, with variations ±25% from mean.

---

## 10. Priority Analysis

### Priority Distribution Across Cases and Events
| Priority | Cases | % of Cases | Events | % of Events | Avg Events/Case |
|----------|-------|-----------|--------|-----------|-----------------|
| High | 917 | 91.7% | 2,213 | 32.2% | 2.41 |
| Low | 940 | 94.0% | 2,326 | 33.8% | 2.47 |
| Medium | 928 | 92.8% | 2,329 | 33.9% | 2.51 |

**Quality Check**:
- ✅ Well-balanced across all priorities
- ✅ No skew toward one priority level
- ⚠️ Priority distribution may be from dataset sample, not real-world distribution

**Note**: Priority analysis should NOT be used to determine case speed or performance without confirmation from business stakeholders.

---

## 11. Doctor ID Analysis

### Doctor Distribution
| Metric | Value |
|--------|-------|
| Total unique doctors | 20 |
| Total cases | 1,000 |
| Average cases per doctor | 50 |
| Average events per doctor | 343 |

### Top 10 Doctors by Event Count
| Doctor | Events | Cases | Avg Events/Case |
|--------|--------|-------|-----------------|
| DR009 | 383 | 328 | 1.17 |
| DR001 | 382 | 322 | 1.19 |
| DR015 | 357 | 302 | 1.18 |
| DR020 | 353 | 311 | 1.14 |
| DR006 | 352 | 309 | 1.14 |
| DR005 | 352 | 309 | 1.14 |
| DR014 | 349 | 306 | 1.14 |
| DR004 | 348 | 302 | 1.15 |
| DR003 | 347 | 294 | 1.18 |
| DR011 | 346 | 300 | 1.15 |

**Assessment**: Doctor workload variation is minimal (±12% from mean), suggesting balanced case distribution.

---

## 12. Key Data-Quality Findings

### Actual Errors
1. **68 Duplicate Records**: Full-row duplicates with identical event_id, case_id, activity, timestamp, and doctor
   - **Severity**: High
   - **Impact**: Inflates event counts and distorts timing metrics
   - **Resolution**: Deduplicate in staging layer by keeping first occurrence

### Potential Anomalies
1. **Single Department Only**: All records from Emergency department
   - **Note**: May be correct if data is filtered to Emergency only
   - **Recommendation**: Verify with data source team

2. **Loopback cases have more events**: Loopback journey type averages 8.07 events vs 6.07 for Normal
   - **Interpretation**: Expected if loopback means return to earlier activities
   - **Business validation**: Confirm with clinical team

3. **Delayed journey type low volume**: Only 77 cases (7.7% of total) classified as Delayed
   - **Observation**: May be rare edge case or filtered dataset
   - **Note**: Delayed is timing-based, not activity-based

### Business Questions Requiring Validation
1. **What determines journey_type classification?**
   - Is it pre-assigned or calculated after case completion?
   - What defines "Delayed" vs "Normal" timing threshold?

2. **What is the business meaning of "Loopback"?**
   - Is it patient returning after discharge?
   - Is it administrative re-triage?
   - Or readmission?

3. **Why are all departments labeled "Emergency"?**
   - Is dataset filtered to Emergency only?
   - Or are all activities labeled Emergency by default?

4. **How should duplicate events be handled?**
   - Are these system errors or re-records?
   - Should they be flagged for investigation instead of silently deduplicated?

---

## 13. Transformation Decisions

### Decision 1: Deduplication
**Issue**: 68 full-row duplicate records
**Decision**: Deduplicate by keeping first occurrence of each event_id
**Rationale**: 
- All columns are identical, suggesting data-loading error
- Deduplication preserves timeline (using source_row for ordering)
- Maintains referential integrity

**Implementation**:
```sql
row_number() over (partition by event_id order by source_row) = 1
```

### Decision 2: Column Naming
**Standard**: Convert to lowercase snake_case
- `timestamp` → `event_timestamp` (clarifies event context)
- All other columns remain in snake_case

### Decision 3: String Trimming
**Action**: Trim all string columns to remove leading/trailing whitespace
**Rationale**: Prevents category matching issues in downstream models

### Decision 4: Type Casting
**Action**: Explicit casting of all columns to intended types
- Strings → STRING (with TRIM)
- Timestamps → TIMESTAMP
- Integers → INT64

---

## 14. Raw BigQuery Schema

### Recommended Schema for careflow_raw.event_log
```sql
create table if not exists `project.careflow_raw.event_log` (
    event_id STRING not null,
    case_id STRING not null,
    activity_name STRING not null,
    timestamp TIMESTAMP not null,
    department STRING not null,
    doctor_id STRING not null,
    priority STRING not null,
    journey_type STRING not null,
    source_row INT64 not null,
    source_system STRING not null
);
```

### Column-Level Specifications
| Column | Type | Nullable | Constraints | Notes |
|--------|------|----------|-------------|-------|
| event_id | STRING | No | Unique (after deduplication) | Event identifier |
| case_id | STRING | No | FK to cases dimension | Case identifier |
| activity_name | STRING | No | Valid activity types | Process step |
| timestamp | TIMESTAMP | No | UTC timezone recommended | Event timing |
| department | STRING | No | Currently all 'Emergency' | Location |
| doctor_id | STRING | No | FK to provider dimension | Healthcare provider |
| priority | STRING | No | High/Medium/Low | Case urgency |
| journey_type | STRING | No | Normal/Loopback/Delayed | Case classification |
| source_row | INT64 | No | Source line number | Data lineage |
| source_system | STRING | No | WaitData.Published_F1 | Data provenance |

---

## 15. Staging Model Specifications

### Model: stg_careflow__events
**Materialization**: View
**Source**: {{ source('careflow_raw', 'event_log') }}
**Transformations**:
1. Deduplicate by event_id (keep first by source_row)
2. Cast all columns to correct data types
3. Trim string fields
4. Rename timestamp → event_timestamp

**Output Columns**:
- event_id (STRING, unique, not null)
- case_id (STRING, not null)
- activity_name (STRING, not null)
- event_timestamp (TIMESTAMP, not null)
- department (STRING, not null)
- doctor_id (STRING, not null)
- priority (STRING, not null)
- journey_type (STRING, not null)
- source_row (INT64, not null)
- source_system (STRING, not null)

**Row Count Expected**: 6,800 (after deduplication from 6,868)

---

## 16. Open Questions for Stakeholders

1. **Data Source & Refresh**
   - How often is this dataset refreshed?
   - Is there a production data pipeline or manual export?
   - Where will the source BigQuery table live in production?

2. **Duplicate Records**
   - Are the 68 duplicate records known data quality issues?
   - Should they be flagged for investigation instead of silently removed?
   - Is there a source system identifier or timestamp to help resolve them?

3. **Department Scope**
   - Is this dataset limited to Emergency department only?
   - Will future datasets include other departments?
   - Should the department field be marked as a filter or filter it out?

4. **Journey Type Classification**
   - How is journey_type determined (at admission, at discharge, or calculated)?
   - What is the exact business definition of each type?
   - Can a case's journey_type change, or is it fixed?

5. **Waiting Time Metrics**
   - Are there any pre-calculated wait times in the source, or do we calculate from timestamps?
   - How should we calculate wait time between activities? (end of Activity A to start of Activity B)
   - Should we account for time zones or assume UTC?

6. **Case Demographics**
   - Why are patient_age and gender not in the dataset (mentioned in Day 1)?
   - Will they be added later?
   - Are they in a separate dimension table?

---

## 17. Data Quality Summary

| Category | Status | Notes |
|----------|--------|-------|
| Completeness | ✅ PASS | No NULL values detected |
| Uniqueness | ⚠️ PASS WITH CAVEAT | 68 duplicate event_ids; deduplicated in staging |
| Consistency | ✅ PASS | Consistent formatting, no spelling variations |
| Validity | ✅ PASS | All timestamps valid, no future dates |
| Accuracy | ❓ NEEDS CONFIRMATION | Cannot confirm without source verification |

---

## 18. Validation Checklist

- [x] CSV inspected and loaded
- [x] Dataset grain identified (one row = one event)
- [x] Schema profiled (10 columns, all present)
- [x] Null checks completed (0 nulls in all columns)
- [x] Duplicate checks completed (68 full-row duplicates identified)
- [x] Category analysis completed (6 activities, 3 priorities, 3 journey types)
- [x] Timestamp checks completed (valid range, no NULLs or futures)
- [x] Event sequences analyzed (6-10 events per case, mean 6.87)
- [x] Journey types profiled (Normal, Loopback, Delayed with expected event distributions)
- [x] Departments profiled (1 department: Emergency)
- [x] Doctors profiled (20 clinicians, relatively balanced workload)
- [x] Raw BigQuery schema documented
- [x] dbt source definition updated with actual columns
- [x] dbt staging model created with deduplication logic
- [x] dbt tests created for critical columns and accepted values
- [x] Transformation decisions documented
- [x] Data quality report completed

---

## 19. Next Steps (Day 3)

Day 3 should focus on:
1. **Case-level metrics**: Aggregate events to case level
2. **Process timing**: Calculate duration between activities
3. **Case flow analysis**: Model complete patient journeys
4. **Waiting time metrics**: Derive from timestamp sequences
5. **Process paths**: Identify common and anomalous case flows
6. **Mart preparation**: Design case facts and dimensions

---

## Sign-Off

**Dataset Validation**: PASSED with noted deduplication requirement
**Data Quality**: Acceptable for downstream analysis with duplicate handling
**Ready for BigQuery**: Yes
**Ready for dbt Staging**: Yes

Report generated: 2026-08-15
