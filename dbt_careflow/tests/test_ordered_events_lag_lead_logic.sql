-- Test to ensure LAG/LEAD logic is correct
-- Returns rows if:
-- 1. First event has a previous_activity
-- 2. Last event has a next_activity
-- 3. Middle event is unexpectedly missing previous_activity

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
    b.is_first_event,
    b.is_last_event,
    b.activity_name,
    b.previous_activity,
    b.next_activity
from base b
join case_event_counts c on b.case_id = c.case_id
where 
    -- Rule 1: First event shouldn't have a previous
    (b.is_first_event = true and b.previous_activity is not null)
    or
    -- Rule 2: Last event shouldn't have a next
    (b.is_last_event = true and b.next_activity is not null)
    or
    -- Rule 3: Middle event must have a previous
    (b.event_sequence > 1 and b.previous_activity is null and c.total_events > 1)
