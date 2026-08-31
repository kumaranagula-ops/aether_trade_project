-- dbt-owned replacement for the hand-rolled MERGE in
-- sql/snowflake/04_pipes_streams_tasks.sql (TASK_FACT_EXECUTION). Same
-- grain and same merge key (execution_id); the difference is this is
-- tested, documented, and lineage-tracked instead of a bare Task.
{{
    config(
        materialized='incremental',
        unique_key='execution_id',
        incremental_strategy='merge',
    )
}}

with execs as (
    select * from {{ ref('stg_execution') }}
    {% if is_incremental() %}
    where fill_ts > (select coalesce(max(fill_ts), '1900-01-01') from {{ this }})
    {% endif %}
),

orders as (
    select order_id, side from {{ ref('stg_orders') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['e.execution_id']) }}  as execution_sk,
    e.execution_id,
    e.order_id,
    da.account_sk,
    dc.customer_sk,
    dadv.advisor_sk,
    dsec.security_sk,
    to_number(to_char(e.fill_ts::date, 'YYYYMMDD'))              as trade_date_sk,
    o.side,
    e.fill_qty,
    e.fill_px,
    e.fill_qty * e.fill_px                                        as notional,
    e.commission,
    e.venue,
    e.fill_ts
from execs e
join orders o
    on o.order_id = e.order_id
left join {{ ref('dim_account') }} da
    on da.account_id = e.account_id and da.is_current
left join {{ ref('dim_customer') }} dc
    on dc.customer_id = da.customer_id and dc.is_current
left join {{ ref('dim_advisor') }} dadv
    on dadv.advisor_id = dc.advisor_id and dadv.is_current
left join {{ ref('dim_security') }} dsec
    on dsec.security_id = e.security_id and dsec.is_current
