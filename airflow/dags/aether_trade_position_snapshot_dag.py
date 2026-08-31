"""
Aether Trade — daily EOD position snapshot batch.

Runs once per US trading day after market close, building only
fact_position_snapshot (dbt's `--select` scopes the run instead of rebuilding
the whole mart). This is deliberately structured like a TWS/Autosys EOD batch
job rather than a continuous micro-batch DAG:

  - catchup=True on purpose: a gap in this DAG (deploy freeze, incident,
    Airflow downtime) should backfill every missed business day once the DAG
    is healthy again, the same "resume where you left off" expectation an
    EOD batch has under TWS/Autosys.
  - Reruns are safe: fact_position_snapshot is an incremental MERGE keyed on
    (account_id, security_id, as_of_date), so replaying a past run_date is
    idempotent instead of duplicating rows.
"""
from __future__ import annotations

import datetime as dt

from airflow.decorators import dag
from airflow.operators.bash import BashOperator

DBT_PROJECT_DIR = "/opt/airflow/dbt/aether_trade"
DBT_PROFILES_DIR = "/opt/airflow/dbt/aether_trade"

default_args = {
    "owner": "aether-trade-data-eng",
    "retries": 1,
    "retry_delay": dt.timedelta(minutes=5),
    "execution_timeout": dt.timedelta(minutes=20),
}


@dag(
    dag_id="aether_trade_position_snapshot_daily",
    description="Daily EOD position snapshot -> fact_position_snapshot",
    schedule="0 21 * * 1-5",  # 21:00 UTC weekdays, after US market close
    start_date=dt.datetime(2026, 1, 1),
    catchup=True,
    max_active_runs=1,
    default_args=default_args,
    tags=["aether-trade", "dbt", "positions", "eod"],
)
def aether_trade_position_snapshot_daily():
    BashOperator(
        task_id="dbt_build_fact_position_snapshot",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && "
            f"dbt build --select stg_position+ fact_position_snapshot "
            f"--profiles-dir {DBT_PROFILES_DIR}"
        ),
    )


aether_trade_position_snapshot_daily()
