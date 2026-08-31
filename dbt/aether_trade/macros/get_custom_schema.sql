{#
    Standard dbt override: a model's `+schema: staging` config APPENDS to the
    target schema (MART_DBT_staging) instead of replacing it (staging).
    Without this, two environments with different target schemas would both
    dump staging models into a literal schema named "staging" and collide.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
