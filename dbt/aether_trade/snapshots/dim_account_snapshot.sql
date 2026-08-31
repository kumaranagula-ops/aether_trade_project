{% snapshot dim_account_snapshot %}
{{
    config(
        target_schema=env_var('SNOWFLAKE_SCHEMA', 'MART_DBT') ~ '_snapshots',
        unique_key='account_id',
        strategy='check',
        check_cols=['customer_id', 'account_no', 'account_type', 'base_ccy', 'status', 'opened_dt'],
    )
}}
select * from {{ ref('stg_account') }}
{% endsnapshot %}
