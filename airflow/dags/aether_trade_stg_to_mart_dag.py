"""
Aether Trade — STG to MART transform, orchestrated by Airflow, executed by dbt.

Ownership split (see dbt/README.md and the root README's architecture section):
  RAW  -> STG   native Snowflake Snowpipe + Streams + Tasks
                (sql/snowflake/04_pipes_streams_tasks.sql) — event-driven CDC
                micro-batch, ~1-5 min latency. Airflow does not touch this half.
  STG  -> MART  dbt, run on a schedule from this DAG. Batch transform with
                tests, docs and lineage instead of hand-rolled MERGE tasks.

Latency target for this DAG: fill -> MART fact within 15 minutes, matching the
latency table in the root README.

`dbt source freshness` runs before the build and is allowed to fail the DAG:
if STG hasn't been touched in > SLA minutes, that's the native ingestion
pipeline's SLO breaching, not dbt's — and it should page/alert as such rather
than silently building a MART on stale STG data.
"""
from __future__ import annotations

import datetime as dt

from airflow.decorators import dag, task
from airflow.operators.bash import BashOperator
from airflow.utils.trigger_rule import TriggerRule

DBT_PROJECT_DIR = "/opt/airflow/dbt/aether_trade"
DBT_PROFILES_DIR = "/opt/airflow/dbt/aether_trade"

default_args = {
    "owner": "aether-trade-data-eng",
    "retries": 2,
    "retry_delay": dt.timedelta(minutes=3),
    "execution_timeout": dt.timedelta(minutes=12),
}


def _dbt(cmd: str) -> str:
    return f"cd {DBT_PROJECT_DIR} && dbt {cmd} --profiles-dir {DBT_PROFILES_DIR}"


@dag(
    dag_id="aether_trade_stg_to_mart",
    description="dbt build: STG -> MART star schema for Aether Trade",
    schedule="*/15 * * * *",
    start_date=dt.datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["aether-trade", "dbt", "snowflake"],
)
def aether_trade_stg_to_mart():

    dbt_deps = BashOperator(task_id="dbt_deps", bash_command=_dbt("deps"))

    # SLO gate: STG freshness thresholds live in models/staging/_stg__sources.yml.
    # error_after breach -> nonzero exit -> this task (and the DAG) fails.
    dbt_source_freshness = BashOperator(
        task_id="dbt_source_freshness",
        bash_command=_dbt("source freshness"),
    )

    dbt_seed = BashOperator(task_id="dbt_seed", bash_command=_dbt("seed"))

    dbt_snapshot = BashOperator(
        task_id="dbt_snapshot_scd2_dims",
        bash_command=_dbt("snapshot"),
    )

    dbt_run = BashOperator(task_id="dbt_run_marts", bash_command=_dbt("run"))

    dbt_test = BashOperator(task_id="dbt_test", bash_command=_dbt("test"))

    @task(trigger_rule=TriggerRule.ALL_DONE)
    def notify_on_failure(**context):
        # Stub: wire to Slack/PagerDuty/email in a real deployment. Kept as a
        # single, obvious place to plug in an SRE on-call integration.
        dag_run = context["dag_run"]
        failed = [ti.task_id for ti in dag_run.get_task_instances() if ti.state == "failed"]
        if failed:
            print(f"[ALERT] aether_trade_stg_to_mart failed tasks: {failed}")

    dbt_deps >> dbt_source_freshness >> dbt_seed >> dbt_snapshot >> dbt_run >> dbt_test >> notify_on_failure()


aether_trade_stg_to_mart()
