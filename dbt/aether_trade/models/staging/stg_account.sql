select
    account_id,
    customer_id,
    account_no,
    account_type,
    base_ccy,
    status,
    opened_dt
from {{ source('stg', 'account') }}
