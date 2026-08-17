"""
CareFlow - Mock EHR Event Schema
------------------------------------
Defines the shape of a single EHR event record before any code
generates or loads data. Every downstream script (the data generator
in Week 1-2, the BigQuery loader, dbt models, PM4Py) depends on this
exact structure staying consistent, so it's defined once, here, first.

An "event" is one row = one thing that happened to one patient at one
point in time. A patient's full ER visit is many rows.
"""

from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class ActivityName(str, Enum):
    """The fixed set of clinical activities a patient can move through.
    Keeping this as an enum (not free text) is what makes process
    mining possible later — PM4Py needs a closed set of activity names
    to build a reliable process model."""

    REGISTRATION = "Registration"
    TRIAGE = "Triage"
    XRAY = "X-Ray"
    TRIAGE_REBOUNCE = "Triage (Rebounce - Missing Form)"
    DOCTOR_CONSULTATION = "Doctor Consultation"
    DISCHARGE = "Discharge"


@dataclass
class EHREvent:
    """One row of the mock EHR event log.

    Field names intentionally match what BigQuery/dbt/PM4Py expect
    downstream, so no renaming has to happen later in the pipeline:
        patient_id      -> case_id      (process mining "case" identifier)
        activity        -> activity_name
        timestamp       -> event_timestamp
    """

    patient_id: str       # unique per patient visit, e.g. a UUID
    activity: ActivityName
    timestamp: datetime

    def to_csv_row(self) -> list:
        """Matches the column order the CSV export (Day 4) will use:
        Patient, Activity, Timestamp."""
        return [self.patient_id, self.activity.value, self.timestamp.isoformat()]


# CSV header row, defined once so the generator (Day 2) and the CSV
# export step (Day 4) can't drift out of sync with each other.
CSV_HEADER = ["Patient", "Activity", "Timestamp"]


# Example of one patient's full event sequence, for documentation and
# for writing the first unit test against once the generator exists.
EXAMPLE_PATIENT_JOURNEY = [
    EHREvent("PATIENT_0001", ActivityName.REGISTRATION, datetime(2026, 8, 13, 10, 0)),
    EHREvent("PATIENT_0001", ActivityName.TRIAGE, datetime(2026, 8, 13, 10, 10)),
    EHREvent("PATIENT_0001", ActivityName.XRAY, datetime(2026, 8, 13, 10, 25)),
    EHREvent("PATIENT_0001", ActivityName.DOCTOR_CONSULTATION, datetime(2026, 8, 13, 11, 5)),
    EHREvent("PATIENT_0001", ActivityName.DISCHARGE, datetime(2026, 8, 13, 11, 30)),
]


if __name__ == "__main__":
    # Quick manual check that the schema round-trips to CSV rows cleanly.
    for event in EXAMPLE_PATIENT_JOURNEY:
        print(event.to_csv_row())
