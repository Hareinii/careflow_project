"""
CareFlow - Mock Hospital Event Log Generator (Day 2)
--------------------------------------------------------
Generates a synthetic hospital event log where every patient follows
the standard "happy path" through the ER:

    Registration -> Triage -> X-Ray -> Doctor Consultation -> Discharge

This is deliberately the SIMPLE version. Deliberate inefficiencies and
loop-backs (the Triage rebounce bottleneck) are added on Day 3, on top
of this file — keeping them separate makes it easy to prove each piece
works before adding complexity.

Uses the schema defined on Day 1 (data_engineering/schema/ehr_event_schema.py)
so every event this script produces matches that exact structure.

Usage:
    python generate_mock_events.py --num-patients 500 --output mock_events.csv
"""

import argparse
import csv
import random
import uuid
from datetime import datetime, timedelta

from schema.ehr_event_schema import ActivityName, EHREvent, CSV_HEADER

# The standard patient path, in order, for Day 2's simple version
HAPPY_PATH = [
    ActivityName.REGISTRATION,
    ActivityName.TRIAGE,
    ActivityName.XRAY,
    ActivityName.DOCTOR_CONSULTATION,
    ActivityName.DISCHARGE,
]

# Realistic minutes spent on each activity before the next one starts
ACTIVITY_DURATION_MIN = {
    ActivityName.REGISTRATION: (5, 15),
    ActivityName.TRIAGE: (10, 25),
    ActivityName.XRAY: (15, 40),
    ActivityName.DOCTOR_CONSULTATION: (10, 30),
    ActivityName.DISCHARGE: (5, 10),
}


def generate_patient_journey(patient_id: str, start_time: datetime) -> list[EHREvent]:
    """Builds one patient's full straight-line journey through the ER."""
    events = []
    t = start_time

    for activity in HAPPY_PATH:
        events.append(EHREvent(patient_id, activity, t))
        lo, hi = ACTIVITY_DURATION_MIN[activity]
        t = t + timedelta(minutes=random.randint(lo, hi))

    return events


def generate_all_events(num_patients: int, base_date: datetime) -> list[EHREvent]:
    all_events = []
    for i in range(num_patients):
        patient_id = f"PATIENT_{i:05d}"
        arrival_hour = random.randint(0, 23)
        start_time = base_date.replace(
            hour=arrival_hour, minute=random.randint(0, 59)
        )
        all_events.extend(generate_patient_journey(patient_id, start_time))
    return all_events


def write_csv(events: list[EHREvent], output_path: str):
    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(CSV_HEADER)
        for event in events:
            writer.writerow(event.to_csv_row())


def main():
    parser = argparse.ArgumentParser(description="Generate mock hospital event logs")
    parser.add_argument("--num-patients", type=int, default=500)
    parser.add_argument("--output", type=str, default="mock_events.csv")
    parser.add_argument("--date", type=str, default=datetime.today().strftime("%Y-%m-%d"))
    args = parser.parse_args()

    base_date = datetime.strptime(args.date, "%Y-%m-%d")
    events = generate_all_events(args.num_patients, base_date)
    write_csv(events, args.output)

    print(f"Generated {len(events)} events for {args.num_patients} patients -> {args.output}")
    print(f"Every patient follows the standard happy path (no bottlenecks yet — see Day 3)")


if __name__ == "__main__":
    main()
