# CareFlow — Data Engineering: Final Summary & Handoff Notes

## What was built (Weeks 1–4)

**Week 1 — Foundation**
Designed the mock EHR event schema, built the base generator producing straight-line patient journeys, injected the deliberate 40% Triage rebounce bottleneck, added local export/validation, and stood up the BigQuery warehouse with an initial data load.

**Week 2 — Realism & Scale**
Expanded the simulator with a department layer (mapping activities to physical hospital departments), upgraded timing from flat uniform randomness to a realistic triangular distribution, added write-disposition control for safe reloading, and validated chronological ordering and data volume directly via SQL for scale-readiness.

**Week 3 — Analysis-Ready Data**
Built transition-time extraction (the timing data bottleneck detection depends on), optimized the warehouse's partitioning/clustering for query performance, generated and validated bottleneck patterns at larger scale.

**Week 4 — Conformance & Delivery**
Built the reference "ideal" patient journey and a full conformance-checking report comparing every case against it, documented the end-to-end architecture, and prepared the pipeline for final demonstration.

## How to run the complete pipeline end-to-end

```bash
# 1. Generate data
cd data_engineering
python generate_mock_events.py --num-patients 1000 --output mock_events.csv --rebounce-rate 0.40

# 2. Validate locally
python export_and_validate.py --input mock_events.csv --json-output mock_events.json

# 3. Analyze transitions and conformance (no BigQuery needed for these two)
python transitions.py --input mock_events.csv --output transitions_report.csv
python conformance_check.py --input mock_events.csv --output conformance_report.csv

# 4. Load into BigQuery
cd ../gcp_bigquery
python create_dataset.py
python create_table.py
python load_csv.py --input ../data_engineering/mock_events.csv --write-disposition truncate

# 5. Validate at scale
python validate_scale.py --expected-row-count <row count from step 1's CSV>
```

## Known limitations / honest caveats

- The 40% rebounce rate is a chosen parameter matching the project's problem statement, not derived from real hospital data — appropriate for a mock/demo dataset, should be stated as such in any presentation.
- `load_csv.py` with `--write-disposition append` will create duplicates if the same CSV is loaded twice; use `truncate` when reloading a regenerated dataset.
- Conformance checking currently only distinguishes "ideal path" vs. "Triage rebounce deviation" — it does not yet categorize other theoretically possible deviation types, since the generator currently only produces this one bottleneck pattern.

## Cleanup checklist before final demo (Day 18)

- [ ] Drop any test/debug BigQuery datasets created during development (keep only `careflow_raw`)
- [ ] Confirm `.env` and `credentials/` were never committed to git (check `git log --all --full-history -- "*.env"` returns nothing)
- [ ] Regenerate a final, clean dataset for the demo rather than reusing accumulated test data
- [ ] Confirm `mock_events.csv` and `mock_events.json` are gitignored, not committed as stale artifacts
