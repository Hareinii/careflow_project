"""
CareFlow - Export & Validate Generated Data (Day 4)
---------------------------------------------------------
Two things this script does, matching Day 4's scope exactly:

1. EXPORT: takes the CSV that generate_mock_events.py produces and
   also writes it out as JSON — some downstream consumers (APIs,
   quick inspection, non-BigQuery tools) prefer JSON over CSV.

2. VALIDATE: runs structural checks on the CSV *before* it ever goes
   near BigQuery. This is a local, fast, offline sanity check — the
   separate, heavier validation in gcp_bigquery/validate_data.py
   (Week 2) checks the data *after* it's loaded into the warehouse.
   Catching problems here is much cheaper than catching them there.

Usage:
    python export_and_validate.py --input mock_events.csv --json-output mock_events.json
"""

import argparse
import csv
import json
import sys
from datetime import datetime

from schema.ehr_event_schema import ActivityName, CSV_HEADER

VALID_ACTIVITIES = {a.value for a in ActivityName}


def read_csv(csv_path):
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        return list(reader), reader.fieldnames


def export_to_json(rows, json_path):
    with open(json_path, "w") as f:
        json.dump(rows, f, indent=2)
    print(f"Exported {len(rows)} rows -> {json_path}")


def validate_structure(rows, fieldnames):
    """Runs a checklist of structural checks and returns a list of
    (check_name, passed, detail) tuples."""
    results = []

    def check(name, passed, detail):
        results.append((name, passed, detail))
        status = "PASS" if passed else "FAIL"
        print(f"[{status}] {name}: {detail}")

    # 1. Header matches the schema exactly
    expected = CSV_HEADER
    check(
        "Header columns",
        list(fieldnames) == expected,
        f"expected {expected}, got {list(fieldnames)}",
    )

    # 2. No missing/empty values in any required field
    missing = [
        i for i, row in enumerate(rows)
        if not row.get("Patient") or not row.get("Activity") or not row.get("Timestamp")
    ]
    check("No missing values", len(missing) == 0, f"{len(missing)} rows with a blank field")

    # 3. Every Activity value is one of the allowed enum values
    bad_activities = {
        row["Activity"] for row in rows if row["Activity"] not in VALID_ACTIVITIES
    }
    check(
        "Valid activity names",
        len(bad_activities) == 0,
        f"unexpected activity values: {bad_activities}" if bad_activities else "all activities recognized",
    )

    # 4. Every Timestamp parses as a real ISO 8601 datetime
    bad_timestamps = 0
    for row in rows:
        try:
            datetime.fromisoformat(row["Timestamp"])
        except ValueError:
            bad_timestamps += 1
    check("Parseable timestamps", bad_timestamps == 0, f"{bad_timestamps} unparseable timestamp values")

    # 5. Each patient's events are in chronological order
    patients = {}
    for row in rows:
        patients.setdefault(row["Patient"], []).append(row["Timestamp"])

    out_of_order = [
        pid for pid, timestamps in patients.items()
        if timestamps != sorted(timestamps)
    ]
    check(
        "Chronological order per patient",
        len(out_of_order) == 0,
        f"{len(out_of_order)} patients with out-of-order events",
    )

    # 6. Every patient has at least the minimum expected event count (5)
    short_journeys = [pid for pid, ts in patients.items() if len(ts) < 5]
    check(
        "Minimum events per patient",
        len(short_journeys) == 0,
        f"{len(short_journeys)} patients with fewer than 5 events",
    )

    return results


def main():
    parser = argparse.ArgumentParser(description="Export and validate generated EHR data")
    parser.add_argument("--input", required=True, help="Path to the generated CSV")
    parser.add_argument("--json-output", default="mock_events.json")
    args = parser.parse_args()

    rows, fieldnames = read_csv(args.input)
    print(f"Loaded {len(rows)} rows from {args.input}\n")

    print("--- Validation ---")
    results = validate_structure(rows, fieldnames)

    print("\n--- Export ---")
    export_to_json(rows, args.json_output)

    failed = [r for r in results if not r[1]]
    if failed:
        print(f"\n{len(failed)} validation check(s) FAILED.")
        sys.exit(1)
    else:
        print("\nAll validation checks passed. Data is ready for BigQuery loading.")


if __name__ == "__main__":
    main()
