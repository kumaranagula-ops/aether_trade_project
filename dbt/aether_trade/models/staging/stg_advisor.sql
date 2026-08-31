select
    advisor_id,
    branch_code,
    region,
    advisor_code,
    full_name,
    is_active
from {{ source('stg', 'advisor') }}
