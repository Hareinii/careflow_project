/*
=============================================================================
TEST: test_bottlenecks_transition_names_not_null
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Validates that mart_careflow__bottlenecks has no null transition names,
no null transition counts, and no null case counts.

Returns rows (test fails) if any violations exist.
=============================================================================
*/

select
    transition_name,
    transition_count,
    case_count,
    'Bottleneck validation failed: required field is null or zero' as failure_reason
from {{ ref('mart_careflow__bottlenecks') }}
where
    transition_name is null
    or transition_count is null
    or case_count is null
    or transition_count <= 0
    or case_count <= 0
