/*
=============================================================================
MODEL: int_careflow__transition_metrics
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Produces one row per event-to-next-event transition per case.

The final event of each case is EXCLUDED because it has no next event
and therefore no forward-facing transition to measure. The final event
is preserved in int_careflow__ordered_events for completeness.

GRAIN
-----
One row = one transition (from_activity → to_activity) for one case.

SOURCE COLUMN MAPPING
---------------------
  activity_name             → from_activity
  next_activity             → to_activity
  event_timestamp           → from_timestamp
  next_event_timestamp      → to_timestamp
  duration_to_next_minutes  → transition_duration_minutes
  (computed below as forward-facing duration)

IMPORTANT — METRIC SEMANTICS
-----------------------------
`transition_duration_minutes` is the elapsed time between two recorded
events. It does NOT automatically imply "waiting time". The business
meaning of each transition must be established separately. For example:

  Registration → Triage        : operational processing gap
  X-Ray → Doctor Review        : diagnostic turnaround + review gap

No transition is labelled "waiting time" in this model.

TRANSITION IDENTIFIER
---------------------
`transition_name` is generated dynamically as:
  from_activity || ' → ' || to_activity

This avoids hard-coding activity names.

TRANSITION VALIDATION FLAGS
----------------------------
Two quality flags are added:
  - is_null_duration    : TRUE if transition_duration_minutes IS NULL
  - is_negative_duration: TRUE if transition_duration_minutes < 0

Negative durations are NOT deleted. They are flagged for investigation.
Possible causes include:
  - Timestamp data entry errors
  - Duplicated timestamps with conflicting ordering
  - Source-system clock drift
  - Event ordering anomalies

=============================================================================
*/

with ordered_events as (

    select * from {{ ref('int_careflow__ordered_events') }}

),

/*
  Include only non-final events.
  Final events have no next_activity and no next_event_timestamp,
  so they do not form a valid forward-facing transition.
  They are retained in the source model for case-level analysis.
*/
transitions_raw as (

    select
        event_id,
        case_id,
        event_sequence,

        -- Transition endpoints (dynamically computed — no hard-coded names)
        activity_name                                    as from_activity,
        next_activity                                    as to_activity,

        -- Transition timestamps
        event_timestamp                                  as from_timestamp,
        next_event_timestamp                             as to_timestamp,

        -- Forward-facing transition duration in minutes
        -- Computed as: (next_event_timestamp - event_timestamp) in minutes
        -- This is distinct from transition_duration_minutes in the source,
        -- which is the BACKWARD-facing duration (from previous event).
        {{ dbt.datediff("event_timestamp", "next_event_timestamp", "minute") }} as transition_duration_minutes,

        -- Dimensional attributes for segmentation
        department,
        doctor_id,
        priority,
        journey_type

    from ordered_events
    where is_last_event = false  -- Exclude final events; they have no next event

),

transitions_with_labels as (

    select
        *,

        -- Dynamic transition label — no activity names hard-coded
        from_activity || ' → ' || to_activity            as transition_name,

        -- Data quality flags
        case
            when transition_duration_minutes is null then true
            else false
        end                                              as is_null_duration,

        case
            when transition_duration_minutes < 0 then true
            else false
        end                                              as is_negative_duration

    from transitions_raw

)

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
    is_null_duration,
    is_negative_duration,
    department,
    doctor_id,
    priority,
    journey_type
from transitions_with_labels
order by case_id, event_sequence
