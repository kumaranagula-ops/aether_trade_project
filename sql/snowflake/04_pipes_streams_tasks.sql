-- Landing from S3 (CDC files dumped by Debezium / custom publisher)
CREATE OR REPLACE FILE FORMAT AETHER_TRADE.RAW.FF_JSON
    TYPE = JSON
    STRIP_OUTER_ARRAY = TRUE
    COMPRESSION = GZIP;

-- Assume stage already exists: AETHER_TRADE.RAW.STG_S3_CDC
CREATE OR REPLACE PIPE AETHER_TRADE.RAW.PIPE_EXECUTION
    AUTO_INGEST = TRUE
AS
COPY INTO AETHER_TRADE.RAW.EXECUTION_CDC (event_id, op, payload, event_ts, file_name)
FROM (
    SELECT
        $1:event_id::NUMBER,
        $1:op::STRING,
        $1:payload,
        $1:event_ts::TIMESTAMP_NTZ,
        METADATA$FILENAME
    FROM @AETHER_TRADE.RAW.STG_S3_CDC/execution/
)
FILE_FORMAT = AETHER_TRADE.RAW.FF_JSON
ON_ERROR = CONTINUE;

CREATE OR REPLACE PIPE AETHER_TRADE.RAW.PIPE_ORDERS
    AUTO_INGEST = TRUE
AS
COPY INTO AETHER_TRADE.RAW.ORDERS_CDC (event_id, op, payload, event_ts, file_name)
FROM (
    SELECT
        $1:event_id::NUMBER,
        $1:op::STRING,
        $1:payload,
        $1:event_ts::TIMESTAMP_NTZ,
        METADATA$FILENAME
    FROM @AETHER_TRADE.RAW.STG_S3_CDC/orders/
)
FILE_FORMAT = AETHER_TRADE.RAW.FF_JSON
ON_ERROR = CONTINUE;

-- Streams on RAW
CREATE OR REPLACE STREAM AETHER_TRADE.RAW.STR_EXECUTION ON TABLE AETHER_TRADE.RAW.EXECUTION_CDC;
CREATE OR REPLACE STREAM AETHER_TRADE.RAW.STR_ORDERS     ON TABLE AETHER_TRADE.RAW.ORDERS_CDC;

-- Flatten RAW -> STG (latest image per key)
CREATE OR REPLACE TASK AETHER_TRADE.STG.TASK_LOAD_EXECUTION
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('AETHER_TRADE.RAW.STR_EXECUTION')
AS
MERGE INTO AETHER_TRADE.STG.EXECUTION t
USING (
    SELECT
        payload:execution_id::NUMBER    AS execution_id,
        payload:order_id::NUMBER        AS order_id,
        payload:account_id::NUMBER      AS account_id,
        payload:security_id::NUMBER     AS security_id,
        payload:fill_qty::NUMBER(18,4)  AS fill_qty,
        payload:fill_px::NUMBER(18,6)   AS fill_px,
        payload:commission::NUMBER(18,4) AS commission,
        payload:venue::STRING           AS venue,
        payload:fill_ts::TIMESTAMP_NTZ  AS fill_ts,
        op,
        event_ts AS src_event_ts,
        CURRENT_TIMESTAMP() AS loaded_at
    FROM AETHER_TRADE.RAW.STR_EXECUTION
    QUALIFY ROW_NUMBER() OVER (PARTITION BY payload:execution_id::NUMBER ORDER BY event_ts DESC) = 1
) s
ON t.execution_id = s.execution_id
WHEN MATCHED AND s.op = 'D' THEN DELETE
WHEN MATCHED THEN UPDATE SET
    order_id = s.order_id, account_id = s.account_id, security_id = s.security_id,
    fill_qty = s.fill_qty, fill_px = s.fill_px, commission = s.commission,
    venue = s.venue, fill_ts = s.fill_ts, op = s.op,
    src_event_ts = s.src_event_ts, loaded_at = s.loaded_at
WHEN NOT MATCHED AND s.op <> 'D' THEN INSERT (
    execution_id, order_id, account_id, security_id, fill_qty, fill_px,
    commission, venue, fill_ts, op, src_event_ts, loaded_at
) VALUES (
    s.execution_id, s.order_id, s.account_id, s.security_id, s.fill_qty, s.fill_px,
    s.commission, s.venue, s.fill_ts, s.op, s.src_event_ts, s.loaded_at
);

CREATE OR REPLACE TASK AETHER_TRADE.MART.TASK_FACT_EXECUTION
    WAREHOUSE = COMPUTE_WH
    AFTER AETHER_TRADE.STG.TASK_LOAD_EXECUTION
AS
MERGE INTO AETHER_TRADE.MART.FACT_EXECUTION t
USING (
    SELECT
        e.execution_id,
        e.order_id,
        a.account_sk,
        c.customer_sk,
        adv.advisor_sk,
        s.security_sk,
        TO_NUMBER(TO_CHAR(e.fill_ts::DATE,'YYYYMMDD')) AS trade_date_sk,
        o.side,
        e.fill_qty,
        e.fill_px,
        e.fill_qty * e.fill_px AS notional,
        e.commission,
        e.venue,
        e.fill_ts
    FROM AETHER_TRADE.STG.EXECUTION e
    JOIN AETHER_TRADE.STG.ORDERS o
      ON o.order_id = e.order_id
    JOIN AETHER_TRADE.MART.DIM_ACCOUNT a
      ON a.account_id = e.account_id AND a.is_current
    JOIN AETHER_TRADE.MART.DIM_CUSTOMER c
      ON c.customer_id = a.customer_id AND c.is_current
    JOIN AETHER_TRADE.MART.DIM_ADVISOR adv
      ON adv.advisor_id = c.advisor_id AND adv.is_current
    JOIN AETHER_TRADE.MART.DIM_SECURITY s
      ON s.security_id = e.security_id AND s.is_current
) src
ON t.execution_id = src.execution_id
WHEN MATCHED THEN UPDATE SET
    fill_qty = src.fill_qty, fill_px = src.fill_px, notional = src.notional,
    commission = src.commission, fill_ts = src.fill_ts
WHEN NOT MATCHED THEN INSERT (
    execution_id, order_id, account_sk, customer_sk, advisor_sk, security_sk,
    trade_date_sk, side, fill_qty, fill_px, notional, commission, venue, fill_ts
) VALUES (
    src.execution_id, src.order_id, src.account_sk, src.customer_sk, src.advisor_sk, src.security_sk,
    src.trade_date_sk, src.side, src.fill_qty, src.fill_px, src.notional, src.commission, src.venue, src.fill_ts
);

ALTER TASK AETHER_TRADE.MART.TASK_FACT_EXECUTION RESUME;
ALTER TASK AETHER_TRADE.STG.TASK_LOAD_EXECUTION RESUME;
