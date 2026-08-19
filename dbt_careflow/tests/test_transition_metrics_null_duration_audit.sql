/*
=============================================================================
TEST: test_transition_metrics_null_duration_audit
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Audit test that reports all transition records where transition_duration_minutes IS NULL.
After excluding final events, null durations should not occur in a healthy dataset.
Any nulls indicate a data quality issue requiring investigation.

=============================================================================
*/

select
    event_id,
    case_id,
    event_sequence,
    transition_name,
    from_activity,
    to_activity,
    from_timestamp,
    to_timestamp,
    transition_duration_minutes,
    department,
    doctor_id
from {{ ref('int_careflow__transition_metrics') }}
where transition_duration_minutes is null
