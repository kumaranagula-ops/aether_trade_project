select
    {{ dbt_utils.generate_surrogate_key(['advisor_id', 'dbt_valid_from']) }} as advisor_sk,
    advisor_id,
    advisor_code,
    full_name as advisor_name,
    branch_code,
    region,
    is_active,
    dbt_valid_from as effective_from,
    dbt_valid_to as effective_to,
    dbt_valid_to is null as is_current
from {{ ref('dim_advisor_snapshot') }}
