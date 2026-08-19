/*
=============================================================================
TEST: test_transitions_transition_count_gte_case_count
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Validates the fundamental relationship: transition_count >= case_count.
A case may traverse a transition multiple times (loopbacks), so the number
of transition occurrences must be >= the number of distinct cases.

Returns rows (test fails) if any transition violates this invariant.
=============================================================================
*/

select
    transition_name,
    transition_count,
    case_count,
    'transition_count must be >= case_count' as failure_reason
from {{ ref('mart_careflow__transitions') }}
where transition_count < case_count
