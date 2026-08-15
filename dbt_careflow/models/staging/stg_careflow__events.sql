with source_data as (

    select *
    from {{ source('careflow_raw', 'event_log') }}

),

deduplicated as (

    select
        cast(event_id as string) as event_id,
        cast(case_id as string) as case_id,
        trim(cast(activity_name as string)) as activity_name,
        cast(timestamp as timestamp) as event_timestamp,
        trim(cast(department as string)) as department,
        trim(cast(doctor_id as string)) as doctor_id,
        trim(cast(priority as string)) as priority,
        trim(cast(journey_type as string)) as journey_type,
        cast(source_row as int64) as source_row,
        trim(cast(source_system as string)) as source_system,
        row_number() over (partition by event_id order by source_row) as event_id_row_num
    from source_data

),

final as (

    select
        event_id,
        case_id,
        activity_name,
        event_timestamp,
        department,
        doctor_id,
        priority,
        journey_type,
        source_row,
        source_system
    from deduplicated
    where event_id_row_num = 1

)

select *
from final

