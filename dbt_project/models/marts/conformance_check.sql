-- Flags whether each patient's actual journey matches the hospital's
-- "ideal" mandated path (Registration -> Triage -> X-Ray -> Doctor ->
-- Discharge), or deviated from it (e.g. the Triage rebounce loop).
-- This feeds the dashboard's drill-down conformance-checking view.

with events as (

    select * from {{ ref('stg_ehr_event_log') }}

),

case_paths as (

    select
        case_id,
        string_agg(activity_name, ' -> ' order by event_sequence) as actual_path,
        count(*) as num_events

    from events
    group by case_id

),

flagged as (

    select
        case_id,
        actual_path,
        num_events,
        case
            when actual_path like '%Rebounce%' then false
            else true
        end as is_conformant,
        case
            when actual_path like '%Rebounce%' then 'Triage rebounce - missing paperwork'
            else null
        end as deviation_reason

    from case_paths

)

select * from flagged
