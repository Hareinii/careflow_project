"""
CareFlow - Create Raw Event Log Table (Day 5)
----------------------------------------------------
Creates the raw_ehr_events table, partitioned by event_timestamp (day)
so later queries only scan the days they actually need, and clustered
by case_id/activity_name to speed up the transition/bottleneck queries
Week 2-3 will run against it.

Usage:
    python create_table.py
"""

from google.cloud import bigquery

from bigquery_client import get_client
from config import full_table_id
from schemas import RAW_EHR_EVENTS_SCHEMA


def create_table():
    client = get_client()
    table_ref = full_table_id()

    table = bigquery.Table(table_ref, schema=RAW_EHR_EVENTS_SCHEMA)
    table.time_partitioning = bigquery.TimePartitioning(
        type_=bigquery.TimePartitioningType.DAY,
        field="event_timestamp",
    )
    table.clustering_fields = ["case_id", "activity_name"]
    table.description = "Raw, timestamped EHR event log ingested from mock hospital data"

    table = client.create_table(table, exists_ok=True)
    print(f"Table ready: {table.table_id}")
    print(f"Partitioned by: event_timestamp (day)")
    print(f"Clustered by: {table.clustering_fields}")


if __name__ == "__main__":
    create_table()
