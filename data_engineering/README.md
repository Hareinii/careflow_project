# CareFlow — Data Engineering Module

Generates synthetic hospital ER event logs for process mining analysis.

## Files

| File | Purpose |
|---|---|
| `schema/ehr_event_schema.py` | Defines the event structure (Patient, Activity, Timestamp) and the fixed set of allowed activities |
| `departments.py` | Maps each activity to the physical hospital department it occurs in |
| `generate_mock_events.py` | Generates the mock event log — realistic timing (triangular distribution), a deliberate 40% Triage rebounce bottleneck, and department load reporting |
| `export_and_validate.py` | Exports the CSV to JSON and runs local structural validation before the data goes to BigQuery |

## Usage

```bash
python generate_mock_events.py --num-patients 500 --output mock_events.csv --rebounce-rate 0.40
python export_and_validate.py --input mock_events.csv --json-output mock_events.json
```

## Output

A CSV/JSON event log where ~40% of patients are looped back through Triage
due to a simulated missing-paperwork bottleneck — the core pattern the
downstream process mining pipeline (PM4Py) is meant to discover automatically.