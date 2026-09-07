/*
=============================================================================
MODEL: mart_careflow__kpis
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Overall project KPI foundation. Provides a single-row reporting snapshot
of the core CareFlow process metrics, along with segmented breakdowns for
department and priority to support Day 5 analysis.

GRAIN
-----
One row = one overall reporting snapshot (the "header" section).
The department_kpis and priority_kpis CTEs are output as separate sections
and are DOCUMENTED here for Day 5 use, not as separate tables yet.

SOURCES
-------
  fct_careflow__cases            — case-level metrics
  int_careflow__ordered_events   — event-level metrics
  mart_careflow__transitions     — transition-level metrics
  mart_careflow__process_paths   — path analysis

KPI DEFINITIONS (per Day 4 specification)
-----------------------------------------

  total_cases
    Number of distinct case_id values in fct_careflow__cases.

  total_events
    Number of event records in int_careflow__ordered_events.

  average_cycle_time_minutes
    Average of (last_event_timestamp - first_event_timestamp) per case.
    Measured in minutes. Computed from fct_careflow__cases.cycle_time_minutes.

  median_cycle_time_minutes
    50th percentile of case cycle time. Exact via PERCENTILE_CONT.

  p90_cycle_time_minutes
    90th percentile of case cycle time.

  p95_cycle_time_minutes
    95th percentile of case cycle time.

  minimum_cycle_time_minutes / maximum_cycle_time_minutes
    Min and max case cycle times. Identifies the range of observed performance.

  average_events_per_case
    total_events / total_cases. A proxy for process complexity.

  repeat_activity_case_count
    Number of cases where has_repeated_activity = true.

  repeat_activity_case_percentage
    repeat_activity_case_count / total_cases * 100.

  unique_process_path_count
    Number of distinct process_path values. High count suggests high variability.

TRANSITION KPI CANDIDATES
--------------------------
The following are included as CANDIDATE metrics pending business confirmation:

  arrival_to_exam_* columns:
    The dataset does not contain activities named "Arrival" or "Exam Started".
    Therefore these columns return NULL with a note column documenting this.
    They are preserved for forward compatibility when richer data is available.

  registration_to_triage_* columns:
    The closest operational equivalent in this dataset to "front-of-process" timing.
    Labeled "candidate metric" — not confirmed as a KPI definition.

  doctor_assessment_to_xray_* columns:
    Represents the diagnostic initiation transition.
    Labeled "candidate metric" — not confirmed as a KPI definition.

DEPARTMENT AND PRIORITY BREAKDOWNS
------------------------------------
Included as sub-queries within this model for Day 5 readiness.
These are NOT separate mart tables yet. Day 5 should promote them
to their own mart models with fuller segmentation.

=============================================================================
*/

with cases as (

    select * from {{ ref('fct_careflow__cases') }}

),

ordered_events as (

    select * from {{ ref('int_careflow__ordered_events') }}

),

transition_metrics as (

    select * from {{ ref('int_careflow__transition_metrics') }}

),

process_paths as (

    select * from {{ ref('mart_careflow__process_paths') }}

),

-- ============================================================
-- OVERALL KPI SNAPSHOT
-- ============================================================

kpi_snapshot as (

    select
        -- Case volume
        count(distinct case_id)                                          as total_cases,

        -- Cycle time distribution
        round(avg(cycle_time_minutes), 2)                                as average_cycle_time_minutes,
        {{ exact_percentile(0.50, 'cycle_time_minutes') }} as median_cycle_time_minutes,
        {{ exact_percentile(0.90, 'cycle_time_minutes') }} as p90_cycle_time_minutes,
        {{ exact_percentile(0.95, 'cycle_time_minutes') }} as p95_cycle_time_minutes,
        min(cycle_time_minutes)                                          as minimum_cycle_time_minutes,
        max(cycle_time_minutes)                                          as maximum_cycle_time_minutes,

        -- Repeat activity (loopbacks)
        sum(case when has_repeated_activity = true then 1 else 0 end)       as repeat_activity_case_count,
        round(
            100.0
            * sum(case when has_repeated_activity = true then 1 else 0 end)
            / nullif(count(distinct case_id), 0)
        , 2)                                                             as repeat_activity_case_percentage

    from cases

),

event_kpis as (

    select
        count(*)                                                          as total_events
    from ordered_events

),

path_kpis as (

    select
        count(distinct process_path)                                      as unique_process_path_count
    from process_paths

),

-- ============================================================
-- CANDIDATE TRANSITION KPI: Registration → Triage
-- The first operational transition visible in this dataset.
-- Named "candidate" — not a confirmed business KPI definition.
-- ============================================================

registration_to_triage_kpi as (

    select
        count(*)                                                           as reg_to_triage_count,
        round(avg(transition_duration_minutes), 2)                         as reg_to_triage_avg_minutes,
        {{ exact_percentile(0.50, 'transition_duration_minutes') }}
                                                                           as reg_to_triage_median_minutes,
        {{ exact_percentile(0.90, 'transition_duration_minutes') }}
                                                                           as reg_to_triage_p90_minutes,
        {{ exact_percentile(0.95, 'transition_duration_minutes') }}
                                                                           as reg_to_triage_p95_minutes
    from transition_metrics
    where transition_name = 'Registration → Triage'

),

-- ============================================================
-- CANDIDATE TRANSITION KPI: Doctor Assessment → X-Ray
-- Represents diagnostic initiation transition duration.
-- Named "candidate" — not a confirmed business KPI definition.
-- ============================================================

assessment_to_xray_kpi as (

    select
        count(*)                                                           as assessment_to_xray_count,
        round(avg(transition_duration_minutes), 2)                         as assessment_to_xray_avg_minutes,
        {{ exact_percentile(0.50, 'transition_duration_minutes') }}
                                                                           as assessment_to_xray_median_minutes,
        {{ exact_percentile(0.90, 'transition_duration_minutes') }}
                                                                           as assessment_to_xray_p90_minutes,
        {{ exact_percentile(0.95, 'transition_duration_minutes') }}
                                                                           as assessment_to_xray_p95_minutes
    from transition_metrics
    where transition_name = 'Doctor Assessment → X-Ray'

),

-- ============================================================
-- CANDIDATE TRANSITION KPI: Arrival → Exam Started
-- This transition does NOT exist in the current dataset.
-- Columns return NULL with documentation for future data integration.
-- ============================================================

arrival_to_exam_kpi as (

    select
        count(*)                                                           as arrival_to_exam_count,
        round(avg(transition_duration_minutes), 2)                         as arrival_to_exam_avg_minutes,
        {{ exact_percentile(0.50, 'transition_duration_minutes') }}
                                                                           as arrival_to_exam_median_minutes,
        {{ exact_percentile(0.90, 'transition_duration_minutes') }}
                                                                           as arrival_to_exam_p90_minutes,
        {{ exact_percentile(0.95, 'transition_duration_minutes') }}
                                                                           as arrival_to_exam_p95_minutes
    from transition_metrics
    where transition_name = 'Arrival → Exam Started'
    -- Returns 0-row result if transition does not exist; aggregates return NULL.

),

-- ============================================================
-- DEPARTMENT KPI FOUNDATION (Day 5 readiness)
-- Segmented cycle time and activity metrics by department.
-- Not promoted to a separate mart yet — preserved for Day 5.
-- ============================================================

department_kpis as (

    select
        department,
        count(distinct case_id)                                            as dept_case_count,
        count(event_id)                                                    as dept_event_count,
        {% set dept_cycle_diff = dbt.datediff("first_event_timestamp", "last_event_timestamp", "minute") %}
        round(avg(
            {{ dept_cycle_diff }}
        ), 2)                                                              as dept_avg_cycle_time_minutes,
        {{ exact_percentile(0.50, dept_cycle_diff) }}
                                                                           as dept_median_cycle_time_minutes,
        {{ exact_percentile(0.90, dept_cycle_diff) }}
                                                                           as dept_p90_cycle_time_minutes
    from ordered_events
    group by department

),

-- ============================================================
-- PRIORITY KPI FOUNDATION (Day 5 readiness)
-- Cycle time by priority level.
-- No causal claims — observed patterns only.
-- ============================================================

priority_kpis as (

    select
        priority,
        count(distinct case_id)                                            as priority_case_count,
        round(avg(cycle_time_minutes), 2)                                  as priority_avg_cycle_time_minutes,
        {{ exact_percentile(0.50, 'cycle_time_minutes') }}                 as priority_median_cycle_time_minutes,
        {{ exact_percentile(0.90, 'cycle_time_minutes') }}                 as priority_p90_cycle_time_minutes
    from cases
    group by priority

),

-- ============================================================
-- RECONCILIATION CHECKS (mandatory per Day 4 spec)
-- Reported as metrics within the KPI model for documentation.
-- ============================================================

reconciliation as (

    select
        -- Source events in the raw dataset after deduplication (stg layer)
        (select count(*) from ordered_events)                              as ordered_event_count,

        -- Cases in case fact table
        (select count(distinct case_id) from cases)                        as fact_case_count,

        -- Cases in ordered events model
        (select count(distinct case_id) from ordered_events)               as ordered_event_case_count,

        -- Transition records in int_careflow__transition_metrics
        (select count(*) from transition_metrics)                          as transition_record_count,

        -- Non-final events in ordered events (should equal transition records)
        (select count(*) from ordered_events where is_last_event = false)  as non_final_event_count

)

-- ============================================================
-- FINAL OUTPUT — Single-row KPI snapshot
-- ============================================================
select
    -- Overall totals
    e.total_events,
    k.total_cases,
    round(cast(e.total_events as {{ dbt.type_float() }}) / nullif(k.total_cases, 0), 2)   as average_events_per_case,

    -- Cycle time distribution
    k.average_cycle_time_minutes,
    k.median_cycle_time_minutes,
    k.p90_cycle_time_minutes,
    k.p95_cycle_time_minutes,
    k.minimum_cycle_time_minutes,
    k.maximum_cycle_time_minutes,

    -- Repeat activity
    k.repeat_activity_case_count,
    k.repeat_activity_case_percentage,

    -- Process path diversity
    p.unique_process_path_count,

    -- Candidate KPI: Registration → Triage transition duration
    -- Label: "Registration-to-Triage Transition Duration"
    -- Not confirmed as an operational waiting-time KPI.
    rt.reg_to_triage_count                                                as candidate_reg_to_triage_count,
    rt.reg_to_triage_avg_minutes                                          as candidate_reg_to_triage_avg_minutes,
    rt.reg_to_triage_median_minutes                                       as candidate_reg_to_triage_median_minutes,
    rt.reg_to_triage_p90_minutes                                          as candidate_reg_to_triage_p90_minutes,
    rt.reg_to_triage_p95_minutes                                          as candidate_reg_to_triage_p95_minutes,

    -- Candidate KPI: Doctor Assessment → X-Ray transition duration
    -- Label: "Assessment-to-X-Ray Transition Duration"
    ax.assessment_to_xray_count                                           as candidate_assessment_to_xray_count,
    ax.assessment_to_xray_avg_minutes                                     as candidate_assessment_to_xray_avg_minutes,
    ax.assessment_to_xray_median_minutes                                  as candidate_assessment_to_xray_median_minutes,
    ax.assessment_to_xray_p90_minutes                                     as candidate_assessment_to_xray_p90_minutes,
    ax.assessment_to_xray_p95_minutes                                     as candidate_assessment_to_xray_p95_minutes,

    -- Candidate KPI: Arrival → Exam Started (NOT present in current dataset)
    -- Returns NULL — included for forward compatibility when richer data is added.
    -- Label: "Arrival-to-Exam Transition Duration" (NOT "Waiting Time" —
    -- business definition not yet confirmed).
    ae.arrival_to_exam_count                                              as candidate_arrival_to_exam_count,
    ae.arrival_to_exam_avg_minutes                                        as candidate_arrival_to_exam_avg_minutes,
    ae.arrival_to_exam_median_minutes                                     as candidate_arrival_to_exam_median_minutes,
    ae.arrival_to_exam_p90_minutes                                        as candidate_arrival_to_exam_p90_minutes,
    ae.arrival_to_exam_p95_minutes                                        as candidate_arrival_to_exam_p95_minutes,

    -- Note explaining absent transition
    'Transition Arrival → Exam Started does not exist in current dataset. '
    || 'Columns preserved for future data integration.'                    as arrival_to_exam_data_note,

    -- Reconciliation metrics
    r.ordered_event_count,
    r.fact_case_count,
    r.ordered_event_case_count,
    r.transition_record_count,
    r.non_final_event_count,

    -- Reconciliation status flags
    case
        when r.fact_case_count = r.ordered_event_case_count
        then 'PASS — Case counts reconcile'
        else 'FAIL — Case count mismatch: fact=' || r.fact_case_count
             || ' vs ordered_events=' || r.ordered_event_case_count
    end                                                                    as reconciliation_case_counts,

    case
        when r.transition_record_count = r.non_final_event_count
        then 'PASS — Transition count matches non-final events'
        else 'FAIL — Transition/event mismatch: transitions=' || r.transition_record_count
             || ' vs non_final_events=' || r.non_final_event_count
    end                                                                    as reconciliation_transitions,

    {{ dbt.current_timestamp() }}                                                                  as snapshot_generated_at

from kpi_snapshot k
cross join event_kpis e
cross join path_kpis p
cross join registration_to_triage_kpi rt
cross join assessment_to_xray_kpi ax
cross join arrival_to_exam_kpi ae
cross join reconciliation r
