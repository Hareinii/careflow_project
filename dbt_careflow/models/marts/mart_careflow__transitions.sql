/*
=============================================================================
MODEL: mart_careflow__transitions
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Transition-level summary mart. One row per unique transition type observed
in the dataset. Aggregates duration statistics across all occurrences of
each transition pair.

GRAIN
-----
One row = one unique transition type (from_activity → to_activity pair).

NOTE: transition_count vs case_count
--------------------------------------
A case may traverse the same transition more than once (e.g. a patient
may be re-triaged). Therefore:

  transition_count = COUNT(*)                      — total occurrences
  case_count       = COUNT(DISTINCT case_id)       — distinct cases affected

These are DIFFERENT metrics and must not be confused.
transition_count >= case_count always.

PERCENTILE METHOD
-----------------
DuckDB supports exact percentile computation via:
  PERCENTILE_CONT(fraction) WITHIN GROUP (ORDER BY column)

This provides EXACT percentiles (not approximate). The documentation
explicitly labels them as exact.

DURATION STATISTICS
-------------------
All statistics exclude null durations from the aggregation (SQL standard:
aggregate functions ignore nulls).

Negative durations ARE included in statistics — they are data-quality
signals that must be visible, not hidden.

=============================================================================
*/

with transitions as (

    select * from {{ ref('int_careflow__transition_metrics') }}

),

transition_summary as (

    select
        transition_name,

        -- Volume metrics
        count(*)                        as transition_count,
        count(distinct case_id)         as case_count,

        -- Null and negative duration counts for data quality visibility
        sum(case when is_null_duration     = true then 1 else 0 end) as null_duration_count,
        sum(case when is_negative_duration = true then 1 else 0 end) as negative_duration_count,

        -- Central tendency
        round(avg(transition_duration_minutes), 2)              as avg_duration_minutes,

        -- Exact percentiles using DuckDB PERCENTILE_CONT
        -- These are EXACT percentiles computed over the full distribution.
        percentile_cont(0.50) within group (order by transition_duration_minutes)
                                                                as median_duration_minutes,
        percentile_cont(0.75) within group (order by transition_duration_minutes)
                                                                as p75_duration_minutes,
        percentile_cont(0.90) within group (order by transition_duration_minutes)
                                                                as p90_duration_minutes,
        percentile_cont(0.95) within group (order by transition_duration_minutes)
                                                                as p95_duration_minutes,

        -- Range
        min(transition_duration_minutes)                        as min_duration_minutes,
        max(transition_duration_minutes)                        as max_duration_minutes,

        -- Spread / variability
        round(stddev(transition_duration_minutes), 2)           as stddev_duration_minutes

    from transitions
    group by transition_name

),

/*
  Add share of total transition time.
  Calculated as:
    sum of all individual transition durations for this transition type
    / sum of all individual transition durations across all transitions
  
  This uses transition OCCURRENCES (all rows), not distinct cases.
  This gives the operational view: where is the total process time consumed?
*/
transition_summary_with_share as (

    select
        ts.*,

        -- Sum of all durations for this transition
        round(
            sum(t.transition_duration_minutes)
                filter (where t.transition_name = ts.transition_name)
        , 2) as total_duration_sum,

        -- Total duration across all transitions
        round(
            sum(t.transition_duration_minutes)
        , 2) as grand_total_duration,

        -- Share of total transition time (percentage)
        round(
            100.0
            * sum(t.transition_duration_minutes)
                  filter (where t.transition_name = ts.transition_name)
            / nullif(sum(t.transition_duration_minutes), 0)
        , 2) as share_of_total_transition_time_pct

    from transition_summary ts
    -- Cross join to get global sum alongside each row
    cross join transitions t
    group by
        ts.transition_name,
        ts.transition_count,
        ts.case_count,
        ts.null_duration_count,
        ts.negative_duration_count,
        ts.avg_duration_minutes,
        ts.median_duration_minutes,
        ts.p75_duration_minutes,
        ts.p90_duration_minutes,
        ts.p95_duration_minutes,
        ts.min_duration_minutes,
        ts.max_duration_minutes,
        ts.stddev_duration_minutes

)

select
    transition_name,
    transition_count,
    case_count,
    null_duration_count,
    negative_duration_count,
    avg_duration_minutes,
    median_duration_minutes,
    p75_duration_minutes,
    p90_duration_minutes,
    p95_duration_minutes,
    min_duration_minutes,
    max_duration_minutes,
    stddev_duration_minutes,
    total_duration_sum,
    grand_total_duration,
    share_of_total_transition_time_pct
from transition_summary_with_share
order by avg_duration_minutes desc
