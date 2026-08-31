-- RAW: land CDC / files as-is. Prefer VARIANT for payload + extracted keys.
CREATE OR REPLACE TABLE AETHER_TRADE.RAW.ORDERS_CDC (
    event_id        NUMBER,
    op              STRING,
    payload         VARIANT,
    event_ts        TIMESTAMP_NTZ,
    file_name       STRING,
    loaded_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE AETHER_TRADE.RAW.EXECUTION_CDC (
    event_id        NUMBER,
    op              STRING,
    payload         VARIANT,
    event_ts        TIMESTAMP_NTZ,
    file_name       STRING,
    loaded_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE AETHER_TRADE.RAW.POSITION_CDC (
    event_id        NUMBER,
    op              STRING,
    payload         VARIANT,
    event_ts        TIMESTAMP_NTZ,
    file_name       STRING,
    loaded_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE AETHER_TRADE.RAW.CASH_LEDGER_CDC (
    event_id        NUMBER,
    op              STRING,
    payload         VARIANT,
    event_ts        TIMESTAMP_NTZ,
    file_name       STRING,
    loaded_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE AETHER_TRADE.RAW.CUSTOMER_CDC LIKE AETHER_TRADE.RAW.ORDERS_CDC;
CREATE OR REPLACE TABLE AETHER_TRADE.RAW.ACCOUNT_CDC  LIKE AETHER_TRADE.RAW.ORDERS_CDC;
CREATE OR REPLACE TABLE AETHER_TRADE.RAW.SECURITY_CDC LIKE AETHER_TRADE.RAW.ORDERS_CDC;
CREATE OR REPLACE TABLE AETHER_TRADE.RAW.ADVISOR_CDC  LIKE AETHER_TRADE.RAW.ORDERS_CDC;

-- STG: flattened, typed, deduped latest image per business key
CREATE OR REPLACE TABLE AETHER_TRADE.STG.ORDERS (
    order_id        NUMBER,
    account_id      NUMBER,
    security_id     NUMBER,
    entered_by      NUMBER,
    side            STRING,
    order_type      STRING,
    ordered_qty     NUMBER(18,4),
    limit_px        NUMBER(18,6),
    tif             STRING,
    status          STRING,
    reject_reason   STRING,
    order_ts        TIMESTAMP_NTZ,
    last_update_ts  TIMESTAMP_NTZ,
    op              STRING,
    src_event_ts    TIMESTAMP_NTZ,
    loaded_at       TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE AETHER_TRADE.STG.EXECUTION (
    execution_id    NUMBER,
    order_id        NUMBER,
    account_id      NUMBER,
    security_id     NUMBER,
    fill_qty        NUMBER(18,4),
    fill_px         NUMBER(18,6),
    commission      NUMBER(18,4),
    venue           STRING,
    fill_ts         TIMESTAMP_NTZ,
    op              STRING,
    src_event_ts    TIMESTAMP_NTZ,
    loaded_at       TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE AETHER_TRADE.STG.CUSTOMER (
    customer_id     NUMBER,
    advisor_id      NUMBER,
    customer_code   STRING,
    full_name       STRING,
    kyc_status      STRING,
    risk_profile    STRING,
    tax_residency   STRING,
    src_event_ts    TIMESTAMP_NTZ,
    loaded_at       TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE AETHER_TRADE.STG.ACCOUNT (
    account_id      NUMBER,
    customer_id     NUMBER,
    account_no      STRING,
    account_type    STRING,
    base_ccy        STRING,
    status          STRING,
    opened_dt       DATE,
    src_event_ts    TIMESTAMP_NTZ,
    loaded_at       TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE AETHER_TRADE.STG.SECURITY (
    security_id     NUMBER,
    exchange_code   STRING,
    ticker          STRING,
    isin            STRING,
    security_name   STRING,
    asset_class     STRING,
    src_event_ts    TIMESTAMP_NTZ,
    loaded_at       TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE AETHER_TRADE.STG.ADVISOR (
    advisor_id      NUMBER,
    branch_code     STRING,
    region          STRING,
    advisor_code    STRING,
    full_name       STRING,
    is_active       BOOLEAN,
    src_event_ts    TIMESTAMP_NTZ,
    loaded_at       TIMESTAMP_NTZ
);
