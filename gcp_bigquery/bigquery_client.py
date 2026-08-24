"""
CareFlow - BigQuery Client Wrapper (Day 5)
-----------------------------------------------
A thin wrapper around google.cloud.bigquery.Client so every script uses
the same auth setup and project ID, instead of duplicating client
construction everywhere.
"""

from google.cloud import bigquery
from config import require_project_id


def get_client():
    project_id = require_project_id()
    return bigquery.Client(project=project_id)
