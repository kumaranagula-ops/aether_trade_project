-- Aether Trade OLTP (PostgreSQL-compatible)
-- Purpose: real-time order capture, risk checks, fills, positions.
-- This is the system of record for trading. Snowflake is not.

CREATE SCHEMA IF NOT EXISTS oms;

CREATE TABLE oms.branch (
    branch_id        BIGSERIAL PRIMARY KEY,
    branch_code      VARCHAR(16) NOT NULL UNIQUE,
    branch_name      VARCHAR(100) NOT NULL,
    region           VARCHAR(40) NOT NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE oms.advisor (
    advisor_id       BIGSERIAL PRIMARY KEY,
    branch_id        BIGINT NOT NULL REFERENCES oms.branch(branch_id),
    advisor_code     VARCHAR(16) NOT NULL UNIQUE,
    full_name        VARCHAR(120) NOT NULL,
    email            VARCHAR(160) NOT NULL,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE oms.customer (
    customer_id      BIGSERIAL PRIMARY KEY,
    advisor_id       BIGINT NOT NULL REFERENCES oms.advisor(advisor_id),
    customer_code    VARCHAR(20) NOT NULL UNIQUE,
    full_name        VARCHAR(120) NOT NULL,
    date_of_birth    DATE,
    kyc_status       VARCHAR(20) NOT NULL,   -- PENDING / APPROVED / REJECTED
    risk_profile     VARCHAR(20) NOT NULL,   -- CONSERVATIVE / MODERATE / AGGRESSIVE
    tax_residency    VARCHAR(8) NOT NULL DEFAULT 'US',
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE oms.account (
    account_id       BIGSERIAL PRIMARY KEY,
    customer_id      BIGINT NOT NULL REFERENCES oms.customer(customer_id),
    account_no       VARCHAR(24) NOT NULL UNIQUE,
    account_type     VARCHAR(20) NOT NULL,   -- CASH / MARGIN / IRA / 401K
    base_ccy         CHAR(3) NOT NULL DEFAULT 'USD',
    status           VARCHAR(16) NOT NULL DEFAULT 'OPEN',
    opened_dt        DATE NOT NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE oms.exchange (
    exchange_id      BIGSERIAL PRIMARY KEY,
    exchange_code    VARCHAR(12) NOT NULL UNIQUE,
    exchange_name    VARCHAR(80) NOT NULL,
    timezone         VARCHAR(40) NOT NULL
);

CREATE TABLE oms.security (
    security_id      BIGSERIAL PRIMARY KEY,
    exchange_id      BIGINT NOT NULL REFERENCES oms.exchange(exchange_id),
    ticker           VARCHAR(16) NOT NULL,
    isin             VARCHAR(12),
    security_name    VARCHAR(160) NOT NULL,
    asset_class      VARCHAR(24) NOT NULL,   -- EQUITY / ETF / OPTION / MF
    lot_size         INTEGER NOT NULL DEFAULT 1,
    tick_size        NUMERIC(10,6) NOT NULL DEFAULT 0.01,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (exchange_id, ticker)
);

CREATE TABLE oms.app_user (
    user_id          BIGSERIAL PRIMARY KEY,
    user_name        VARCHAR(80) NOT NULL UNIQUE,
    role_code        VARCHAR(24) NOT NULL,   -- CLIENT / ADVISOR / TRADER / OPS
    advisor_id       BIGINT REFERENCES oms.advisor(advisor_id)
);

CREATE TABLE oms.orders (
    order_id         BIGSERIAL PRIMARY KEY,
    account_id       BIGINT NOT NULL REFERENCES oms.account(account_id),
    security_id      BIGINT NOT NULL REFERENCES oms.security(security_id),
    entered_by       BIGINT NOT NULL REFERENCES oms.app_user(user_id),
    side             CHAR(1) NOT NULL CHECK (side IN ('B','S')),
    order_type       VARCHAR(12) NOT NULL,   -- MKT / LMT / STP
    ordered_qty      NUMERIC(18,4) NOT NULL CHECK (ordered_qty > 0),
    limit_px         NUMERIC(18,6),
    tif              VARCHAR(8) NOT NULL DEFAULT 'DAY',
    status           VARCHAR(16) NOT NULL,   -- NEW / PARTIAL / FILLED / CXL / REJ
    reject_reason    VARCHAR(200),
    order_ts         TIMESTAMP NOT NULL DEFAULT NOW(),
    last_update_ts   TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_orders_acct_ts ON oms.orders (account_id, order_ts);
CREATE INDEX ix_orders_sec_ts  ON oms.orders (security_id, order_ts);

CREATE TABLE oms.execution (
    execution_id     BIGSERIAL PRIMARY KEY,
    order_id         BIGINT NOT NULL REFERENCES oms.orders(order_id),
    account_id       BIGINT NOT NULL REFERENCES oms.account(account_id),
    security_id      BIGINT NOT NULL REFERENCES oms.security(security_id),
    fill_qty         NUMERIC(18,4) NOT NULL CHECK (fill_qty > 0),
    fill_px          NUMERIC(18,6) NOT NULL,
    commission       NUMERIC(18,4) NOT NULL DEFAULT 0,
    venue            VARCHAR(16) NOT NULL,
    fill_ts          TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_exec_order ON oms.execution (order_id);
CREATE INDEX ix_exec_acct_ts ON oms.execution (account_id, fill_ts);

CREATE TABLE oms.position (
    position_id      BIGSERIAL PRIMARY KEY,
    account_id       BIGINT NOT NULL REFERENCES oms.account(account_id),
    security_id      BIGINT NOT NULL REFERENCES oms.security(security_id),
    qty              NUMERIC(18,4) NOT NULL,
    avg_cost         NUMERIC(18,6) NOT NULL,
    last_px          NUMERIC(18,6),
    updated_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (account_id, security_id)
);

CREATE TABLE oms.cash_ledger (
    ledger_id        BIGSERIAL PRIMARY KEY,
    account_id       BIGINT NOT NULL REFERENCES oms.account(account_id),
    execution_id     BIGINT REFERENCES oms.execution(execution_id),
    amount           NUMERIC(18,4) NOT NULL,  -- signed: debit -, credit +
    ccy              CHAR(3) NOT NULL DEFAULT 'USD',
    reason_code      VARCHAR(24) NOT NULL,    -- TRADE / FEE / DIV / DEPOSIT / WITHDRAW
    value_dt         DATE NOT NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE oms.order_audit (
    audit_id         BIGSERIAL PRIMARY KEY,
    order_id         BIGINT NOT NULL REFERENCES oms.orders(order_id),
    from_status      VARCHAR(16),
    to_status        VARCHAR(16) NOT NULL,
    event_ts         TIMESTAMP NOT NULL DEFAULT NOW(),
    event_payload    JSONB
);

-- CDC helper: watermark / change log for extraction to Snowflake
CREATE TABLE oms.cdc_outbox (
    event_id         BIGSERIAL PRIMARY KEY,
    table_name       VARCHAR(64) NOT NULL,
    pk_value         BIGINT NOT NULL,
    op               CHAR(1) NOT NULL CHECK (op IN ('I','U','D')),
    payload          JSONB NOT NULL,
    event_ts         TIMESTAMP NOT NULL DEFAULT NOW(),
    published_flag   BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX ix_cdc_unpublished ON oms.cdc_outbox (published_flag, event_ts);
