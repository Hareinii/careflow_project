-- CareFlow: BigQuery schema setup
-- Run via `bq` CLI or the BigQuery console.

CREATE SCHEMA IF NOT EXISTS `careflow.raw`
OPTIONS (
  description = "Raw EHR event log storage for CareFlow process mining",
  location = "US"
);

-- Raw event log, loaded directly from generate_ehr_logs.py output.
-- Deliberately loose typing here since real EHR exports are messy;
-- dbt (see dbt_project/models/staging) is responsible for cleaning this.
CREATE OR REPLACE TABLE `careflow.raw.ehr_events` (
    case_id       STRING,
    activity_name STRING,
    event_timestamp STRING  -- raw string; cast properly in dbt staging
);

-- Load with:
-- bq load --source_format=CSV --skip_leading_rows=1 \
--   careflow.raw.ehr_events ehr_events.csv \
--   Case_ID:STRING,Activity_Name:STRING,Timestamp:STRING
