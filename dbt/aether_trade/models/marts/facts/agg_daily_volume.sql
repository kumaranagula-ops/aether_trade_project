select
    d.cal_date       as as_of_date,
    f.advisor_sk,
    f.security_sk,
    sum(case when f.side = 'B' then f.fill_qty else 0 end)     as buy_qty,
    sum(case when f.side = 'S' then f.fill_qty else 0 end)     as sell_qty,
    sum(case when f.side = 'B' then f.notional else 0 end)     as buy_notional,
    sum(case when f.side = 'S' then f.notional else 0 end)     as sell_notional,
    count(*)                                                    as trade_count,
    sum(f.commission)                                           as commission_amt
from {{ ref('fact_execution') }} f
join {{ ref('dim_date') }} d
    on d.date_sk = f.trade_date_sk
group by 1, 2, 3
