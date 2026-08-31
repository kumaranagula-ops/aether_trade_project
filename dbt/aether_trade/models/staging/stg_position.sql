-- Unlike orders/execution, the native pipeline (sql/snowflake/02_raw_stg.sql)
-- does not flatten POSITION_CDC into its own STG table — only RAW.POSITION_CDC
-- exists. dbt does that flatten here, directly from RAW, following the same
-- "latest image per key" pattern the Snowflake Tasks use for orders/execution
-- (see sql/snowflake/04_pipes_streams_tasks.sql), keyed on account+security+day.
select
    payload:account_id::number            as account_id,
    payload:security_id::number           as security_id,
    payload:qty::number(18,4)             as qty,
    payload:avg_cost::number(18,6)        as avg_cost,
    payload:last_px::number(18,6)         as last_px,
    payload:updated_at::timestamp_ntz     as updated_at,
    coalesce(
        payload:as_of_date::date,
        payload:updated_at::timestamp_ntz::date
    )                                      as as_of_date,
    event_ts                              as src_event_ts
from {{ source('raw', 'position_cdc') }}
where op <> 'D'
qualify row_number() over (
    partition by
        payload:account_id::number,
        payload:security_id::number,
        coalesce(payload:as_of_date::date, payload:updated_at::timestamp_ntz::date)
    order by event_ts desc
) = 1
