"""
CareFlow - Reference Ideal Journey & Conformance Checking (Day 16)
--------------------------------------------------------------------------
Defines the hospital's "ideal"/mandated patient path, then checks every
real generated patient case against it — flagging exactly which cases
deviated and why. This is what turns "40% of patients looped back" from
an observation into an auditable, per-case data quality/compliance
metric.

Usage:
    python conformance_check.py --input mock_events.csv --output conformance_report.csv
"""

import argparse
import csv
from collections import defaultdict

from schema.ehr_event_schema import ActivityName

# The mandated/ideal path every patient is expected to follow — no
# loop-backs, no rework. This is the baseline every real case is
# compared against.
IDEAL_PATH = [
    ActivityName.REGISTRATION.value,
    ActivityName.TRIAGE.value,
    ActivityName.XRAY.value,
    ActivityName.DOCTOR_CONSULTATION.value,
    ActivityName.DISCHARGE.value,
]


def read_patient_sequences(csv_path):
    """Groups CSV rows into an ordered activity sequence per patient."""
    sequences = defaultdict(list)
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        rows = sorted(reader, key=lambda r: (r["Patient"], r["Timestamp"]))
    for row in rows:
        sequences[row["Patient"]].append(row["Activity"])
    return sequences


def check_conformance(actual_sequence, ideal_sequence=IDEAL_PATH):
    """Returns (is_conformant, deviation_reason). A case is conformant
    only if its actual sequence exactly matches the ideal path — any
    extra, missing, or reordered activity counts as a deviation."""
    if actual_sequence == ideal_sequence:
        return True, None

    if ActivityName.TRIAGE_REBOUNCE.value in actual_sequence:
        return False, "Triage rebounce - missing paperwork form"

    if len(actual_sequence) < len(ideal_sequence):
        return False, "Incomplete journey - missing expected activities"

    if len(actual_sequence) > len(ideal_sequence):
        return False, "Extra activities beyond the ideal path"

    return False, "Sequence order deviates from the ideal path"


def run_conformance_report(csv_path, output_path):
    sequences = read_patient_sequences(csv_path)

    results = []
    conformant_count = 0
    deviation_reasons = defaultdict(int)

    for patient_id, sequence in sequences.items():
        is_conformant, reason = check_conformance(sequence)
        if is_conformant:
            conformant_count += 1
        else:
            deviation_reasons[reason] += 1

        results.append(
            {
                "patient": patient_id,
                "is_conformant": is_conformant,
                "deviation_reason": reason or "",
                "actual_path": " -> ".join(sequence),
            }
        )

    with open(output_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["patient", "is_conformant", "deviation_reason", "actual_path"])
        writer.writeheader()
        writer.writerows(results)

    total = len(sequences)
    conformant_pct = 100 * conformant_count / total if total else 0

    print(f"Checked {total} patient cases against the ideal path:")
    print(f"  Conformant: {conformant_count} ({conformant_pct:.1f}%)")
    print(f"  Deviated:   {total - conformant_count} ({100 - conformant_pct:.1f}%)")
    print(f"\n--- Deviation Reasons ---")
    for reason, count in deviation_reasons.items():
        print(f"  {reason}: {count}")

    print(f"\nFull per-case report written to {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check patient cases against the ideal journey")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", default="conformance_report.csv")
    args = parser.parse_args()

    run_conformance_report(args.input, args.output)
