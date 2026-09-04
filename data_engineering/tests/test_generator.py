"""
CareFlow - Unit Tests for Data Generation
------------------------------------------------
Run with: python -m pytest tests/ -v
(or: python -m unittest discover tests -v  if pytest isn't installed)

These tests catch regressions in the generator as it keeps changing
across days — e.g. if a future edit accidentally breaks the CSV column
order, or drifts the rebounce rate way off target, these tests fail
loudly instead of the problem being discovered later in BigQuery.
"""

import sys
import os
import unittest
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from schema.ehr_event_schema import ActivityName, EHREvent, CSV_HEADER
from departments import department_for_activity
from generate_mock_events import generate_all_events, generate_patient_journey


class TestSchema(unittest.TestCase):
    def test_csv_row_matches_header_order(self):
        event = EHREvent("PATIENT_00001", ActivityName.TRIAGE, datetime(2026, 1, 1, 10, 0))
        row = event.to_csv_row()
        self.assertEqual(len(row), len(CSV_HEADER))
        self.assertEqual(row[0], "PATIENT_00001")
        self.assertEqual(row[1], "Triage")

    def test_all_activities_have_a_department(self):
        # Every activity in the enum must map to a department, or the
        # department load report will crash on that activity.
        for activity in ActivityName:
            dept = department_for_activity(activity)
            self.assertIsNotNone(dept)


class TestPatientJourney(unittest.TestCase):
    def test_journey_without_rebounce_has_five_events(self):
        journey = generate_patient_journey(
            "PATIENT_00001", datetime(2026, 1, 1, 8, 0), rebounce_rate=0.0
        )
        self.assertEqual(len(journey), 5)

    def test_journey_with_forced_rebounce_has_six_events(self):
        journey = generate_patient_journey(
            "PATIENT_00001", datetime(2026, 1, 1, 8, 0), rebounce_rate=1.0
        )
        self.assertEqual(len(journey), 6)
        activities = [e.activity for e, _ in journey]
        self.assertIn(ActivityName.TRIAGE_REBOUNCE, activities)

    def test_events_are_chronologically_ordered(self):
        journey = generate_patient_journey(
            "PATIENT_00001", datetime(2026, 1, 1, 8, 0), rebounce_rate=1.0
        )
        timestamps = [e.timestamp for e, _ in journey]
        self.assertEqual(timestamps, sorted(timestamps))


class TestGeneratorAtScale(unittest.TestCase):
    def test_correct_number_of_patients_generated(self):
        events, _ = generate_all_events(100, datetime(2026, 1, 1), rebounce_rate=0.40)
        patient_ids = {e.patient_id for e, _ in events}
        self.assertEqual(len(patient_ids), 100)

    def test_rebounce_rate_within_reasonable_tolerance(self):
        # With 1000 patients, the actual rate should land close to the
        # target — a wide-but-meaningful tolerance to avoid flaky tests
        # while still catching a genuinely broken rebounce_rate check.
        _, rebounced_count = generate_all_events(1000, datetime(2026, 1, 1), rebounce_rate=0.40)
        actual_rate = rebounced_count / 1000
        self.assertAlmostEqual(actual_rate, 0.40, delta=0.08)

    def test_every_patient_has_minimum_five_events(self):
        events, _ = generate_all_events(200, datetime(2026, 1, 1), rebounce_rate=0.40)
        counts = {}
        for e, _ in events:
            counts[e.patient_id] = counts.get(e.patient_id, 0) + 1
        self.assertTrue(all(c >= 5 for c in counts.values()))


if __name__ == "__main__":
    unittest.main()
