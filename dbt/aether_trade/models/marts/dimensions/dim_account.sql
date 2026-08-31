select
    {{ dbt_utils.generate_surrogate_key(['account_id', 'dbt_valid_from']) }} as account_sk,
    account_id,
    account_no,
    customer_id,
    account_type,
    base_ccy,
    status,
    opened_dt,
    dbt_valid_from as effective_from,
    dbt_valid_to as effective_to,
    dbt_valid_to is null as is_current
from {{ ref('dim_account_snapshot') }}
