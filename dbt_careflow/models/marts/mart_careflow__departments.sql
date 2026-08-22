/*
=============================================================================
MODEL: mart_careflow__departments
PROJECT: CareFlow Data Analyst Portfolio Project — Day 5
=============================================================================

PURPOSE
-------
Department-level analytical KPI mart. Provides a reusable summary of
process metrics grouped by department, supporting Day 5+ operational analysis
and eventual dashboard segmentation.

GRAIN
-----
One row = one department.

SOURCES
-------
  int_careflow__ordered_events   — event-level metrics and case membership
  int_careflow__transition_metrics — transition durations by department
  fct_careflow__cases             — case-level cycle time and repeat-activity flags

METRIC DEFINITIONS
------------------

  case_count
    COUNT(DISTINCT case_id) from ordered_events for this department.
    A case may span multiple departments (e.g. Emergency + Radiology).
    A case is counted in every department where it has at least one event.
    This differs from a department "owning" a case exclusively.

  event_count
    COUNT(*) of events from ordered_events where department = this department.

  avg_events_per_case
    event_count / case_count.
    Represents the average number of events a case generates IN this department.
    NOT the total events per case across all departments.

  avg_cycle_time_minutes / median_cycle_time_minutes / p90 / p95
    Computed from fct_careflow__cases for cases that have at least one event
    in this department. Cycle time is the FULL case duration (first to last event
    across all departments). It is NOT the time spent within this department.
    This distinction is documented and must be preserved in any downstream analysis.

  repeat_activity_case_count / repeat_activity_case_percentage
    Cases with has_repeated_activity = true that also have events in this department.
    Note: the repeat activity may or may not have occurred within this department.

  unique_doctors
    COUNT(DISTINCT doctor_id) from ordered_events for this department.

  unique_process_paths
    COUNT(DISTINCT process_path) from fct_careflow__cases for cases
    that have events in this department.

  transition_count
    COUNT(*) from int_careflow__transition_metrics where the from_activity
    belongs to this department. Transitions are attributed to the department
    of the FROM event.

  avg_transition_duration_minutes / median_transition_duration_minutes / p90
    Average, median, and P90 of transition_duration_minutes for transitions
    originating in this department. Includes all transition types.

IMPORTANT ANALYTICAL CAVEAT
-----------------------------
Department comparison by cycle time is potentially misleading.
Differences may reflect:
  - Case complexity (not department performance)
  - Process design (e.g. Radiology handles only X-Ray steps)
  - Case mix (all cases pass through both departments in this dataset)
Do NOT rank departments as "better" or "worse" without controlling for these.

=============================================================================
*/

with ordered_events as (

    select * from {{ ref('int_careflow__ordered_events') }}

),

cases as (

    select * from {{ ref('fct_careflow__cases') }}

),

transition_metrics as (

    select * from {{ ref('int_careflow__transition_metrics') }}

),

-- -------------------------------------------------------
-- Event-level aggregation by department
-- -------------------------------------------------------
dept_events as (

    select
        department,
        count(distinct case_id)         as case_count,
        count(*)                        as event_count,
        count(distinct doctor_id)       as unique_doctors
    from ordered_events
    group by department

),

-- -------------------------------------------------------
-- Case-level metrics: join cases that have events in dept
-- -------------------------------------------------------
dept_cases as (

    select distinct
        oe.department,
        oe.case_id
    from ordered_events oe

),

dept_case_metrics as (

    select
        dc.department,
        round(avg(c.cycle_time_minutes), 2)                                      as avg_cycle_time_minutes,
        percentile_cont(0.50) within group (order by c.cycle_time_minutes)        as median_cycle_time_minutes,
        percentile_cont(0.90) within group (order by c.cycle_time_minutes)        as p90_cycle_time_minutes,
        percentile_cont(0.95) within group (order by c.cycle_time_minutes)        as p95_cycle_time_minutes,
        count(c.case_id) filter (where c.has_repeated_activity = true)            as repeat_activity_case_count,
        round(
            100.0
            * count(c.case_id) filter (where c.has_repeated_activity = true)
            / nullif(count(c.case_id), 0)
        , 2)                                                                       as repeat_activity_case_percentage,
        count(distinct c.process_path)                                             as unique_process_paths
    from dept_cases dc
    join cases c on dc.case_id = c.case_id
    group by dc.department

),

-- -------------------------------------------------------
-- Transition metrics by department (from_activity department)
-- -------------------------------------------------------
dept_transitions as (

    select
        department,
        count(*)                                                                   as transition_count,
        round(avg(transition_duration_minutes), 2)                                 as avg_transition_duration_minutes,
        percentile_cont(0.50) within group (order by transition_duration_minutes)  as median_transition_duration_minutes,
        percentile_cont(0.90) within group (order by transition_duration_minutes)  as p90_transition_duration_minutes
    from transition_metrics
    group by department

)

select
    de.department,

    -- Volume
    de.case_count,
    de.event_count,
    round(cast(de.event_count as float) / nullif(de.case_count, 0), 2) as avg_events_per_case,
    de.unique_doctors,

    -- Cycle time (full case duration for cases touching this department)
    dcm.avg_cycle_time_minutes,
    dcm.median_cycle_time_minutes,
    dcm.p90_cycle_time_minutes,
    dcm.p95_cycle_time_minutes,

    -- Repeat activity
    dcm.repeat_activity_case_count,
    dcm.repeat_activity_case_percentage,

    -- Process diversity
    dcm.unique_process_paths,

    -- Transitions originating from this department
    coalesce(dt.transition_count, 0)                    as transition_count,
    dt.avg_transition_duration_minutes,
    dt.median_transition_duration_minutes,
    dt.p90_transition_duration_minutes

from dept_events de
left join dept_case_metrics dcm on de.department = dcm.department
left join dept_transitions dt   on de.department = dt.department

order by de.case_count desc, de.event_count desc
