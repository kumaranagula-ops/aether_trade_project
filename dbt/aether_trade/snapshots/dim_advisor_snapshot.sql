{% snapshot dim_advisor_snapshot %}
{{
    config(
        target_schema=env_var('SNOWFLAKE_SCHEMA', 'MART_DBT') ~ '_snapshots',
        unique_key='advisor_id',
        strategy='check',
        check_cols=['advisor_code', 'full_name', 'branch_code', 'region', 'is_active'],
    )
}}
select * from {{ ref('stg_advisor') }}
{% endsnapshot %}
