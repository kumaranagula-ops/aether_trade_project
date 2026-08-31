select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'dbt_valid_from']) }} as customer_sk,
    customer_id,
    customer_code,
    full_name as customer_name,
    advisor_id,
    kyc_status,
    risk_profile,
    tax_residency,
    dbt_valid_from as effective_from,
    dbt_valid_to as effective_to,
    dbt_valid_to is null as is_current
from {{ ref('dim_customer_snapshot') }}
