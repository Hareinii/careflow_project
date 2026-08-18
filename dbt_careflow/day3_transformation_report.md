# Day 3 Transformation Report

## Overview
Day 3 transforms the raw event log into an analytical data model with:
1. Ordered events with sequencing and transition analysis
2. Case-level fact table with aggregated journey metrics
3. Process path analysis for journey pattern discovery

## Deliverables

### Models Created

#### 1. int_careflow__ordered_events (Intermediate)
- **Purpose**: Add event sequencing and transition information to raw events
- **Grain**: One row per event
- **Key Features**:
  - Event sequence numbering within each case
  - Previous/Next activity identification using LAG/LEAD
  - Previous/Next event timestamps
  - Transition duration in minutes between consecutive events
  - First/Last event flags for each case
  - Full case duration timestamps

#### 2. fct_careflow__cases (Fact Table)
- **Purpose**: Aggregate events to case level for analytical reporting
- **Grain**: One row per case
- **Key Metrics**:
  - First and last event timestamps
  - First and last activity names
  - Event count (total events per case)
  - Unique activity count (number of distinct activities)
  - Cycle time in minutes (case duration from first to last event)
  - Process path (ordered sequence of activities)
  - Repeat activity flag (detects loopbacks/repeated activities)

#### 3. mart_careflow__process_paths (Journey Analysis)
- **Purpose**: Aggregate cases by unique journey patterns
- **Grain**: One row per unique process path
- **Key Metrics**:
  - Case count per path
  - Percentage of total cases per path
  - Average/Min/Max cycle time per path
  - Count of cases with repeated activities per path
  - Department, provider, and priority diversity per path
  - Ordered by frequency (most common paths first)

## Data Pipeline Architecture

```
stg_careflow__events (raw cleaned events)
           ↓
int_careflow__ordered_events (sequenced with transitions)
           ↓
fct_careflow__cases (case-level aggregation)
           ↓
mart_careflow__process_paths (journey pattern analysis)
```

## Key Transformations

### Event Sequencing
- Events ordered by case_id and event_timestamp
- Row numbering creates event_sequence field
- LAG/LEAD windows identify previous and next activities

### Cycle Time Calculation
- Difference between last and first event timestamp
- Measured in minutes for granularity
- Null for single-event cases (0 minute cycle)

### Activity Tracking
- Total event count captures all activity instances
- Unique activity count identifies distinct activity types
- Difference between counts reveals repeated activities
- Process path concatenates all activities in order

### Path Aggregation
- Groups cases by their complete process path
- Calculates frequency and performance statistics
- Identifies patterns in case journeys
- Detects unusual or loopback patterns

## Tests Created

1. **test_ordered_events_sequence_integrity**: Validates event sequence numbering
2. **test_ordered_events_lag_lead_logic**: Validates previous/next activity logic
3. **test_cases_activity_count_logic**: Ensures unique_activity_count ≤ event_count
4. **test_cases_repeat_activity_flag**: Validates repeat activity flag accuracy
5. **test_process_paths_case_totals**: Ensures case counts sum correctly across paths

## Usage Examples

### Case-Level Analysis
Query fct_careflow__cases to:
- Calculate average cycle time by department
- Identify cases with repeated activities (loopbacks)
- Track first and last activities to detect bottlenecks
- Analyze event counts by priority level

### Journey Pattern Analysis
Query mart_careflow__process_paths to:
- Identify most common patient journeys
- Compare cycle times across different journey patterns
- Find paths with highest repeat activity rates
- Analyze organizational patterns by department/provider

## Files Modified/Created

### Models
- models/intermediate/int_careflow__ordered_events.sql
- models/marts/fct_careflow__cases.sql
- models/marts/mart_careflow__process_paths.sql

### Schema Definitions (YAML)
- models/intermediate/int_careflow__ordered_events.yml
- models/marts/fct_careflow__cases.yml
- models/marts/mart_careflow__process_paths.yml

### Tests
- tests/test_ordered_events_sequence_integrity.sql
- tests/test_ordered_events_lag_lead_logic.sql
- tests/test_cases_activity_count_logic.sql
- tests/test_cases_repeat_activity_flag.sql
- tests/test_process_paths_case_totals.sql

## Next Steps

Day 4 will build:
- Transition-level metrics (time between specific activity pairs)
- Bottleneck analysis (activities with highest wait times)
- KPI marts for dashboard consumption
- Waiting time calculations by activity transition
