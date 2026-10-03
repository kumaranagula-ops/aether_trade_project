"""
Aether Trade — data lake load, orchestrated by Airflow, executed by Spark on YARN.

  1. land_csv_to_hdfs      copy the source CSVs into HDFS over WebHDFS (raw zone)
  2. spark_daily_traded_value
                           spark-submit to YARN in cluster mode; the job writes
                           Parquet tables into HDFS and registers them in the
                           Hive Metastore (aether_lake.*)
  3. verify_lake_output    confirm the summary table's Parquet files exist

Needs the big data stack: start with
  docker compose -f docker-compose.yml -f docker-compose.bigdata.yml up -d
"""
from __future__ import annotations

import datetime as dt
from pathlib import Path

import requests

from airflow.decorators import dag, task
from airflow.operators.bash import BashOperator

WEBHDFS = "http://namenode:9870/webhdfs/v1"
HDFS_USER = "root"
LOCAL_DATA = Path("/opt/airflow/data")
RAW_DIR = "/data/aether/raw"
SUMMARY_TABLE_DIR = "/user/hive/warehouse/aether_lake.db/daily_traded_value"

SPARK_VENV = "/home/airflow/.venvs/spark-tools"
# spark-submit locates Spark by asking whichever `python` is first on PATH, which
# is Airflow's own interpreter, not the venv. Pointing SPARK_HOME at the venv's
# pyspark package avoids that lookup.
SPARK_HOME = f"{SPARK_VENV}/lib/python3.11/site-packages/pyspark"
SPARK_SUBMIT = f"SPARK_HOME={SPARK_HOME} {SPARK_VENV}/bin/spark-submit"
SPARK_JOB = "/opt/airflow/spark_jobs/daily_traded_value.py"

default_args = {
    "owner": "aether-trade-data-eng",
    "retries": 1,
    "retry_delay": dt.timedelta(minutes=2),
    "execution_timeout": dt.timedelta(minutes=20),
}


@dag(
    dag_id="aether_trade_spark_lake",
    description="Land CSVs in HDFS, run the PySpark job on YARN, verify the Hive table",
    schedule=None,
    start_date=dt.datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["aether-trade", "spark", "hdfs", "hive"],
)
def aether_trade_spark_lake():
    @task
    def land_csv_to_hdfs() -> int:
        files = sorted(LOCAL_DATA.glob("*.csv"))
        if not files:
            raise FileNotFoundError(f"No CSV files found in {LOCAL_DATA}")

        auth = {"user.name": HDFS_USER}
        requests.put(f"{WEBHDFS}{RAW_DIR}", params={"op": "MKDIRS", **auth}, timeout=30).raise_for_status()

        for f in files:
            # WebHDFS writes are two steps: the NameNode redirects to a DataNode,
            # and the file body goes to that second URL.
            first = requests.put(
                f"{WEBHDFS}{RAW_DIR}/{f.name}",
                params={"op": "CREATE", "overwrite": "true", **auth},
                allow_redirects=False,
                timeout=30,
            )
            if first.status_code != 307:
                raise RuntimeError(f"NameNode did not redirect for {f.name}: {first.status_code} {first.text}")
            with f.open("rb") as body:
                requests.put(first.headers["Location"], data=body, timeout=300).raise_for_status()
            print(f"landed {f.name} ({f.stat().st_size} bytes)")
        return len(files)

    spark_daily_traded_value = BashOperator(
        task_id="spark_daily_traded_value",
        bash_command=(
            f"{SPARK_SUBMIT} "
            "--master yarn --deploy-mode cluster "
            "--properties-file /opt/spark-conf/spark-defaults.conf "
            "--name aether_trade_daily_traded_value "
            "--conf spark.driver.memory=768m "
            "--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=/usr/bin/python3 "
            f"{SPARK_JOB}"
        ),
    )

    @task
    def verify_lake_output() -> int:
        resp = requests.get(
            f"{WEBHDFS}{SUMMARY_TABLE_DIR}",
            params={"op": "LISTSTATUS", "user.name": HDFS_USER},
            timeout=30,
        )
        resp.raise_for_status()
        parts = [
            s for s in resp.json()["FileStatuses"]["FileStatus"]
            if s["pathSuffix"].endswith(".parquet") and s["length"] > 0
        ]
        if not parts:
            raise ValueError(f"No Parquet files in {SUMMARY_TABLE_DIR}")
        print(f"{len(parts)} Parquet file(s), {sum(p['length'] for p in parts)} bytes")
        return len(parts)

    land_csv_to_hdfs() >> spark_daily_traded_value >> verify_lake_output()


aether_trade_spark_lake()
