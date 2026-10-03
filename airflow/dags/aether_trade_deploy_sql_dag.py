from __future__ import annotations

import datetime as dt

from airflow.decorators import dag
from airflow.operators.bash import BashOperator

default_args = {
    "owner": "aether-trade-data-eng",
    "retries": 1,
    "retry_delay": dt.timedelta(minutes=3),
}


@dag(
    dag_id="aether_trade_deploy_sql",
    description="Run sql/create_tables.sql against Snowflake",
    schedule=None,
    start_date=dt.datetime(2026, 1, 1),
    catchup=False,
    default_args=default_args,
    tags=["aether-trade", "snowflake", "ddl"],
)
def aether_trade_deploy_sql():
    create_db_schemas = BashOperator(
        task_id="create_databases_schemas",
        bash_command="/home/airflow/.venvs/snowflake-tools/bin/snow sql -c default -f /opt/airflow/sql/snowflake/01_databases_schemas.sql",
    )
    create_raw_stg = BashOperator(
        task_id="create_raw_stg_tables",
        bash_command="/home/airflow/.venvs/snowflake-tools/bin/snow sql -c default -f /opt/airflow/sql/snowflake/02_raw_stg.sql",
    )
    create_mart = BashOperator(
        task_id="create_mart_tables",
        bash_command="/home/airflow/.venvs/snowflake-tools/bin/snow sql -c default -f /opt/airflow/sql/snowflake/03_mart.sql",
    )
    create_pipes_streams_tasks = BashOperator(
        task_id="create_pipes_streams_tasks",
        bash_command="/home/airflow/.venvs/snowflake-tools/bin/snow sql -c default -f /opt/airflow/sql/snowflake/04_pipes_streams_tasks.sql",
    )

    create_db_schemas >> create_raw_stg >> create_mart >> create_pipes_streams_tasks


aether_trade_deploy_sql()
