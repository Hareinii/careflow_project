# Day 6: Operational Performance Segmentation
## CareFlow Data Analyst Portfolio Project

**Date:** 2026-08-22  
**Stage:** Day 6 — Operational factors and case segmentation  
**Build Result:** ✅ dbt build successful

---

## 1. Overall Cycle-Time Distribution
- **Minimum:** 100.0 min
- **P25:** 102.5 min
- **Median:** 105.0 min
- **P75:** 122.5 min
- **P90:** 133.0 min
- **P95:** 136.5 min
- **Maximum:** 140.0 min

## 2. Priority & Journey-Type Analysis
- **Finding:** 100% of cases are currently tagged as Priority: "High" and Journey Type: "Normal".
- **Observation:** Because these variables are entirely monolithic (staging layer fabrications as determined in Day 5), no operational variance can be attributed to them at this stage.

## 3. Department Case-Mix Analysis
- **Finding:** Both Emergency and Radiology processed 100% of the cases (3 out of 3 cases).
- **Observation:** The case-mix is identical across both departments. No department is uniquely processing a longer or more complex case type in this sample dataset.

## 4. Process-Path Performance
We identified two distinct process paths:
1. **Standard Path (No Repeat):** Registration → Triage → Doctor Assessment → X-Ray → Doctor Review → Discharge
   - **Volume:** 2 cases (66.67%)
   - **Median Cycle Time:** 102.5 min
2. **Loopback Path (With Repeat):** Registration → Triage → Doctor Assessment → X-Ray → Doctor Review → Triage → Doctor Review → Discharge
   - **Volume:** 1 case (33.33%)
   - **Median Cycle Time:** 140.0 min

## 5. Repeat-Activity Impact
- **Observation:** Cases containing a repeated activity (Triage/Doctor Review) have a materially higher cycle time.
- **Normal Cases (No Repeat):** Median 102.5 min
- **Repeated Cases:** Median 140.0 min
- **Difference:** The presence of repeat activities is associated with a ~37.5 minute increase in median cycle time.

## 6. Long-Duration Cases (P95+ Outliers)
- **Rule Used:** Cases with cycle time >= P95 (136.5 min)
- **Finding:** Case `PAT002` (140 min) is the sole P95 outlier.
- **Key Characteristics:** This case follows the Loopback Path, containing 8 total events instead of the standard 6, confirming that process repetition is the primary driver of outlier cycle times in this dataset.

## 7. Key Observations & Business Questions
* **Observation:** The single biggest driver of cycle-time variance is the occurrence of repeated activities (specifically, re-triage and secondary doctor reviews).
* **Question:** Why did `PAT002` require a second triage and review? Is this a clinical necessity or a process breakdown?
* **Observation:** Priority and Journey Type cannot currently explain any variance because the EHR source does not provide them.
* **Question:** Can we get real historical Priority data mapped into the EHR extract so we can validate if high-priority cases are actually processed faster?

## 8. Limitations
- Association does not equal causation. While repeat activities are associated with longer cycle times, we cannot say if the repeat *caused* the delay or if a clinical complication caused *both* the repeat and the delay.
- The sample size is extremely small (3 cases), meaning P95 thresholds are highly sensitive to single data points.
