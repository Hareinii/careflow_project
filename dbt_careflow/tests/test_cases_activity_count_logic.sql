-- Test to ensure unique_activity_count never exceeds event_count
select
    case_id,
    event_count,
    unique_activity_count
from {{ ref('fct_careflow__cases') }}
where unique_activity_count > event_count
