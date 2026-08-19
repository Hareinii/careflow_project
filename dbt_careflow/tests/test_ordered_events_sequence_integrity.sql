-- Test to ensure event sequence is correct within each case
select
    case_id,
    count(*) as event_count,
    count(distinct event_sequence) as distinct_sequences,
    max(event_sequence) as max_sequence
from {{ ref('int_careflow__ordered_events') }}
group by case_id
having count(*) != count(distinct event_sequence)
    or max(event_sequence) != count(*)
