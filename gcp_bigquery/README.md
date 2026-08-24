# CareFlow — Day 5: BigQuery Dataset, Raw Table, Initial Load

## Setup (one-time)

1. Create a GCP project (or use an existing one) and enable the BigQuery API.
2. Create a service account with `BigQuery Data Editor` + `BigQuery Job User` roles, download its JSON key into `gcp_bigquery/credentials/` (already gitignored).
3. Copy `.env.example` to `.env`, fill in your real `GCP_PROJECT_ID`.
4. `pip install -r requirements.txt`

## Run in order

```bash
python create_dataset.py
python create_table.py
python load_csv.py --input ../data_engineering/mock_events.csv
```

## What each does

| Script | Purpose |
|---|---|
| `create_dataset.py` | Creates the `careflow_raw` dataset |
| `schemas.py` | Defines the `raw_ehr_events` table schema (case_id, activity_name, event_timestamp) |
| `create_table.py` | Creates the table, partitioned by day, clustered by case_id + activity_name |
| `load_csv.py` | Loads your generated `mock_events.csv` into the table |

## Note on column mapping

Your CSV header is `Patient, Activity, Timestamp` (from the Day 1 schema). The
BigQuery table uses `case_id, activity_name, event_timestamp` instead — these
are the standard names the rest of the pipeline (dbt, PM4Py) expects downstream.
The load works because `load_csv.py` loads **positionally** (column 1 → column 1,
etc.) with `skip_leading_rows=1` to skip the CSV header — so the names don't
need to match, only the column order does.

## Verify it worked

After running `load_csv.py`, check in the BigQuery console:

```sql
SELECT COUNT(*) FROM `your-project.careflow_raw.ehr_events`
```

The row count should match your CSV's row count exactly.
