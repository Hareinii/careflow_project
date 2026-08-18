-- Calculates the average time spent transitioning between every pair of
-- consecutive activities (e.g. Triage -> X-Ray). This is the core
-- bottleneck metric that feeds the process flowchart dashboard, and is
-- what would surface the Triage rebounce loop as a major time sink.

with events as (

    select * from {{ ref('stg_ehr_event_log') }}

),

with_next_event as (

    select
        case_id,
        activity_name as from_activity,
        event_timestamp as from_timestamp,
        lead(activity_name) over (
            partition by case_id order by event_sequence
        ) as to_activity,
        lead(event_timestamp) over (
            partition by case_id order by event_sequence
        ) as to_timestamp

    from events

),

transitions as (

    select
        from_activity,
        to_activity,
        timestamp_diff(to_timestamp, from_timestamp, minute) as transition_minutes

    from with_next_event
    where to_activity is not null

)

select
    from_activity,
    to_activity,
    count(*) as transition_count,
    round(avg(transition_minutes), 1) as avg_transition_minutes,
    round(min(transition_minutes), 1) as min_transition_minutes,
    round(max(transition_minutes), 1) as max_transition_minutes

from transitions
group by from_activity, to_activity
order by transition_count desc
