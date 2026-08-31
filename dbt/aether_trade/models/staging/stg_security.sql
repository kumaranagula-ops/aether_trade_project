select
    security_id,
    exchange_code,
    ticker,
    isin,
    security_name,
    asset_class
from {{ source('stg', 'security') }}
