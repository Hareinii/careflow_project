/*
=============================================================================
MODEL: mart_careflow__bottlenecks
PROJECT: CareFlow Data Analyst Portfolio Project — Day 4
=============================================================================

PURPOSE
-------
Identifies potential process bottlenecks for business investigation.
This model does NOT declare any transition a confirmed operational bottleneck.
Instead it applies multi-signal scoring to surface transitions that warrant
further operational investigation.

GRAIN
-----
One row = one unique transition type.

METHODOLOGY
-----------
No single metric determines a bottleneck. Five signals are used:

  Signal 1 — High Median Duration
    Indicates the typical (not just extreme) case takes long on this step.
    Threshold: median_duration_minutes > median of all medians.

  Signal 2 — High P95 Duration
    Indicates a long-tail risk — some cases experience very long delays.
    Threshold: p95_duration_minutes > median of all p95 values.

  Signal 3 — High Transition Volume
    High-frequency transitions carry systemic risk even if per-case duration
    is moderate. Threshold: transition_count > median of all counts.

  Signal 4 — High Share of Total Transition Time
    Transitions consuming the most total process time.
    Threshold: share_of_total_transition_time_pct > median of all shares.

  Signal 5 — High Duration Variability
    High standard deviation suggests inconsistent performance —
    some cases fly through, others stall. This is operationally concerning.
    Threshold: stddev_duration_minutes > median of all stddev values.

All thresholds are percentile/median-based on the actual dataset values.
No arbitrary fixed thresholds are used.

CLASSIFICATION LABELS
---------------------
Each signal contributes one label when triggered:
  - "High Duration"    : Signal 1 triggered
  - "High Tail Risk"   : Signal 2 triggered
  - "High Volume"      : Signal 3 triggered
  - "High Time Share"  : Signal 4 triggered
  - "High Variability" : Signal 5 triggered

bottleneck_signals_count = number of signals triggered (0–5).

CAUTION: These are analytical candidates only.
Business context is required to confirm any bottleneck designation.

=============================================================================
*/

with transitions as (

    select * from {{ ref('mart_careflow__transitions') }}

),

/*
  Compute dataset-level thresholds using medians of each metric.
  This makes thresholds data-driven rather than fixed constants.
*/
thresholds as (

    select
        percentile_cont(0.50) within group (order by median_duration_minutes)
            as threshold_median_duration,
        percentile_cont(0.50) within group (order by p95_duration_minutes)
            as threshold_p95_duration,
        percentile_cont(0.50) within group (order by transition_count)
            as threshold_volume,
        percentile_cont(0.50) within group (order by share_of_total_transition_time_pct)
            as threshold_time_share,
        percentile_cont(0.50) within group (order by coalesce(stddev_duration_minutes, 0))
            as threshold_variability
    from transitions

),

bottleneck_signals as (

    select
        t.transition_name,
        t.transition_count,
        t.case_count,
        t.null_duration_count,
        t.negative_duration_count,
        t.avg_duration_minutes,
        t.median_duration_minutes,
        t.p90_duration_minutes,
        t.p95_duration_minutes,
        t.min_duration_minutes,
        t.max_duration_minutes,
        t.stddev_duration_minutes,
        t.total_duration_sum,
        t.share_of_total_transition_time_pct,

        -- Threshold values (for transparency / documentation)
        th.threshold_median_duration,
        th.threshold_p95_duration,
        th.threshold_volume,
        th.threshold_time_share,
        th.threshold_variability,

        -- Individual signal flags
        case when t.median_duration_minutes > th.threshold_median_duration
            then true else false end                             as signal_high_duration,

        case when t.p95_duration_minutes > th.threshold_p95_duration
            then true else false end                             as signal_high_tail_risk,

        case when t.transition_count > th.threshold_volume
            then true else false end                             as signal_high_volume,

        case when t.share_of_total_transition_time_pct > th.threshold_time_share
            then true else false end                             as signal_high_time_share,

        case when coalesce(t.stddev_duration_minutes, 0) > th.threshold_variability
            then true else false end                             as signal_high_variability

    from transitions t
    cross join thresholds th

),

bottleneck_classified as (

    select
        *,

        -- Count of signals triggered
        (case when signal_high_duration    then 1 else 0 end
         + case when signal_high_tail_risk   then 1 else 0 end
         + case when signal_high_volume      then 1 else 0 end
         + case when signal_high_time_share  then 1 else 0 end
         + case when signal_high_variability then 1 else 0 end) as bottleneck_signals_count,

        -- Human-readable signal list
        trim(
            case when signal_high_duration    then 'High Duration | '    else '' end ||
            case when signal_high_tail_risk   then 'High Tail Risk | '   else '' end ||
            case when signal_high_volume      then 'High Volume | '      else '' end ||
            case when signal_high_time_share  then 'High Time Share | '  else '' end ||
            case when signal_high_variability then 'High Variability | ' else '' end,
            ' |'
        )                                                        as bottleneck_flags,

        -- Overall candidate classification
        case
            when (case when signal_high_duration    then 1 else 0 end
                  + case when signal_high_tail_risk   then 1 else 0 end
                  + case when signal_high_volume      then 1 else 0 end
                  + case when signal_high_time_share  then 1 else 0 end
                  + case when signal_high_variability then 1 else 0 end) >= 3
            then 'Strong Candidate'
            when (case when signal_high_duration    then 1 else 0 end
                  + case when signal_high_tail_risk   then 1 else 0 end
                  + case when signal_high_volume      then 1 else 0 end
                  + case when signal_high_time_share  then 1 else 0 end
                  + case when signal_high_variability then 1 else 0 end) >= 2
            then 'Moderate Candidate'
            when (case when signal_high_duration    then 1 else 0 end
                  + case when signal_high_tail_risk   then 1 else 0 end
                  + case when signal_high_volume      then 1 else 0 end
                  + case when signal_high_time_share  then 1 else 0 end
                  + case when signal_high_variability then 1 else 0 end) >= 1
            then 'Weak Candidate'
            else 'No Signal'
        end                                                      as bottleneck_category

    from bottleneck_signals

)

select
    transition_name,
    bottleneck_category,
    bottleneck_signals_count,
    bottleneck_flags,
    transition_count,
    case_count,
    avg_duration_minutes,
    median_duration_minutes,
    p90_duration_minutes,
    p95_duration_minutes,
    min_duration_minutes,
    max_duration_minutes,
    stddev_duration_minutes,
    share_of_total_transition_time_pct,
    null_duration_count,
    negative_duration_count,
    signal_high_duration,
    signal_high_tail_risk,
    signal_high_volume,
    signal_high_time_share,
    signal_high_variability,
    threshold_median_duration,
    threshold_p95_duration,
    threshold_volume,
    threshold_time_share,
    threshold_variability
from bottleneck_classified
order by bottleneck_signals_count desc, avg_duration_minutes desc
