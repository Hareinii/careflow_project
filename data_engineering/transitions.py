"""
CareFlow - Transition Time Extraction (Day 11)
----------------------------------------------------
Extracts the time elapsed between every consecutive pair of activities
per patient (e.g. Triage -> X-Ray took 18 minutes). This is the core
timing data every downstream bottleneck analysis depends on — without
it, the pipeline only knows an event happened, not how long patients
waited between steps.

Works directly against a generated CSV (local, fast to iterate on).
The equivalent SQL logic for running this against the full BigQuery
table is in gcp_bigquery/transitions.sql, once the dataset is loaded.

Usage:
    python transitions.py --input mock_events.csv --output transitions_report.csv
"""

import argparse
import csv
from collections import defaultdict
from datetime import datetime


def read_events(csv_path):
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    for row in rows:
        row["Timestamp"] = datetime.fromisoformat(row["Timestamp"])
    rows.sort(key=lambda r: (r["Patient"], r["Timestamp"]))
    return rows


def extract_transitions(rows):
    """Pairs each event with the next event for the same patient,
    computing the minutes between them."""
    transitions = []
    by_patient = defaultdict(list)
    for row in rows:
        by_patient[row["Patient"]].append(row)

    for patient_id, events in by_patient.items():
        for i in range(len(events) - 1):
            current = events[i]
            nxt = events[i + 1]
            minutes = (nxt["Timestamp"] - current["Timestamp"]).total_seconds() / 60
            transitions.append(
                {
                    "patient": patient_id,
                    "from_activity": current["Activity"],
                    "to_activity": nxt["Activity"],
                    "minutes": round(minutes, 1),
                }
            )
    return transitions


def aggregate_transitions(transitions):
    """Groups by (from_activity, to_activity) and computes summary
    stats — this is the table a bottleneck dashboard would read from."""
    grouped = defaultdict(list)
    for t in transitions:
        grouped[(t["from_activity"], t["to_activity"])].append(t["minutes"])

    summary = []
    for (from_act, to_act), minutes_list in grouped.items():
        summary.append(
            {
                "from_activity": from_act,
                "to_activity": to_act,
                "patient_count": len(minutes_list),
                "avg_minutes": round(sum(minutes_list) / len(minutes_list), 1),
                "min_minutes": round(min(minutes_list), 1),
                "max_minutes": round(max(minutes_list), 1),
            }
        )
    summary.sort(key=lambda s: s["patient_count"], reverse=True)
    return summary


def write_summary_csv(summary, output_path):
    with open(output_path, "w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["from_activity", "to_activity", "patient_count", "avg_minutes", "min_minutes", "max_minutes"]
        )
        writer.writeheader()
        writer.writerows(summary)


def main():
    parser = argparse.ArgumentParser(description="Extract activity transition timings")
    parser.add_argument("--input", required=True, help="Path to the mock EHR events CSV")
    parser.add_argument("--output", default="transitions_report.csv")
    args = parser.parse_args()

    rows = read_events(args.input)
    transitions = extract_transitions(rows)
    summary = aggregate_transitions(transitions)
    write_summary_csv(summary, args.output)

    print(f"Extracted {len(transitions)} individual transitions across {len(rows)} events")
    print(f"\n--- Transition Summary (by frequency) ---")
    print(f"{'From':<35}{'To':<35}{'Count':<8}{'Avg Min':<10}")
    for s in summary:
        print(f"{s['from_activity']:<35}{s['to_activity']:<35}{s['patient_count']:<8}{s['avg_minutes']:<10}")

    print(f"\nFull summary written to {args.output}")


if __name__ == "__main__":
    main()
