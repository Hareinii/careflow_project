"""
CareFlow - Hospital Departments
-----------------------------------
"""

from dataclasses import dataclass
from schema.ehr_event_schema import ActivityName


@dataclass
class Department:
    name: str
    code: str
    typical_staff_count: int


DEPARTMENTS = {
    "FRONT_DESK": Department("Front Desk", "FD", typical_staff_count=2),
    "TRIAGE": Department("Triage", "TRI", typical_staff_count=4),
    "RADIOLOGY": Department("Radiology (X-Ray)", "RAD", typical_staff_count=3),
    "CONSULTATION": Department("Doctor Consultation", "DOC", typical_staff_count=6),
    "DISCHARGE_DESK": Department("Discharge Desk", "DIS", typical_staff_count=2),
}

ACTIVITY_TO_DEPARTMENT = {
    ActivityName.REGISTRATION: DEPARTMENTS["FRONT_DESK"],
    ActivityName.TRIAGE: DEPARTMENTS["TRIAGE"],
    ActivityName.TRIAGE_REBOUNCE: DEPARTMENTS["TRIAGE"],
    ActivityName.XRAY: DEPARTMENTS["RADIOLOGY"],
    ActivityName.DOCTOR_CONSULTATION: DEPARTMENTS["CONSULTATION"],
    ActivityName.DISCHARGE: DEPARTMENTS["DISCHARGE_DESK"],
}


def department_for_activity(activity: ActivityName) -> Department:
    return ACTIVITY_TO_DEPARTMENT[activity]
