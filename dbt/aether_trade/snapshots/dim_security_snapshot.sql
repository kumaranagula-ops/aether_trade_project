{% snapshot dim_security_snapshot %}
{{
    config(
        target_schema=env_var('SNOWFLAKE_SCHEMA', 'MART_DBT') ~ '_snapshots',
        unique_key='security_id',
        strategy='check',
        check_cols=['ticker', 'isin', 'security_name', 'asset_class', 'exchange_code'],
    )
}}
select * from {{ ref('stg_security') }}
{% endsnapshot %}
