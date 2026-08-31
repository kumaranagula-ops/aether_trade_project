-- EOD position snapshot, one row per account/security/day. Reruns for a past
-- as_of_date are idempotent (merge on the natural key), which is what makes
-- the Airflow position DAG's catchup=True backfill behavior safe.
{{
    config(
        materialized='incremental',
        unique_key=['account_id', 'security_id', 'as_of_date'],
        incremental_strategy='merge',
    )
}}

with pos as (
    select * from {{ ref('stg_position') }}
    {% if is_incremental() %}
    where src_event_ts > (select coalesce(max(src_event_ts), '1900-01-01') from {{ this }})
    {% endif %}
)

select
    {{ dbt_utils.generate_surrogate_key(['p.account_id', 'p.security_id', 'p.as_of_date']) }} as pos_sk,
    p.account_id,
    p.security_id,
    p.as_of_date,
    da.account_sk,
    dc.customer_sk,
    dadv.advisor_sk,
    dsec.security_sk,
    to_number(to_char(p.as_of_date, 'YYYYMMDD'))    as as_of_date_sk,
    p.qty,
    p.avg_cost,
    p.last_px,
    p.qty * p.last_px                                as market_value,
    (p.last_px - p.avg_cost) * p.qty                 as unrealized_pnl
from pos p
left join {{ ref('dim_account') }} da
    on da.account_id = p.account_id and da.is_current
left join {{ ref('dim_customer') }} dc
    on dc.customer_id = da.customer_id and dc.is_current
left join {{ ref('dim_advisor') }} dadv
    on dadv.advisor_id = dc.advisor_id and dadv.is_current
left join {{ ref('dim_security') }} dsec
    on dsec.security_id = p.security_id and dsec.is_current
