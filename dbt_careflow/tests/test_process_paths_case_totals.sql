-- Test to ensure all cases in process paths sum to total cases
-- Returns a row if the path totals do not match the distinct case count (test fails if any rows returned)
with path_totals as (
    select sum(case_count) as path_case_total
    from {{ ref('mart_careflow__process_paths') }}
),
case_totals as (
    select count(distinct case_id) as total_cases
    from {{ ref('fct_careflow__cases') }}
)
select
    total_cases,
    path_case_total
from path_totals
cross join case_totals
where path_case_total != total_cases
