select
    execution_id,
    order_id,
    account_id,
    security_id,
    fill_qty,
    fill_px,
    commission,
    venue,
    fill_ts,
    loaded_at
from {{ source('stg', 'execution') }}
