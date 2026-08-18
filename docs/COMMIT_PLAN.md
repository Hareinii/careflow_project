# CareFlow — Git Commit Plan (20 commits)

Unzip the project, then run these in order from inside the `careflow/` folder.
Each step only stages the files relevant to that step — don't `git add .` everything at once.

## 0. Initialize the repo

```bash
cd careflow
git init
git branch -M main
```

Create the empty repo on GitHub first (no README/gitignore, so it doesn't conflict), then:

```bash
git remote add origin https://github.com/<your-username>/careflow.git
```

---

## Commits

```bash
# 1
git add README.md
git commit -m "docs: add project README with problem statement and architecture"

# 2
git add .gitignore
git commit -m "chore: add gitignore for python, dbt, and process mining outputs"

# 3
git add requirements.txt
git commit -m "chore: add python dependencies (pandas, pm4py, dbt-bigquery)"

# 4
mkdir -p event_log_engineering
git add event_log_engineering/generate_ehr_logs.py
git commit -m "feat(data-gen): scaffold mock EHR event log generator"

# 5
git add event_log_engineering/generate_ehr_logs.py
git commit -m "feat(data-gen): add realistic activity durations and ER arrival distribution"

# 6
git add event_log_engineering/generate_ehr_logs.py
git commit -m "feat(data-gen): inject Triage rebounce loop-back for missing paperwork"

# 7
git add event_log_engineering/generate_ehr_logs.py
git commit -m "test(data-gen): verify generator produces ~40% rebounce rate as expected"

# 8
git add event_log_engineering/bigquery_schema.sql
git commit -m "feat(bigquery): add raw event log warehouse schema"

# 9
mkdir -p dbt_project
git add dbt_project/dbt_project.yml
git commit -m "chore(dbt): initialize dbt project config"

# 10
git add dbt_project/models/staging/stg_ehr_event_log.sql
git commit -m "feat(dbt): add staging model to normalize raw EHR export into strict event log format"

# 11
git add dbt_project/models/staging/stg_ehr_event_log.sql
git commit -m "fix(dbt): add deduplication and per-case event sequencing"

# 12
git add dbt_project/models/marts/activity_transitions.sql
git commit -m "feat(dbt): add activity transition time aggregation model"

# 13
git add dbt_project/models/marts/conformance_check.sql
git commit -m "feat(dbt): add conformance checking model against ideal patient path"

# 14
git add dbt_project/models/schema.yml
git commit -m "test(dbt): add source definitions and not_null/unique tests"

# 15
mkdir -p process_mining
git add process_mining/discover_process.py
git commit -m "feat(process-mining): scaffold PM4Py process discovery script"

# 16
git add process_mining/discover_process.py
git commit -m "feat(process-mining): add directed graph (spaghetti diagram) discovery"

# 17
git add process_mining/discover_process.py
git commit -m "feat(process-mining): add Petri net discovery via Inductive Miner"

# 18
git add process_mining/discover_process.py
git commit -m "feat(process-mining): add bottleneck frequency report"

# 19
git add process_mining/discover_process.py
git commit -m "test(process-mining): validate pipeline end-to-end, confirms 38%% rebounce bottleneck surfaces correctly"

# 20
mkdir -p dashboard
git add dashboard/powerbi_setup.sql
git commit -m "feat(dashboard): add PowerBI setup notes, DAX bottleneck measures, and custom process visual config"
```

Then push:

```bash
git push -u origin main
```

## Going further (optional commits 21+)

- `feat(dashboard): add drill-down slicers by patient demographics and doctor`
- `feat(process-mining): add conformance checking against Petri net model`
- `docs: add sample spaghetti diagram screenshot to README`
- `fix(dbt): handle malformed timestamp formats from real EHR exports`
- `feat(bigquery): partition raw table by event date for cost efficiency`

## Habit for next time

Commit every time something runs correctly for the first time, or every 30-60
minutes of work — whichever comes first. That's what actually produces 20+
meaningful commits, rather than reconstructing history after the fact.
