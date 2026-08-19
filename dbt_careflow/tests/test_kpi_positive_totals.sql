/*
=============================================================================
TEST: test_kpi_positive_totals
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Validates that the KPI mart contains meaningful non-zero values.
The KPI snapshot must show at least one case, at least one event,
and non-negative cycle time metrics.

Returns rows (test fails) if any of these conditions are violated.
=============================================================================
*/

select
    total_cases,
    total_events,
    average_cycle_time_minutes,
    median_cycle_time_minutes,
    'KPI validation failed: one or more core KPIs are invalid' as failure_reason
from {{ ref('mart_careflow__kpis') }}
where
    total_cases <= 0
    or total_events <= 0
    or average_cycle_time_minutes < 0
    or median_cycle_time_minutes < 0
