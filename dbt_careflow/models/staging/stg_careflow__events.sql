with source_events as (

    select *
    from {{ source('careflow_raw', 'event_log') }}

)

select *
from source_events
