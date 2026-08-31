-- Thin pass-through over the native STG.ORDERS table. Kept as its own model
-- (rather than reading the source directly from marts) so every downstream
-- model shares one column contract and one place to add renames/casts.
select
    order_id,
    account_id,
    security_id,
    entered_by,
    side,
    order_type,
    ordered_qty,
    limit_px,
    tif,
    status,
    reject_reason,
    order_ts,
    last_update_ts
from {{ source('stg', 'orders') }}
