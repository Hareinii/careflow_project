-- Test to ensure LAG/LEAD logic is correct (previous/next activities should not be null for middle events)
-- Returns rows where a non-first event is unexpectedly missing previous_activity,
-- for cases that have more than one event (i.e., a middle event has null previous_activity).
with base as (
    select * from {{ ref('int_careflow__ordered_events') }}
),
case_event_counts as (
    select case_id, count(*) as total_events
    from base
    group by case_id
)
select
    b.case_id,
    b.event_sequence,
    b.activity_name,
    b.previous_activity,
    b.next_activity
from base b
join case_event_counts c on b.case_id = c.case_id
where b.event_sequence > 1
    and b.previous_activity is null
    and c.total_events > 1
