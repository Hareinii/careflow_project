with ordered_events as (

    select * from {{ ref('int_careflow__ordered_events') }}

),

case_base as (

    select
        case_id,
        max(department) as department,
        max(doctor_id) as doctor_id,
        max(priority) as priority,
        max(journey_type) as journey_type,
        min(event_timestamp) as first_event_timestamp,
        max(event_timestamp) as last_event_timestamp,
        count(*) as event_count,
        count(distinct activity_name) as unique_activity_count,
        cast((epoch(max(event_timestamp)) - epoch(min(event_timestamp))) / 60 as integer) as cycle_time_minutes
    from ordered_events
    group by case_id

),

first_activity_cte as (

    select
        case_id,
        activity_name as first_activity
    from ordered_events
    where event_sequence = 1

),

last_activity_cte as (

    select
        case_id,
        activity_name as last_activity
    from ordered_events
    where is_last_event = true

),

process_path_cte as (

    select
        case_id,
        string_agg(activity_name, ' → ' order by event_sequence) as process_path
    from ordered_events
    group by case_id

)

select
    cb.case_id,
    cb.department,
    cb.doctor_id,
    cb.priority,
    cb.journey_type,
    cb.first_event_timestamp,
    cb.last_event_timestamp,
    fa.first_activity,
    la.last_activity,
    cb.event_count,
    cb.unique_activity_count,
    cb.cycle_time_minutes,
    pp.process_path,
    case
        when cb.unique_activity_count < cb.event_count then true
        else false
    end as has_repeated_activity,
    now() as loaded_at
from case_base cb
left join first_activity_cte fa on cb.case_id = fa.case_id
left join last_activity_cte la on cb.case_id = la.case_id
left join process_path_cte pp on cb.case_id = pp.case_id
