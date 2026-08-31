-- Snowflake tenancy for Aether Trade
CREATE DATABASE IF NOT EXISTS AETHER_TRADE;
CREATE SCHEMA IF NOT EXISTS AETHER_TRADE.RAW;
CREATE SCHEMA IF NOT EXISTS AETHER_TRADE.STG;
CREATE SCHEMA IF NOT EXISTS AETHER_TRADE.MART;
CREATE SCHEMA IF NOT EXISTS AETHER_TRADE.CTRL;

-- Control / audit
CREATE TABLE IF NOT EXISTS AETHER_TRADE.CTRL.JOB_AUDIT (
    run_id              STRING,
    job_name            STRING,
    layer               STRING,
    start_ts            TIMESTAMP_NTZ,
    end_ts              TIMESTAMP_NTZ,
    status              STRING,
    source_row_count    NUMBER,
    target_row_count    NUMBER,
    error_message       STRING
);

CREATE TABLE IF NOT EXISTS AETHER_TRADE.CTRL.WATERMARK (
    source_name         STRING PRIMARY KEY,
    last_successful_ts  TIMESTAMP_NTZ,
    last_run_id         STRING,
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
