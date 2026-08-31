-- MART: star schema for advisor / risk / operations reporting
CREATE OR REPLACE TABLE AETHER_TRADE.MART.DIM_DATE (
    date_sk         NUMBER PRIMARY KEY,
    cal_date        DATE,
    year_num        NUMBER,
    quarter_num     NUMBER,
    month_num       NUMBER,
    month_name      STRING,
    day_of_week     STRING,
    is_weekend      BOOLEAN,
    is_business_day BOOLEAN
);

CREATE OR REPLACE TABLE AETHER_TRADE.MART.DIM_ADVISOR (
    advisor_sk      NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    advisor_id      NUMBER,
    advisor_code    STRING,
    advisor_name    STRING,
    branch_code     STRING,
    region          STRING,
    is_active       BOOLEAN,
    effective_from  TIMESTAMP_NTZ,
    effective_to    TIMESTAMP_NTZ,
    is_current      BOOLEAN,
    PRIMARY KEY (advisor_sk)
);

CREATE OR REPLACE TABLE AETHER_TRADE.MART.DIM_CUSTOMER (
    customer_sk     NUMBER AUTOINCREMENT,
    customer_id     NUMBER,
    customer_code   STRING,
    customer_name   STRING,
    advisor_id      NUMBER,
    kyc_status      STRING,
    risk_profile    STRING,
    tax_residency   STRING,
    effective_from  TIMESTAMP_NTZ,
    effective_to    TIMESTAMP_NTZ,
    is_current      BOOLEAN
);

CREATE OR REPLACE TABLE AETHER_TRADE.MART.DIM_ACCOUNT (
    account_sk      NUMBER AUTOINCREMENT,
    account_id      NUMBER,
    account_no      STRING,
    customer_id     NUMBER,
    account_type    STRING,
    base_ccy        STRING,
    status          STRING,
    opened_dt       DATE,
    effective_from  TIMESTAMP_NTZ,
    effective_to    TIMESTAMP_NTZ,
    is_current      BOOLEAN
);

CREATE OR REPLACE TABLE AETHER_TRADE.MART.DIM_SECURITY (
    security_sk     NUMBER AUTOINCREMENT,
    security_id     NUMBER,
    ticker          STRING,
    isin            STRING,
    security_name   STRING,
    asset_class     STRING,
    exchange_code   STRING,
    effective_from  TIMESTAMP_NTZ,
    effective_to    TIMESTAMP_NTZ,
    is_current      BOOLEAN
);

CREATE OR REPLACE TABLE AETHER_TRADE.MART.DIM_ORDER_STATUS (
    status_sk       NUMBER AUTOINCREMENT,
    status_code     STRING,
    status_desc     STRING
);

CREATE OR REPLACE TABLE AETHER_TRADE.MART.FACT_ORDER (
    order_sk            NUMBER AUTOINCREMENT,
    order_id            NUMBER,
    account_sk          NUMBER,
    customer_sk         NUMBER,
    advisor_sk          NUMBER,
    security_sk         NUMBER,
    order_date_sk       NUMBER,
    status_sk           NUMBER,
    side                STRING,
    order_type          STRING,
    ordered_qty         NUMBER(18,4),
    limit_px            NUMBER(18,6),
    filled_qty          NUMBER(18,4),
    remaining_qty       NUMBER(18,4),
    order_ts            TIMESTAMP_NTZ,
    last_update_ts      TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE AETHER_TRADE.MART.FACT_EXECUTION (
    execution_sk        NUMBER AUTOINCREMENT,
    execution_id        NUMBER,
    order_id            NUMBER,
    account_sk          NUMBER,
    customer_sk         NUMBER,
    advisor_sk          NUMBER,
    security_sk         NUMBER,
    trade_date_sk       NUMBER,
    side                STRING,
    fill_qty            NUMBER(18,4),
    fill_px             NUMBER(18,6),
    notional            NUMBER(18,4),
    commission          NUMBER(18,4),
    venue               STRING,
    fill_ts             TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE AETHER_TRADE.MART.FACT_POSITION_SNAPSHOT (
    pos_sk              NUMBER AUTOINCREMENT,
    account_sk          NUMBER,
    customer_sk         NUMBER,
    advisor_sk          NUMBER,
    security_sk         NUMBER,
    as_of_date_sk       NUMBER,
    qty                 NUMBER(18,4),
    avg_cost            NUMBER(18,6),
    last_px             NUMBER(18,6),
    market_value        NUMBER(18,4),
    unrealized_pnl      NUMBER(18,4)
);

CREATE OR REPLACE TABLE AETHER_TRADE.MART.AGG_DAILY_VOLUME (
    as_of_date          DATE,
    advisor_sk          NUMBER,
    security_sk         NUMBER,
    buy_qty             NUMBER(18,4),
    sell_qty            NUMBER(18,4),
    buy_notional        NUMBER(18,4),
    sell_notional       NUMBER(18,4),
    trade_count         NUMBER,
    commission_amt      NUMBER(18,4)
);

-- Clustering for large facts
ALTER TABLE AETHER_TRADE.MART.FACT_EXECUTION CLUSTER BY (trade_date_sk, account_sk);
ALTER TABLE AETHER_TRADE.MART.FACT_ORDER CLUSTER BY (order_date_sk, account_sk);
ALTER TABLE AETHER_TRADE.MART.FACT_POSITION_SNAPSHOT CLUSTER BY (as_of_date_sk, account_sk);
