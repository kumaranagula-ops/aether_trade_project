-- Reconciliation check: notional must equal fill_qty * fill_px exactly.
-- Same spirit as the load-time reconciliation/threshold checks used on the
-- legacy Informatica/Teradata pipeline — a failing row here means the
-- transform layer, not the source data, has a bug.
select *
from {{ ref('fact_execution') }}
where abs(notional - (fill_qty * fill_px)) > 0.01
