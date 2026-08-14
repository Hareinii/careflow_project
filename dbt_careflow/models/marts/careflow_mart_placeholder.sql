with staging_events as (

    select *
    from {{ ref('stg_careflow__events') }}

)

select *
from staging_events
