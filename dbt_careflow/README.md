# CareFlow — Healthcare Patient Flow Analytics

## Project
CareFlow is a healthcare operations and patient-flow analytics project designed to demonstrate data analyst capabilities in SQL, dbt, and BigQuery.

## Objective
Analyze patient and case flow, waiting time, and operational bottlenecks to identify where delays accumulate and what operational changes could improve throughput.

## Team role
Transformation Lead — SQL + dbt + BigQuery

## Current phase
Day 1 — dbt architecture and schema design

## Architecture
Raw Event Log
      ↓
BigQuery
      ↓
dbt Staging
      ↓
dbt Marts
      ↓
Analytics / Dashboard

## Data flow
The project is structured to form a clean transformation layer:

Raw data -> BigQuery -> Staging layer -> Marts layer -> Dashboard / analytical outputs

## Future analytical questions
1. Where does waiting accumulate?
2. Which process stage creates the biggest bottleneck?
3. How does priority affect waiting time?
4. How does journey type affect cycle time?
5. Which cases experience excessive delays?
6. What operational changes could reduce waiting?

## Day 1 scope
This phase focuses on the foundational dbt architecture only:
- define the project structure
- define the raw source in BigQuery
- create a staging placeholder model
- create a mart placeholder model
- document the schema and data-quality expectations
- keep the project interview-ready and free from credentials or unnecessary complexity

## Notes
- The temporary CSV provided during setup is not assumed to be the final production schema.
- Waiting metrics require business validation before being treated as KPI logic.
- Negative waiting values are not automatically removed without investigation.
