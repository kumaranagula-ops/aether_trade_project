select
    {{ dbt_utils.generate_surrogate_key(['status_code']) }} as status_sk,
    status_code,
    status_desc
from {{ ref('order_status') }}
