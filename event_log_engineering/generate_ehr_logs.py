"""
CareFlow - Mock EHR Event Log Generator
-----------------------------------------
Generates a synthetic hospital event log (Case_ID, Activity_Name, Timestamp)
mimicking a real Emergency Room patient journey, with a deliberately
injected operational inefficiency: ~40% of patients get sent back to
Triage after an X-Ray because of a missing paperwork step. This is the
"hidden bottleneck" the process mining engine (PM4Py) is meant to surface.

Usage:
    python generate_ehr_logs.py --num-patients 2000 --output ehr_events.csv
"""

import argparse
import csv
import random
import uuid
from datetime import datetime, timedelta

# The "happy path" activities every patient goes through, in order
HAPPY_PATH = [
    "Registration",
    "Triage",
    "X-Ray",
    "Doctor Consultation",
    "Discharge",
]

# Minutes typically spent on each activity (min, max) - used to advance
# the timestamp realistically between events
ACTIVITY_DURATION_MIN = {
    "Registration": (5, 15),
    "Triage": (10, 25),
    "X-Ray": (15, 40),
    "Doctor Consultation": (10, 30),
    "Discharge": (5, 10),
}

REBOUNCE_RATE = 0.40  # ~40% of patients loop back to Triage after X-Ray
MISSING_FORM_NOTE = "Missing paperwork form"


def advance_time(current_time, activity):
    lo, hi = ACTIVITY_DURATION_MIN[activity]
    return current_time + timedelta(minutes=random.randint(lo, hi))


def generate_patient_journey(case_id, start_time):
    """Generate the sequence of (Case_ID, Activity_Name, Timestamp) events
    for one patient, injecting the Triage rebounce loop-back for a
    deliberately realistic fraction of cases."""
    events = []
    t = start_time

    def log(activity):
        nonlocal t
        events.append((case_id, activity, t.isoformat()))
        t = advance_time(t, activity)

    log("Registration")
    log("Triage")
    log("X-Ray")

    # The hidden bottleneck: missing paperwork sends the patient back
    # to Triage before they can proceed to the doctor.
    if random.random() < REBOUNCE_RATE:
        events.append((case_id, "Triage (Rebounce - Missing Form)", t.isoformat()))
        t = advance_time(t, "Triage")
        # After the second Triage pass, patient can now proceed
        log("Doctor Consultation")
    else:
        log("Doctor Consultation")

    log("Discharge")

    return events


def main():
    parser = argparse.ArgumentParser(description="Generate mock CareFlow EHR event log")
    parser.add_argument("--num-patients", type=int, default=2000)
    parser.add_argument("--output", type=str, default="ehr_events.csv")
    parser.add_argument("--date", type=str, default=datetime.today().strftime("%Y-%m-%d"))
    args = parser.parse_args()

    base_date = datetime.strptime(args.date, "%Y-%m-%d")

    with open(args.output, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Case_ID", "Activity_Name", "Timestamp"])
        rebounce_count = 0

        for _ in range(args.num_patients):
            case_id = str(uuid.uuid4())
            # Spread patient arrivals across a 24-hour window, with an ER
            # rush-hour bump in the evening
            arrival_hour = random.choices(
                population=range(24),
                weights=[1] * 16 + [3, 4, 5, 5, 4, 3, 2, 1],  # bump at 16-23h
                k=1,
            )[0]
            start_time = base_date.replace(
                hour=arrival_hour, minute=random.randint(0, 59)
            )

            journey = generate_patient_journey(case_id, start_time)
            if any("Rebounce" in e[1] for e in journey):
                rebounce_count += 1

            for row in journey:
                writer.writerow(row)

    pct = 100 * rebounce_count / args.num_patients
    print(
        f"Generated event log for {args.num_patients} patients -> {args.output}\n"
        f"Triage rebounce rate: {rebounce_count} patients ({pct:.1f}%)"
    )


if __name__ == "__main__":
    main()
