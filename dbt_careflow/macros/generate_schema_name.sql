{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if target.type == 'bigquery' -%}
        {%- if custom_schema_name is none -%}
            {{ default_schema }}
        {%- else -%}
            careflow_{{ custom_schema_name | trim }}
        {%- endif -%}
    {%- else -%}
        {{ default_schema }}
    {%- endif -%}

{%- endmacro %}
