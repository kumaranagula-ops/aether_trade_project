# dbt — Aether Trade STG → MART

This project owns the **STG → MART** transform. RAW → STG stays native
(Snowpipe + Streams + Tasks, see `../sql/snowflake/04_pipes_streams_tasks.sql`)
because that half is event-driven CDC, not a batch transform problem dbt is
built for. dbt takes over from STG onward: SCD Type 2 dimensions (via
snapshots), incremental fact merges, tests, and docs/lineage — replacing the
hand-rolled `MERGE` statements in `../sql/snowflake/03_mart.sql`.

Output lands in its own schema (`MART_DBT` by default, see
`profiles.yml.example`), deliberately separate from the `MART` schema the raw
SQL created, so nothing collides while both exist side by side.

## Layout

| Path | What |
|---|---|
| `models/staging/` | Thin 1:1 views over native `STG.*` (and `RAW.POSITION_CDC`, flattened here) |
| `snapshots/` | SCD Type 2 history for advisor/customer/account/security |
| `models/marts/dimensions/` | `dim_*` built on top of the snapshots, plus `dim_date` and the `dim_order_status` seed |
| `models/marts/facts/` | Incremental, merge-strategy `fact_*` tables and `agg_daily_volume` |
| `tests/` | Custom reconciliation check (execution notional) |

## Running it

```bash
cd dbt/aether_trade
cp profiles.yml.example ~/.dbt/profiles.yml   # or export DBT_PROFILES_DIR=$(pwd)
# fill in SNOWFLAKE_ACCOUNT / SNOWFLAKE_USER / SNOWFLAKE_PASSWORD (see ../.env.example)

dbt deps
dbt seed        # loads dim_order_status
dbt snapshot    # SCD2 history for the four dimensions
dbt run
dbt test
```

Or via Docker — see the root `README.md`'s "Running locally" section.
