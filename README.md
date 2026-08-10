# CareFlow 🏥
### Clinical Pathway Process Mining

**Domain:** Healthcare Operations & Process Analytics

## The Problem

Hospital administrators don't know why Emergency Room wait times are so high. Standard BI dashboards only show an "average wait time" — they can't map the chaotic, real-world sequence of events a patient actually experiences, which hides the true operational bottlenecks.

## The Solution

CareFlow ingests raw, timestamped event logs from a hospital's Electronic Health Record (EHR) system (e.g. `Patient A: Triage at 10:00 -> X-Ray at 10:15 -> Triage at 10:30`) and uses process mining to algorithmically discover a visual "spaghetti diagram" of actual patient flows — not the idealized path on paper, but what really happens.

**Example use case:** Running CareFlow against a hospital's EHR logs surfaces a massive, hidden bottleneck: 40% of patients are being sent back to Triage after an X-Ray because of a specific missing paperwork form. The administrator fixes the intake form and immediately cuts average wait times by 20 minutes.

This repo includes a working proof of concept — a synthetic EHR log generator that injects this exact bottleneck, and a PM4Py pipeline that rediscovers it purely from the event data, with no prior knowledge of the injected rule.

## Architecture

| Layer | Technology | Purpose |
|---|---|---|
| **Data Warehouse** | Google BigQuery | Stores massive volumes of chronological healthcare event logs |
| **Data Transformation** | dbt | Normalizes messy EHR exports into a strict `Case_ID, Activity_Name, Timestamp` event log format |
| **Process Mining Engine** | PM4Py (Python) | Discovers process models (Petri nets, directed graphs) directly from event data — no manual mapping |
| **Dashboard** | Microsoft Power BI | Custom process-flowchart visuals plus standard operational KPIs, with drill-down by patient/doctor |

## Pipeline Overview

```
Raw EHR Export (Case_ID, Activity_Name, Timestamp)
        │
        ▼
  BigQuery (raw event log storage)
        │
        ▼
  dbt (cleaning, deduplication, sequencing into strict Event Log format)
        │
        ▼
  PM4Py (Directed Graph / spaghetti diagram + Petri net discovery)
        │
        ▼
  Power BI (interactive process dashboard, bottleneck KPIs, drill-down)
```

## Proof of Concept Result

Running the included generator (500 mock patients) and process discovery script produced this directed graph automatically, with **zero manual process mapping**:

- 500 patients: Registration → Triage → X-Ray
- **192 patients (38.4%)** rerouted through `Triage (Rebounce – Missing Form)` before reaching a doctor
- 308 patients proceeded straight from X-Ray to Doctor Consultation

That 38.4% rebounce loop is exactly the kind of hidden bottleneck standard "average wait time" dashboards can't surface — and PM4Py found it directly from raw event data.

## Key Features

- **Synthetic EHR event log generator** simulating realistic ER patient journeys, including a deliberately injected inefficiency loop-back
- **dbt-normalized event log** meeting the strict format process mining algorithms require
- **Automated process discovery** — directed graphs and Petri nets generated with no manual flowcharting
- **Bottleneck ranking** by transition frequency and average wait time
- **Conformance checking** — flags which patient cases deviated from the hospital's ideal/mandated path
- **Power BI dashboard** with custom process-visualization plugins and drill-down KPIs

## Development Roadmap

| Week | Event Log Engineering | Process Mining & BI |
|---|---|---|
| 1 | Generate mock EHR event logs with injected inefficiencies | Load raw logs into BigQuery, configure dbt |
| 2 | dbt models normalizing data into strict Event Log format | PM4Py process discovery — directed graph of the "As-Is" process |
| — | *Mid-project review: pipeline audit + algorithm check* | |
| 3 | Bottleneck calculations (average transition time per node) | Power BI dashboard with custom process mining visuals |
| 4 | Conformance checking — actual vs. ideal patient journey | Polish: drill-down filters by patient demographics/doctor |

## Tech Stack

`Google BigQuery` · `dbt` · `PM4Py` · `Python` · `Power BI`

---

*A process mining pipeline for uncovering the hidden operational bottlenecks standard dashboards can't see.*
