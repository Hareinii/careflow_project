with cases as (

    select * from {{ ref('fct_careflow__cases') }}

),

path_aggregation as (

    select
        process_path,
        count(distinct case_id) as case_count,
        count(distinct case_id) / sum(count(distinct case_id)) over () * 100 as percentage_of_cases,
        avg(cycle_time_minutes) as avg_cycle_time_minutes,
        min(cycle_time_minutes) as min_cycle_time_minutes,
        max(cycle_time_minutes) as max_cycle_time_minutes,
        count(distinct case_id) filter (where has_repeated_activity = true) as cases_with_repeated_activity,
        count(distinct department) as departments_in_path,
        count(distinct doctor_id) as providers_in_path,
        count(distinct priority) as priority_levels_in_path,
        now() as loaded_at
    from cases
    group by process_path

)

select
    *
from path_aggregation
order by case_count desc
