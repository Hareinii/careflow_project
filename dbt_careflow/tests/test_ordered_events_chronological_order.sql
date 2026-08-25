-- Test to ensure chronological ordering within each case.
-- Event timestamps should not decrease as event_sequence increases.
-- This returns any event where the previous event's timestamp is strictly greater than the current event's timestamp.

with ordered_events as (
    select * from {{ ref('int_careflow__ordered_events') }}
)

select
    case_id,
    event_sequence,
    activity_name,
    event_timestamp,
    previous_activity,
    previous_event_timestamp
from ordered_events
where previous_event_timestamp is not null
  and previous_event_timestamp > event_timestamp
