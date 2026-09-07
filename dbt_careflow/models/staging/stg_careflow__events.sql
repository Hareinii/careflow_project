/*
=============================================================================
MODEL: stg_careflow__events
PROJECT: CareFlow Data Analyst Portfolio Project
=============================================================================

PURPOSE
-------
Cleans and deduplicates the raw EHR event log.

DEDUPLICATION — TWO STAGES
---------------------------
Stage 1 (event_id dedup):
  Removes rows where the identical event_id appears more than once.
  Retains one row per event_id. Handles genuine ETL re-load duplicates.

Stage 2 (business-key dedup):
  Removes records that share the same (case_id, activity_name, event_timestamp)
  but carry different event_id values.

  Investigation result (Day 5):
    EVT019 and EVT019_DUP are identical across all meaningful fields:
      case_id, activity_name, event_timestamp, department, doctor_id, source_system
    Only the event_id differs (EVT019_DUP has a _DUP suffix).
    Classification: A — Exact Technical Duplicate.

  Rule: retain the record with the lexicographically lowest event_id.
  This is deterministic and reproducible.
  EVT019 is retained; EVT019_DUP is excluded.

RAW DATA INTEGRITY
------------------
The raw source (raw_ehr_events seed) is never modified.
All deduplication is performed in this staging transformation.
Lineage is preserved via the source_row and source_system columns.

PRIORITY / JOURNEY TYPE
------------------------
These fields are NOT present in the raw source CSV.
They are assigned default values here as placeholder dimensions.
Both are confirmed staging fabrications (Day 5 provenance assessment).
They must NOT be used as confirmed operational KPIs until real values
are provided by the source system.

=============================================================================
*/

with source_data as (

    select *
    from {{ source('careflow', 'raw_ehr_events') }}

),

/*
  Stage 1: Deduplicate on event_id.
  Handles re-load duplicates where the same event_id appears more than once.
  Retains first occurrence.
*/
dedup_event_id as (

    select
        cast(event_id as string)            as event_id,
        cast(case_id as string)             as case_id,
        trim(cast(activity_name as string)) as activity_name,
        cast(timestamp as timestamp)        as event_timestamp,
        trim(cast(department as string))    as department,
        trim(cast(doctor_id as string))     as doctor_id,

        -- Placeholder dimensions — NOT from source CSV.
        -- Provenance: staging fabrication. Do not use as confirmed KPIs.
        'High'                              as priority,
        'Normal'                            as journey_type,

        row_number() over (
            partition by event_id
            order by event_id
        )                                   as source_row,

        trim(cast(source_system as string)) as source_system,

        row_number() over (
            partition by event_id
            order by event_id
        )                                   as event_id_row_num

    from source_data

),

stage1 as (

    select * from dedup_event_id
    where event_id_row_num = 1

),

/*
  Stage 2: Deduplicate on business key (case_id, activity_name, event_timestamp).
  Removes records that are identical in all meaningful fields but differ only
  in event_id (e.g. EVT019 vs EVT019_DUP for PAT003 / Doctor Review / 16:25:00).

  Retention rule: keep the record with the lowest event_id (lexicographic ascending).
  This is deterministic, documented, and reproducible.

  EVT019 is retained. EVT019_DUP is excluded.
*/
dedup_business_key as (

    select
        *,
        row_number() over (
            partition by case_id, activity_name, event_timestamp
            order by event_id asc
        ) as business_key_row_num

    from stage1

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
    from dedup_business_key
    where business_key_row_num = 1

)

select * from final
