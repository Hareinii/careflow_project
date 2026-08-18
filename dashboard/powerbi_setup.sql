-- CareFlow Dashboard - Power BI Setup Notes
-- --------------------------------------------
-- This project uses Power BI's "Process Mining" custom visual (or the
-- Power Automate Process Mining visual) to render the spaghetti diagram
-- inside a standard PowerBI report, alongside operational KPIs built
-- from the dbt marts.

-- 1. DATA SOURCE
-- Connect Power BI to BigQuery using the native BigQuery connector,
-- pointing at the `careflow` dbt marts schema (not raw) so the report
-- only ever reads clean, tested data:
--   - careflow.marts.stg_ehr_event_log
--   - careflow.marts.activity_transitions
--   - careflow.marts.conformance_check

-- 2. CUSTOM VISUAL
-- Import the "Process Mining for Power BI" custom visual from AppSource.
-- Bind it directly to stg_ehr_event_log using:
--   Case ID    -> case_id
--   Activity   -> activity_name
--   Timestamp  -> event_timestamp
-- This renders the same spaghetti-diagram concept as the PM4Py output,
-- but interactively inside the PowerBI canvas.

-- 3. KEY DAX MEASURES
-- Paste these into the PowerBI model once activity_transitions is loaded.

-- Average ER wait time across all cases (headline KPI)
Avg Wait Time (Minutes) =
AVERAGE ( activity_transitions[avg_transition_minutes] )

-- % of patients hitting the Triage rebounce bottleneck
Rebounce Rate % =
DIVIDE (
    CALCULATE ( COUNTROWS ( conformance_check ), conformance_check[is_conformant] = FALSE () ),
    COUNTROWS ( conformance_check ),
    0
) * 100

-- Minutes lost specifically to the Triage rebounce loop
Minutes Lost to Rebounce =
CALCULATE (
    SUM ( activity_transitions[avg_transition_minutes] ),
    activity_transitions[from_activity] = "X-Ray",
    activity_transitions[to_activity] = "Triage (Rebounce - Missing Form)"
)

-- 4. DRILL-DOWN FILTERS
-- Add slicers on patient demographics / doctor (once those fields exist
-- in the EHR export) so administrators can filter the process map by
-- who is most affected by the bottleneck, not just see the aggregate.
