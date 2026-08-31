{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        merge_update_columns=['status_sk', 'filled_qty', 'remaining_qty', 'last_update_ts'],
    )
}}

with orders as (
    select * from {{ ref('stg_orders') }}
    {% if is_incremental() %}
    where last_update_ts > (select coalesce(max(last_update_ts), '1900-01-01') from {{ this }})
    {% endif %}
),

fills as (
    select order_id, sum(fill_qty) as filled_qty
    from {{ ref('stg_execution') }}
    group by order_id
)

select
    {{ dbt_utils.generate_surrogate_key(['o.order_id']) }}     as order_sk,
    o.order_id,
    da.account_sk,
    dc.customer_sk,
    dadv.advisor_sk,
    dsec.security_sk,
    to_number(to_char(o.order_ts::date, 'YYYYMMDD'))           as order_date_sk,
    dos.status_sk,
    o.side,
    o.order_type,
    o.ordered_qty,
    o.limit_px,
    coalesce(f.filled_qty, 0)                                   as filled_qty,
    o.ordered_qty - coalesce(f.filled_qty, 0)                   as remaining_qty,
    o.order_ts,
    o.last_update_ts
from orders o
left join fills f
    on f.order_id = o.order_id
left join {{ ref('dim_account') }} da
    on da.account_id = o.account_id and da.is_current
left join {{ ref('dim_customer') }} dc
    on dc.customer_id = da.customer_id and dc.is_current
left join {{ ref('dim_advisor') }} dadv
    on dadv.advisor_id = dc.advisor_id and dadv.is_current
left join {{ ref('dim_security') }} dsec
    on dsec.security_id = o.security_id and dsec.is_current
left join {{ ref('dim_order_status') }} dos
    on dos.status_code = o.status
