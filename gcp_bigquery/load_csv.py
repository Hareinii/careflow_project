"""
CareFlow - Load Initial Simulated Data (Day 5)
-----------------------------------------------------
Loads the mock event CSV (from data_engineering/generate_mock_events.py)
into the raw BigQuery table.

Usage:
    python load_csv.py --input ../data_engineering/mock_events.csv
"""

import argparse
import sys
from datetime import datetime, timezone

from google.cloud import bigquery

from bigquery_client import get_client
from config import full_table_id
from schemas import RAW_EHR_EVENTS_SCHEMA


def load_csv(csv_path):
    client = get_client()
    table_ref = full_table_id()

    job_config = bigquery.LoadJobConfig(
        schema=RAW_EHR_EVENTS_SCHEMA,
        skip_leading_rows=1,  # skips the "Patient,Activity,Timestamp" header row
        source_format=bigquery.SourceFormat.CSV,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    )

    print(f"Starting load job: {csv_path} -> {table_ref}")

    try:
        with open(csv_path, "rb") as source_file:
            load_job = client.load_table_from_file(
                source_file, table_ref, job_config=job_config
            )
            load_job.result()  # blocks until finished, raises on failure
    except Exception as exc:
        print(f"Load job failed: {exc}", file=sys.stderr)
        sys.exit(1)

    table = client.get_table(table_ref)
    print(f"Load complete. Table now has {table.num_rows} rows.")
    print(f"Loaded at: {datetime.now(timezone.utc).isoformat()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load EHR event CSV into BigQuery")
    parser.add_argument("--input", required=True, help="Path to the mock EHR events CSV")
    args = parser.parse_args()

    load_csv(args.input)
