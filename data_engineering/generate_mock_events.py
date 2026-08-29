"""
CareFlow - Mock Hospital Event Log Generator (Day 7)
--------------------------------------------------------
Two upgrades over Day 6:

1. REALISTIC TIME VARIANCE: durations were previously flat uniform
   random (random.randint(lo, hi) — a 15-minute wait was exactly as
   likely as a 39-minute wait). Real ER wait times aren't like that:
   most patients cluster near a typical duration, with a long tail of
   occasional much-longer waits. This version uses a triangular
   distribution (low, most-likely, high) to capture that shape.

2. REBOUNCE RATE VALIDATION: adds a statistical check confirming the
   actual rebounce rate lands within an acceptable tolerance of the
   requested rate, since random.random() < rate is probabilistic and
   can drift on small sample sizes.

Usage:
    python generate_mock_events.py --num-patients 500 --output mock_events.csv --rebounce-rate 0.40
"""

import argparse
import csv
import random
import statistics
from collections import defaultdict
from datetime import datetime, timedelta

from schema.ehr_event_schema import ActivityName, EHREvent, CSV_HEADER
from departments import department_for_activity

HAPPY_PATH = [
    ActivityName.REGISTRATION,
    ActivityName.TRIAGE,
    ActivityName.XRAY,
    ActivityName.DOCTOR_CONSULTATION,
    ActivityName.DISCHARGE,
]

# (low, most_likely, high) in minutes — triangular distribution params.
# most_likely is where the bulk of patients land; low/high are the
# realistic extremes (a fast pass-through vs. an unusually busy period).
ACTIVITY_DURATION_TRIANGULAR = {
    ActivityName.REGISTRATION: (3, 7, 20),
    ActivityName.TRIAGE: (8, 14, 30),
    ActivityName.XRAY: (12, 22, 50),
    ActivityName.TRIAGE_REBOUNCE: (8, 14, 30),  # same profile as a normal Triage visit
    ActivityName.DOCTOR_CONSULTATION: (8, 16, 40),
    ActivityName.DISCHARGE: (3, 6, 15),
}


def sample_duration(activity: ActivityName) -> int:
    lo, mode, hi = ACTIVITY_DURATION_TRIANGULAR[activity]
    return round(random.triangular(lo, hi, mode))


def generate_patient_journey(patient_id, start_time, rebounce_rate):
    events = []
    t = start_time

    def log(activity):
        nonlocal t
        duration = sample_duration(activity)
        events.append((EHREvent(patient_id, activity, t), duration))
        t = t + timedelta(minutes=duration)

    log(ActivityName.REGISTRATION)
    log(ActivityName.TRIAGE)
    log(ActivityName.XRAY)

    if random.random() < rebounce_rate:
        log(ActivityName.TRIAGE_REBOUNCE)

    log(ActivityName.DOCTOR_CONSULTATION)
    log(ActivityName.DISCHARGE)

    return events


def generate_all_events(num_patients, base_date, rebounce_rate):
    all_events_with_duration = []
    rebounced_count = 0

    for i in range(num_patients):
        patient_id = f"PATIENT_{i:05d}"
        arrival_hour = random.randint(0, 23)
        start_time = base_date.replace(hour=arrival_hour, minute=random.randint(0, 59))
        journey = generate_patient_journey(patient_id, start_time, rebounce_rate)
        if any(e.activity == ActivityName.TRIAGE_REBOUNCE for e, _ in journey):
            rebounced_count += 1
        all_events_with_duration.extend(journey)

    return all_events_with_duration, rebounced_count


def validate_rebounce_rate(actual_count, num_patients, target_rate, tolerance=0.05):
    """New in Day 7: confirms the generator's random rebounce injection
    actually landed close to the requested rate, instead of just
    trusting probability blindly. Flags a warning if it drifted too
    far — useful to catch on small sample sizes."""
    actual_rate = actual_count / num_patients
    diff = abs(actual_rate - target_rate)

    print(f"\n--- Rebounce Rate Validation ---")
    print(f"Target rate:  {target_rate*100:.1f}%")
    print(f"Actual rate:  {actual_rate*100:.1f}%")
    print(f"Difference:   {diff*100:.1f} percentage points (tolerance: ±{tolerance*100:.0f}pp)")

    if diff <= tolerance:
        print("[PASS] Actual rebounce rate is within tolerance of target.")
    else:
        print(
            "[WARNING] Actual rate drifted outside tolerance — consider a larger "
            "--num-patients sample size, since small samples are more prone to "
            "random drift away from the target rate."
        )


def report_duration_variance(events_with_duration):
    """New in Day 7: shows the min/mean/max duration per activity, to
    prove the triangular distribution actually produces variance
    (not the same duration every time) while still clustering near
    the realistic 'most likely' value."""
    durations_by_activity = defaultdict(list)
    for event, duration in events_with_duration:
        durations_by_activity[event.activity.value].append(duration)

    print("\n--- Duration Variance Report ---")
    print(f"{'Activity':<35}{'Min':<8}{'Mean':<8}{'Max':<8}{'StdDev':<8}")
    for activity, durations in durations_by_activity.items():
        mean = statistics.mean(durations)
        stdev = statistics.stdev(durations) if len(durations) > 1 else 0
        print(f"{activity:<35}{min(durations):<8}{mean:<8.1f}{max(durations):<8}{stdev:<8.1f}")


def report_department_load(events_with_duration):
    visits = defaultdict(int)
    minutes = defaultdict(int)
    for event, duration in events_with_duration:
        dept = department_for_activity(event.activity)
        visits[dept.name] += 1
        minutes[dept.name] += duration

    print("\n--- Department Load Report ---")
    print(f"{'Department':<25}{'Visits':<10}{'Total Minutes':<15}{'Avg Min/Visit':<15}")
    for dept_name in visits:
        v = visits[dept_name]
        m = minutes[dept_name]
        print(f"{dept_name:<25}{v:<10}{m:<15}{m/v:<15.1f}")


def write_csv(events_with_duration, output_path):
    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(CSV_HEADER)
        for event, _duration in events_with_duration:
            writer.writerow(event.to_csv_row())


def main():
    parser = argparse.ArgumentParser(description="Generate mock hospital event logs")
    parser.add_argument("--num-patients", type=int, default=500)
    parser.add_argument("--output", type=str, default="mock_events.csv")
    parser.add_argument("--date", type=str, default=datetime.today().strftime("%Y-%m-%d"))
    parser.add_argument("--rebounce-rate", type=float, default=0.40)
    args = parser.parse_args()

    base_date = datetime.strptime(args.date, "%Y-%m-%d")
    events_with_duration, rebounced_count = generate_all_events(
        args.num_patients, base_date, args.rebounce_rate
    )
    write_csv(events_with_duration, args.output)

    pct = 100 * rebounced_count / args.num_patients
    print(f"Generated {len(events_with_duration)} events for {args.num_patients} patients -> {args.output}")
    print(f"Triage rebounce rate: {rebounced_count} patients ({pct:.1f}%)")

    validate_rebounce_rate(rebounced_count, args.num_patients, args.rebounce_rate)
    report_duration_variance(events_with_duration)
    report_department_load(events_with_duration)


if __name__ == "__main__":
    main()
