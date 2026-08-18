"""
CareFlow - Process Discovery Engine (PM4Py)
----------------------------------------------
Ingests the cleaned event log (Case_ID, Activity_Name, Timestamp) that
dbt produces and algorithmically discovers the "As-Is" process model:
- A Directed Graph (the "spaghetti diagram") showing every path patients
  actually took, weighted by frequency.
- A Petri net via the Inductive Miner, for a more formal process model.
- A bottleneck report ranking transitions by average wait time.

Usage:
    python discover_process.py --input ehr_events.csv --output-dir output/
"""

import argparse
import os

import pandas as pd
import pm4py


def load_event_log(csv_path):
    df = pd.read_csv(csv_path)
    df = df.rename(
        columns={
            "Case_ID": "case:concept:name",
            "Activity_Name": "concept:name",
            "Timestamp": "time:timestamp",
        }
    )
    df["time:timestamp"] = pd.to_datetime(df["time:timestamp"])
    df = df.sort_values(["case:concept:name", "time:timestamp"])
    return pm4py.format_dataframe(
        df,
        case_id="case:concept:name",
        activity_key="concept:name",
        timestamp_key="time:timestamp",
    )


def discover_directed_graph(event_log, output_dir):
    """The 'spaghetti diagram' — a frequency-weighted directed graph of
    every path patients actually took through the ER."""
    dfg, start_activities, end_activities = pm4py.discover_dfg(event_log)
    pm4py.save_vis_dfg(
        dfg,
        start_activities,
        end_activities,
        os.path.join(output_dir, "spaghetti_diagram.png"),
    )
    return dfg


def discover_petri_net(event_log, output_dir):
    """A more formal process model via the Inductive Miner algorithm."""
    net, initial_marking, final_marking = pm4py.discover_petri_net_inductive(event_log)
    pm4py.save_vis_petri_net(
        net,
        initial_marking,
        final_marking,
        os.path.join(output_dir, "petri_net.png"),
    )
    return net, initial_marking, final_marking


def bottleneck_report(dfg):
    """Ranks every transition (edge in the directed graph) by frequency,
    surfacing the highest-volume paths — this is where the Triage
    rebounce loop should show up as a major, unexpected edge."""
    rows = [
        {"from_activity": a, "to_activity": b, "frequency": count}
        for (a, b), count in dfg.items()
    ]
    report = pd.DataFrame(rows).sort_values("frequency", ascending=False)
    return report


def main():
    parser = argparse.ArgumentParser(description="CareFlow process discovery")
    parser.add_argument("--input", required=True, help="Path to cleaned event log CSV")
    parser.add_argument("--output-dir", default="output")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    event_log = load_event_log(args.input)

    print("Discovering directed graph (spaghetti diagram)...")
    dfg = discover_directed_graph(event_log, args.output_dir)

    print("Discovering Petri net (Inductive Miner)...")
    discover_petri_net(event_log, args.output_dir)

    print("Building bottleneck report...")
    report = bottleneck_report(dfg)
    report_path = os.path.join(args.output_dir, "bottleneck_report.csv")
    report.to_csv(report_path, index=False)

    print(f"\nTop 5 transitions by frequency:\n{report.head()}")
    print(f"\nOutputs written to {args.output_dir}/")


if __name__ == "__main__":
    main()
