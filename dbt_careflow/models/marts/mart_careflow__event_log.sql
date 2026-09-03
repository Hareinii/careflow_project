/*
=============================================================================
MODEL: mart_careflow__event_log
PROJECT: CareFlow Data Analyst Portfolio Project — Day 9
=============================================================================

PURPOSE
-------
Provides the final, clean, process-mining-ready Event Log.
This exposes the mandatory concepts:
- Case_ID: The process instance (patient journey).
- Activity_Name: What happened (standardized).
- Timestamp: When it happened.

GRAIN
-----
One row = one event.

BUSINESS LOGIC
--------------
Sourced directly from the intermediate ordered events model, this table 
strips away complex analytical artifacts (like lag/lead) to present a 
clean, flat log suitable for ingestion into tools like Celonis, Signavio,
or PowerBI process mining visuals.
=============================================================================
*/

with ordered_events as (
    select * from {{ ref('int_careflow__ordered_events') }}
)

select
    -- Core Process Mining Requirements
    case_id,
    activity_name,
    event_timestamp as timestamp,
    
    -- Necessary Operational Context
    event_id,
    event_sequence,
    department,
    doctor_id
from ordered_events
order by case_id, event_sequence
