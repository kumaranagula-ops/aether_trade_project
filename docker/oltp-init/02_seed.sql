-- Seeds oms.* from the sample CSVs in /seed-data (mounted from ./data).
-- Runs after 01_ddl.sql (sql/oltp/01_oltp_ddl.sql, mounted directly — see
-- docker-compose.yml) because docker-entrypoint-initdb.d executes
-- alphabetically. Load order respects foreign keys.

\copy oms.branch(branch_id, branch_code, branch_name, region) FROM '/seed-data/branch.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.exchange(exchange_id, exchange_code, exchange_name, timezone) FROM '/seed-data/exchange.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.advisor(advisor_id, branch_id, advisor_code, full_name, email, is_active) FROM '/seed-data/advisor.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.customer(customer_id, advisor_id, customer_code, full_name, kyc_status, risk_profile, tax_residency) FROM '/seed-data/customer.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.account(account_id, customer_id, account_no, account_type, base_ccy, status, opened_dt) FROM '/seed-data/account.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.security(security_id, exchange_id, ticker, isin, security_name, asset_class) FROM '/seed-data/security.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.app_user(user_id, user_name, role_code, advisor_id) FROM '/seed-data/app_user.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.orders(order_id, account_id, security_id, entered_by, side, order_type, ordered_qty, limit_px, tif, status, reject_reason, order_ts, last_update_ts) FROM '/seed-data/orders.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.execution(execution_id, order_id, account_id, security_id, fill_qty, fill_px, commission, venue, fill_ts) FROM '/seed-data/execution.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.position(position_id, account_id, security_id, qty, avg_cost, last_px, updated_at) FROM '/seed-data/position.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy oms.cash_ledger(ledger_id, account_id, execution_id, amount, ccy, reason_code, value_dt, created_at) FROM '/seed-data/cash_ledger.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- Explicit PKs were loaded from CSV, so every BIGSERIAL sequence is still at
-- 1. Reset each to MAX(pk)+? (nextval-safe) or the next insert collides with
-- row 1 on the first INSERT that doesn't specify an id.
SELECT setval(pg_get_serial_sequence('oms.branch', 'branch_id'), COALESCE((SELECT MAX(branch_id) FROM oms.branch), 1));
SELECT setval(pg_get_serial_sequence('oms.exchange', 'exchange_id'), COALESCE((SELECT MAX(exchange_id) FROM oms.exchange), 1));
SELECT setval(pg_get_serial_sequence('oms.advisor', 'advisor_id'), COALESCE((SELECT MAX(advisor_id) FROM oms.advisor), 1));
SELECT setval(pg_get_serial_sequence('oms.customer', 'customer_id'), COALESCE((SELECT MAX(customer_id) FROM oms.customer), 1));
SELECT setval(pg_get_serial_sequence('oms.account', 'account_id'), COALESCE((SELECT MAX(account_id) FROM oms.account), 1));
SELECT setval(pg_get_serial_sequence('oms.security', 'security_id'), COALESCE((SELECT MAX(security_id) FROM oms.security), 1));
SELECT setval(pg_get_serial_sequence('oms.app_user', 'user_id'), COALESCE((SELECT MAX(user_id) FROM oms.app_user), 1));
SELECT setval(pg_get_serial_sequence('oms.orders', 'order_id'), COALESCE((SELECT MAX(order_id) FROM oms.orders), 1));
SELECT setval(pg_get_serial_sequence('oms.execution', 'execution_id'), COALESCE((SELECT MAX(execution_id) FROM oms.execution), 1));
SELECT setval(pg_get_serial_sequence('oms.position', 'position_id'), COALESCE((SELECT MAX(position_id) FROM oms.position), 1));
SELECT setval(pg_get_serial_sequence('oms.cash_ledger', 'ledger_id'), COALESCE((SELECT MAX(ledger_id) FROM oms.cash_ledger), 1));
