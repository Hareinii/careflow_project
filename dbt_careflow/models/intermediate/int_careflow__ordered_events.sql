with events_with_sequence as (

    select
        *,
        row_number() over (partition by case_id order by event_timestamp asc, event_id asc) as event_sequence,
        lag(activity_name) over (partition by case_id order by event_timestamp asc, event_id asc) as previous_activity,
        lead(activity_name) over (partition by case_id order by event_timestamp asc, event_id asc) as next_activity,
        lag(event_timestamp) over (partition by case_id order by event_timestamp asc, event_id asc) as previous_event_timestamp,
        lead(event_timestamp) over (partition by case_id order by event_timestamp asc, event_id asc) as next_event_timestamp,
        first_value(event_timestamp) over (partition by case_id order by event_timestamp asc, event_id asc rows between unbounded preceding and unbounded following) as first_event_timestamp,
        last_value(event_timestamp) over (partition by case_id order by event_timestamp asc, event_id asc rows between unbounded preceding and unbounded following) as last_event_timestamp
    from {{ ref('stg_careflow__events') }}

),

events_with_transitions as (

    select
        *,
        case
            when previous_event_timestamp is null then true
            else false
        end as is_first_event,
        case
            when next_event_timestamp is null then true
            else false
        end as is_last_event,
        cast((epoch(event_timestamp) - epoch(previous_event_timestamp)) / 60 as integer) as transition_duration_minutes
    from events_with_sequence

)

select
    event_id,
    case_id,
    activity_name,
    event_timestamp,
    event_sequence,
    previous_activity,
    next_activity,
    previous_event_timestamp,
    next_event_timestamp,
    is_first_event,
    is_last_event,
    transition_duration_minutes,
    first_event_timestamp,
    last_event_timestamp,
    department,
    doctor_id,
    priority,
    journey_type,
    source_row,
    source_system
from events_with_transitions
order by case_id, event_sequence
