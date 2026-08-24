"""
CareFlow - Create BigQuery Dataset (Day 5)
------------------------------------------------
Creates the dataset that will hold the raw EHR event log table. Safe
to re-run: uses exists_ok=True so it won't fail if it already exists.

Usage:
    python create_dataset.py
"""

from google.cloud import bigquery

from bigquery_client import get_client
from config import BQ_DATASET_LOCATION, full_dataset_id


def create_dataset():
    client = get_client()
    dataset_ref = full_dataset_id()

    dataset = bigquery.Dataset(dataset_ref)
    dataset.location = BQ_DATASET_LOCATION
    dataset.description = "CareFlow raw EHR event log storage"
    dataset.labels = {"project": "careflow", "layer": "raw"}

    dataset = client.create_dataset(dataset, exists_ok=True)
    print(f"Dataset ready: {dataset.dataset_id} (location={dataset.location})")


if __name__ == "__main__":
    create_dataset()
