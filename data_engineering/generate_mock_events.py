"""
CareFlow - Mock Hospital Event Log Generator (Day 3)
--------------------------------------------------------
Builds directly on Day 2's generator. The only change: a percentage of
patients now get sent back to Triage after their X-Ray, before they're
allowed to see a doctor — simulating the real-world "missing paperwork
form" bottleneck described in the CareFlow problem statement.

This is deliberate, injected noise — the whole point of the project is
proving that PM4Py (Week 3+) can rediscover this bottleneck automatically
from the raw event data, with no prior knowledge that it's here.

Usage:
    python generate_mock_events.py --num-patients 500 --output mock_events.csv --rebounce-rate 0.40
"""

import argparse
import csv
import random
from datetime import datetime, timedelta

from schema.ehr_event_schema import ActivityName, EHREvent, CSV_HEADER

# The standard patient path, in order
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
    ActivityName.TRIAGE_REBOUNCE: (10, 25),  # same as a normal Triage visit
    ActivityName.DOCTOR_CONSULTATION: (10, 30),
    ActivityName.DISCHARGE: (5, 10),
}


def generate_patient_journey(
    patient_id: str, start_time: datetime, rebounce_rate: float
) -> list[EHREvent]:
    """Builds one patient's journey. With probability `rebounce_rate`,
    the patient gets sent back to Triage after X-Ray (missing
    paperwork) before reaching the doctor — everyone else follows the
    Day 2 straight-line path."""
    events = []
    t = start_time

    def log(activity: ActivityName):
        nonlocal t
        events.append(EHREvent(patient_id, activity, t))
        lo, hi = ACTIVITY_DURATION_MIN[activity]
        t = t + timedelta(minutes=random.randint(lo, hi))

    log(ActivityName.REGISTRATION)
    log(ActivityName.TRIAGE)
    log(ActivityName.XRAY)

    if random.random() < rebounce_rate:
        log(ActivityName.TRIAGE_REBOUNCE)  # the injected bottleneck

    log(ActivityName.DOCTOR_CONSULTATION)
    log(ActivityName.DISCHARGE)

    return events


def generate_all_events(
    num_patients: int, base_date: datetime, rebounce_rate: float
) -> list[EHREvent]:
    all_events = []
    rebounced_count = 0

    for i in range(num_patients):
        patient_id = f"PATIENT_{i:05d}"
        arrival_hour = random.randint(0, 23)
        start_time = base_date.replace(
            hour=arrival_hour, minute=random.randint(0, 59)
        )
        journey = generate_patient_journey(patient_id, start_time, rebounce_rate)
        if any(e.activity == ActivityName.TRIAGE_REBOUNCE for e in journey):
            rebounced_count += 1
        all_events.extend(journey)

    return all_events, rebounced_count


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
    parser.add_argument(
        "--rebounce-rate", type=float, default=0.40,
        help="Fraction of patients rerouted through Triage after X-Ray (default 0.40)"
    )
    args = parser.parse_args()

    base_date = datetime.strptime(args.date, "%Y-%m-%d")
    events, rebounced_count = generate_all_events(
        args.num_patients, base_date, args.rebounce_rate
    )
    write_csv(events, args.output)

    pct = 100 * rebounced_count / args.num_patients
    print(f"Generated {len(events)} events for {args.num_patients} patients -> {args.output}")
    print(f"Triage rebounce rate: {rebounced_count} patients ({pct:.1f}%)")


if __name__ == "__main__":
    main()
