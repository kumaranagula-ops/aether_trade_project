-- Standard date spine, ~2 years past the last business date so backfills
-- and near-term forward scheduling both resolve without a rebuild.
{% set start_date = "to_date('" ~ var('aether_trade_start_date') ~ "')" %}
{% set end_date = "dateadd(year, 2, current_date())" %}

with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date=start_date,
        end_date=end_date
    ) }}
)

select
    to_number(to_char(date_day, 'YYYYMMDD'))  as date_sk,
    date_day                                  as cal_date,
    year(date_day)                            as year_num,
    quarter(date_day)                         as quarter_num,
    month(date_day)                           as month_num,
    monthname(date_day)                       as month_name,
    dayname(date_day)                         as day_of_week,
    dayofweekiso(date_day) in (6, 7)          as is_weekend,
    not (dayofweekiso(date_day) in (6, 7))    as is_business_day
from spine
