-- Standardizes the messy raw EHR export into the strict "Event Log" format
-- (Case_ID, Activity_Name, Timestamp) that PM4Py's process mining
-- algorithms require: one row per event, correctly typed, sorted per case.

with source as (

    select * from {{ source('raw', 'ehr_events') }}

),

cleaned as (

    select
        case_id,
        trim(activity_name) as activity_name,
        -- Real EHR exports mix timestamp formats; PARSE_TIMESTAMP here
        -- stands in for whatever cleanup the real export needs.
        cast(event_timestamp as timestamp) as event_timestamp

    from source
    where case_id is not null
      and activity_name is not null
      and event_timestamp is not null

),

deduped as (

    -- Guard against duplicate EHR system writes for the same event
    select distinct * from cleaned

)

select
    case_id,
    activity_name,
    event_timestamp,
    row_number() over (
        partition by case_id order by event_timestamp
    ) as event_sequence

from deduped
