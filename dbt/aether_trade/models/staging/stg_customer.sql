select
    customer_id,
    advisor_id,
    customer_code,
    full_name,
    kyc_status,
    risk_profile,
    tax_residency
from {{ source('stg', 'customer') }}
