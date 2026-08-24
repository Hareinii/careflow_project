"""
CareFlow - GCP/BigQuery Config Loader (Day 5)
--------------------------------------------------
Central place every script in this folder pulls its GCP project,
dataset, and table settings from. Reads from a local .env file (see
.env.example) so nobody hardcodes project IDs in scripts.
"""

import os
from dotenv import load_dotenv

load_dotenv()

GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
BQ_DATASET_ID = os.getenv("BQ_DATASET_ID", "careflow_raw")
BQ_DATASET_LOCATION = os.getenv("BQ_DATASET_LOCATION", "US")
BQ_TABLE_ID = os.getenv("BQ_TABLE_ID", "ehr_events")


def require_project_id():
    if not GCP_PROJECT_ID:
        raise EnvironmentError(
            "GCP_PROJECT_ID is not set. Copy .env.example to .env and fill "
            "in your project ID before running any BigQuery script."
        )
    return GCP_PROJECT_ID


def full_table_id():
    return f"{require_project_id()}.{BQ_DATASET_ID}.{BQ_TABLE_ID}"


def full_dataset_id():
    return f"{require_project_id()}.{BQ_DATASET_ID}"
