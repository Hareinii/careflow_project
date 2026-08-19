/*
=============================================================================
TEST: test_transition_metrics_negative_duration_audit
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Audit test that reports all transition records where transition_duration_minutes < 0.
Per Day 4 specification, negative durations must NOT be silently removed.
This test surfaces them for investigation.

EXPECTED BEHAVIOR
-----------------
This test is designed as a WARNING, not a hard failure.
If any negative durations exist, the test returns rows (will show as warning/fail).
Each row contains context to investigate the source of the anomaly.

INVESTIGATION GUIDANCE
----------------------
Negative durations may be caused by:
  1. Timestamp data entry errors in the source system
  2. Duplicated events with conflicting timestamps surviving deduplication
  3. Source-system clock drift between recording systems
  4. Events recorded out of chronological order

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
    doctor_id,
    priority,
    journey_type
from {{ ref('int_careflow__transition_metrics') }}
where transition_duration_minutes < 0
