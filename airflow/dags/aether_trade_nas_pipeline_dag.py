"""
Aether Trade — NAS files to the Spark catalog, bronze -> silver -> gold.

  1. land_nas_to_hdfs   mirror each source folder on the NAS (mounted read-only at
                        /opt/airflow/nas) into the HDFS landing zone over WebHDFS
  2. spark_bronze       raw files -> nas_bronze.* (Hive/Parquet)
  3. spark_silver       typed, de-duplicated -> lake.nas_silver.* (Iceberg, MERGE)
  4. spark_gold         aggregates -> lake.nas_gold.* (Iceberg)
  5. verify_gold        confirm both gold tables have data files in HDFS

The NAS folder is set by NAS_LANDING_DIR in .env (default ./nas/landing). Needs the
big data stack:
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
NAS_DIR = Path("/opt/airflow/nas")
LANDING_DIR = "/data/nas/landing"
GOLD_DIR = "/user/hive/warehouse/nas_gold.db"
GOLD_TABLES = ["daily_sales", "customer_value"]

SPARK_VENV = "/home/airflow/.venvs/spark-tools"
# Same SPARK_HOME workaround as aether_trade_spark_lake_dag.py.
SPARK_HOME = f"{SPARK_VENV}/lib/python3.11/site-packages/pyspark"
SPARK_SUBMIT = f"SPARK_HOME={SPARK_HOME} {SPARK_VENV}/bin/spark-submit"
JOBS = "/opt/airflow/spark_jobs/nas_pipeline"

default_args = {
    "owner": "aether-trade-data-eng",
    "retries": 1,
    "retry_delay": dt.timedelta(minutes=2),
    "execution_timeout": dt.timedelta(minutes=20),
}


def spark_job(layer: str) -> BashOperator:
    return BashOperator(
        task_id=f"spark_{layer}",
        bash_command=(
            f"{SPARK_SUBMIT} "
            "--master yarn --deploy-mode cluster "
            "--properties-file /opt/spark-conf/spark-defaults.conf "
            f"--name nas_pipeline_{layer} "
            "--conf spark.driver.memory=768m "
            "--conf spark.yarn.appMasterEnv.PYSPARK_PYTHON=/usr/bin/python3 "
            f"--py-files {JOBS}/common.py "
            f"{JOBS}/{layer}.py"
        ),
    )


def webhdfs(method: str, path: str, op: str, **params) -> requests.Response:
    resp = requests.request(
        method, f"{WEBHDFS}{path}",
        params={"op": op, "user.name": HDFS_USER, **params},
        allow_redirects=False, timeout=30,
    )
    if op != "CREATE":
        resp.raise_for_status()
    return resp


@dag(
    dag_id="aether_trade_nas_pipeline",
    description="NAS files -> HDFS -> bronze/silver/gold tables in the Hive + Iceberg catalog",
    schedule=None,
    start_date=dt.datetime(2026, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["aether-trade", "spark", "nas", "iceberg"],
)
def aether_trade_nas_pipeline():
    @task
    def land_nas_to_hdfs() -> dict[str, int]:
        sources = sorted(d for d in NAS_DIR.iterdir() if d.is_dir())
        if not sources:
            raise FileNotFoundError(f"No source folders found in {NAS_DIR}")

        landed = {}
        for src in sources:
            files = sorted(f for f in src.iterdir() if f.is_file() and not f.name.startswith("."))
            target = f"{LANDING_DIR}/{src.name}"
            # Mirror the NAS: files removed there disappear from the landing zone too.
            webhdfs("DELETE", target, "DELETE", recursive="true")
            webhdfs("PUT", target, "MKDIRS")
            for f in files:
                # WebHDFS writes are two steps: the NameNode redirects to a DataNode.
                first = webhdfs("PUT", f"{target}/{f.name}", "CREATE", overwrite="true")
                if first.status_code != 307:
                    raise RuntimeError(f"NameNode did not redirect for {f}: {first.status_code} {first.text}")
                with f.open("rb") as body:
                    requests.put(first.headers["Location"], data=body, timeout=300).raise_for_status()
            landed[src.name] = len(files)
            print(f"landed {src.name}: {len(files)} file(s)")
        return landed

    @task
    def verify_gold() -> dict[str, int]:
        counts = {}
        for table in GOLD_TABLES:
            listing = webhdfs("GET", f"{GOLD_DIR}/{table}/data", "LISTSTATUS").json()
            parts = [s for s in listing["FileStatuses"]["FileStatus"]
                     if s["pathSuffix"].endswith(".parquet") and s["length"] > 0]
            if not parts:
                raise ValueError(f"No Parquet data files for nas_gold.{table}")
            counts[table] = len(parts)
            print(f"nas_gold.{table}: {len(parts)} data file(s)")
        return counts

    land_nas_to_hdfs() >> spark_job("bronze") >> spark_job("silver") >> spark_job("gold") >> verify_gold()


aether_trade_nas_pipeline()
