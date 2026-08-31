{% snapshot dim_customer_snapshot %}
{{
    config(
        target_schema=env_var('SNOWFLAKE_SCHEMA', 'MART_DBT') ~ '_snapshots',
        unique_key='customer_id',
        strategy='check',
        check_cols=['advisor_id', 'customer_code', 'full_name', 'kyc_status', 'risk_profile', 'tax_residency'],
    )
}}
select * from {{ ref('stg_customer') }}
{% endsnapshot %}
