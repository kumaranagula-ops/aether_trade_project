select
    {{ dbt_utils.generate_surrogate_key(['security_id', 'dbt_valid_from']) }} as security_sk,
    security_id,
    ticker,
    isin,
    security_name,
    asset_class,
    exchange_code,
    dbt_valid_from as effective_from,
    dbt_valid_to as effective_to,
    dbt_valid_to is null as is_current
from {{ ref('dim_security_snapshot') }}
