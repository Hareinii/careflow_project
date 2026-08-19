-- Test to ensure has_repeated_activity flag is correct (true only when unique_activity_count < event_count)
select
    case_id,
    event_count,
    unique_activity_count,
    has_repeated_activity
from {{ ref('fct_careflow__cases') }}
where (has_repeated_activity = true and unique_activity_count >= event_count)
    or (has_repeated_activity = false and unique_activity_count < event_count)
