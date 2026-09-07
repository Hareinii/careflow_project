/*
=============================================================================
MODEL: mart_careflow__conformance
PROJECT: CareFlow Clinical Pathway Process Mining — Day 16-17 Conformance
=============================================================================

PURPOSE
-------
Evaluates patient journey conformance by comparing each actual patient pathway
against the project-defined standard reference pathway:
  Registration → Triage → Doctor Assessment → X-Ray → Doctor Review → Discharge

DISCLAIMER & CLINICAL CONFORMANCE CONTEXT
----------------------------------------
This reference pathway is derived from the project-documented baseline linear 
pathway observed in the EHR extract (Day 6 Standard Path). It serves as an 
analytical process-mining reference model for conformance auditing.
It is NOT an official clinical guideline or medical standard of care.

CONFORMANCE AUDIT CHECKS
------------------------
1. is_path_compliant: TRUE if actual process path matches ideal path exactly.
2. missing_activities: Identifies any of the 6 mandatory baseline activities missing.
3. unexpected_activities: Identifies activities outside the reference set.
4. has_ordering_violation: Detects out-of-sequence events (e.g. review before triage).
5. has_repeated_activity: Identifies loopbacks or duplicate consultations.
6. conformance_status: Categorizes journey as 'Compliant' or 'Non-Compliant'.
7. deviation_reason: Human-readable diagnostic explaining why deviation occurred.

GRAIN
-----
One row per case (case_id).
=============================================================================
*/

with cases as (

    select * from {{ ref('fct_careflow__cases') }}

),

ordered_events as (

    select * from {{ ref('int_careflow__ordered_events') }}

),

reference_journey as (

    select
        'Registration → Triage → Doctor Assessment → X-Ray → Doctor Review → Discharge' as ideal_process_path,
        6 as ideal_event_count

),

case_activity_audit as (

    select
        case_id,
        countif(activity_name = 'Registration')      as count_registration,
        countif(activity_name = 'Triage')            as count_triage,
        countif(activity_name = 'Doctor Assessment') as count_doctor_assessment,
        countif(activity_name = 'X-Ray')             as count_xray,
        countif(activity_name = 'Doctor Review')     as count_doctor_review,
        countif(activity_name = 'Discharge')         as count_discharge,
        countif(activity_name not in (
            'Registration', 'Triage', 'Doctor Assessment', 'X-Ray', 'Doctor Review', 'Discharge'
        ))                                           as count_unexpected
    from ordered_events
    group by case_id

),

first_occurrences as (

    select
        case_id,
        min(case when activity_name = 'Registration' then event_sequence end)      as seq_reg,
        min(case when activity_name = 'Triage' then event_sequence end)            as seq_triage,
        min(case when activity_name = 'Doctor Assessment' then event_sequence end) as seq_doc_assess,
        min(case when activity_name = 'X-Ray' then event_sequence end)             as seq_xray,
        min(case when activity_name = 'Doctor Review' then event_sequence end)     as seq_doc_review,
        min(case when activity_name = 'Discharge' then event_sequence end)         as seq_discharge
    from ordered_events
    group by case_id

),

ordering_check as (

    select
        case_id,
        case
            when seq_reg is not null and seq_triage is not null and seq_reg > seq_triage then true
            when seq_triage is not null and seq_doc_assess is not null and seq_triage > seq_doc_assess then true
            when seq_doc_assess is not null and seq_xray is not null and seq_doc_assess > seq_xray then true
            when seq_xray is not null and seq_doc_review is not null and seq_xray > seq_doc_review then true
            when seq_doc_review is not null and seq_discharge is not null and seq_doc_review > seq_discharge then true
            else false
        end as has_ordering_violation
    from first_occurrences

),

conformance_base as (

    select
        c.case_id,
        c.department,
        c.doctor_id,
        c.priority,
        c.journey_type,
        c.process_path as actual_process_path,
        ref.ideal_process_path,
        c.event_count,
        ref.ideal_event_count,
        (c.event_count - ref.ideal_event_count) as event_count_variance,
        c.cycle_time_minutes,
        c.has_repeated_activity,
        oc.has_ordering_violation,
        case when ca.count_unexpected > 0 then true else false end as has_unexpected_activities,
        
        -- Identify missing activities
        trim(
            case when ca.count_registration = 0 then 'Registration, ' else '' end ||
            case when ca.count_triage = 0 then 'Triage, ' else '' end ||
            case when ca.count_doctor_assessment = 0 then 'Doctor Assessment, ' else '' end ||
            case when ca.count_xray = 0 then 'X-Ray, ' else '' end ||
            case when ca.count_doctor_review = 0 then 'Doctor Review, ' else '' end ||
            case when ca.count_discharge = 0 then 'Discharge, ' else '' end,
            ', '
        ) as missing_activities_list,
        
        case when c.process_path = ref.ideal_process_path then true else false end as is_path_compliant

    from cases c
    cross join reference_journey ref
    inner join case_activity_audit ca on c.case_id = ca.case_id
    inner join ordering_check oc on c.case_id = oc.case_id

)

select
    case_id,
    department,
    doctor_id,
    priority,
    journey_type,
    actual_process_path,
    ideal_process_path,
    is_path_compliant,
    case
        when is_path_compliant then 'Compliant'
        else 'Non-Compliant'
    end as conformance_status,
    case
        when is_path_compliant then 'Path conforms exactly to standard linear reference journey'
        when has_repeated_activity and not has_ordering_violation and missing_activities_list = '' 
            then 'Loopback repetition: secondary clinical review/triage performed'
        when has_ordering_violation then 'Incorrect sequence ordering'
        when missing_activities_list != '' then 'Missing mandatory activity: ' || missing_activities_list
        when has_unexpected_activities then 'Contains activity outside reference journey specification'
        else 'Deviation from standard pathway'
    end as deviation_reason,
    has_repeated_activity,
    has_ordering_violation,
    has_unexpected_activities,
    case when missing_activities_list = '' then null else missing_activities_list end as missing_activities,
    event_count,
    ideal_event_count,
    event_count_variance,
    cycle_time_minutes,
    'This is a project-defined analytical reference baseline for demonstration/conformance analysis. It is not an official clinical practice guideline.' as reference_journey_source,
    {{ dbt.current_timestamp() }} as analyzed_at
from conformance_base
order by case_id
