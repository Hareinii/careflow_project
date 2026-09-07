/*
=============================================================================
MODEL: mart_careflow__case_segments
PROJECT: CareFlow Data Analyst Portfolio Project — Day 6
=============================================================================

PURPOSE
-------
Provides a single, flattened, case-level analytical layer designed for
operational segmentation in BI dashboards. Adds cycle-time percentiles
and long-duration outlier flags to the base case fact table.

GRAIN
-----
One row = one case.

WHY THIS MODEL EXISTS
---------------------
While fct_careflow__cases provides the foundational metrics, dashboard 
tools often struggle to compute dynamic percentiles across the entire
dataset when users apply filters. Pre-computing cycle_time_percentile 
and an explicit is_long_duration_case flag allows simple, performant
dashboard segmentation (e.g., "Compare Long-tail cases to Normal cases").

BUSINESS LOGIC
--------------
* cycle_time_percentile: Rank of the case's cycle time relative to the 
  overall distribution (0.0 to 1.0).
* is_long_duration_case: Flagged TRUE if the case's cycle time is at or 
  above the 95th percentile (P95) threshold of the overall dataset.
=============================================================================
*/

with cases as (

    select * from {{ ref('fct_careflow__cases') }}

),

-- Calculate the overall P95 threshold
thresholds as (

    select 
        {{ exact_percentile(0.95, 'cycle_time_minutes') }} as p95_threshold
    from cases

),

case_segments as (

    select
        c.case_id,
        c.department,
        c.priority,
        c.journey_type,
        c.process_path,
        c.cycle_time_minutes,
        c.event_count,
        c.has_repeated_activity,
        
        -- Compute percentile rank (0 to 1) for this case's cycle time
        round(
            percent_rank() over (order by c.cycle_time_minutes asc)
        , 3) as cycle_time_percentile_rank,
        
        -- Flag long-duration cases (>= overall P95)
        case 
            when c.cycle_time_minutes >= t.p95_threshold then true
            else false
        end as is_long_duration_case

    from cases c
    cross join thresholds t

)

select * from case_segments
