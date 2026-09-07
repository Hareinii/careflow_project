/*
=============================================================================
MACRO: percentile (and exact_percentile alias)
PROJECT: CareFlow Clinical Pathway Process Mining
=============================================================================

PURPOSE
-------
Computes continuous percentile values across different SQL warehouse engines.

SEMANTICS & ENGINE-SPECIFIC BEHAVIOR
------------------------------------
- Google BigQuery (Production Authoritative):
    Uses APPROX_QUANTILES(col, 100)[OFFSET(p*100)] to compute quantiles over 
    a 100-bucket distribution. In BigQuery, continuous percentile windowing 
    over grouped aggregations is calculated via APPROX_QUANTILES.
    This provides stable, highly performant, and production-scale percentile
    approximations suitable for bottleneck thresholding and SLA monitoring.
- DuckDB / ANSI SQL (Local Testing Fallback):
    Uses PERCENTILE_CONT(p) WITHIN GROUP (ORDER BY col).

NOTE: Per project analytical guidelines, BigQuery percentiles must NOT be 
described as 'exact' since they leverage BigQuery's APPROX_QUANTILES engine.
=============================================================================
*/

{% macro percentile(pct_val, order_by_column) %}
    {% if target.type == 'bigquery' %}
        APPROX_QUANTILES({{ order_by_column }}, 100)[OFFSET({{ (pct_val * 100) | int }})]
    {% else %}
        percentile_cont({{ pct_val }}) within group (order by {{ order_by_column }})
    {% endif %}
{% endmacro %}

{# Backward-compatibility alias #}
{% macro exact_percentile(pct_val, order_by_column) %}
    {{ percentile(pct_val, order_by_column) }}
{% endmacro %}
