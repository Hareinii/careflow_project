"""
CareFlow - BigQuery Table Schema (Day 5)
----------------------------------------------
Defines the raw_ehr_events table structure. Field order here MUST
match the CSV column order your generator produces (Patient, Activity,
Timestamp), since load_csv.py loads positionally with skip_leading_rows=1
rather than by matching header names.
"""

from google.cloud import bigquery

RAW_EHR_EVENTS_SCHEMA = [
    bigquery.SchemaField(
        "case_id", "STRING", mode="REQUIRED",
        description="Unique patient/case identifier (maps from CSV 'Patient' column)"
    ),
    bigquery.SchemaField(
        "activity_name", "STRING", mode="REQUIRED",
        description="Clinical activity name (maps from CSV 'Activity' column)"
    ),
    bigquery.SchemaField(
        "event_timestamp", "TIMESTAMP", mode="REQUIRED",
        description="When the activity occurred (maps from CSV 'Timestamp' column)"
    ),
]
