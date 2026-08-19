/*
=============================================================================
TEST: test_transition_metrics_reconciliation
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Reconciliation check: the number of rows in int_careflow__transition_metrics
must equal the number of non-final events in int_careflow__ordered_events.

LOGIC
-----
Every non-final event has a next event, so it forms exactly one transition.
Final events have no next event and are excluded from the transition model.
Therefore: COUNT(transitions) == COUNT(non-final events).

If this test returns any rows, the reconciliation has failed.
=============================================================================
*/

with transition_count as (
    select count(*) as n_transitions
    from {{ ref('int_careflow__transition_metrics') }}
),

non_final_event_count as (
    select count(*) as n_non_final
    from {{ ref('int_careflow__ordered_events') }}
    where is_last_event = false
)

select
    t.n_transitions,
    e.n_non_final,
    'RECONCILIATION FAIL: transition count does not match non-final event count' as failure_reason
from transition_count t
cross join non_final_event_count e
where t.n_transitions <> e.n_non_final
